#!/bin/sh
# Rebuilds the compiled Filament material packages that ship as assets.
#
# The packages are compiled by filamat on a connected Android device —
# the same compiler, at the same pinned Filament version, that the
# runtime falls back to — and pulled back over adb. Any arm64 device
# will do: the bake renders on OpenGL and filamat builds the packages
# for both backends (OpenGL and Vulkan) whichever one is rendering.
#
#   tool/bake_materials.sh <adb-serial> [options]
#
#   --package <id>      app to bake in (default: the dart3d example)
#   --app-assets <dir>  also collect the lit variants the app compiled
#                       into <dir> (an Android assets directory, e.g.
#                       example/android/app/src/main/assets); each is
#                       built for both backends
#   --wait <seconds>    time to visit the app's screens after the fixed
#                       set is done, so their variants get compiled
#
# Before running: install a release build of the app on the device
# (`dn run -d <serial> --release`). The script refuses to start while
# another app is in the foreground. It copies nothing and exits
# non-zero when filamat rejects any recipe of the fixed set, and it
# waits for variant compiles still in flight before it pulls.
#
# Run it when a material recipe in MaterialPackages.kt or the Filament
# pin in android/build.gradle changes; ShippedMaterialsTest fails until
# the shipped set matches. Packages are named by a hash of their recipe,
# so old files are never loaded by mistake — but they are dead weight:
# the script lists them and the same test fails until they are removed.
set -eu

serial=${1:?usage: bake_materials.sh <adb-serial> [--package id] [--app-assets dir] [--wait seconds]}
shift
package=com.jasonholtdigital.dart3d_example
app_assets=
wait_s=0
while [ $# -gt 0 ]; do
  case "$1" in
    --package) package=$2; shift 2 ;;
    --app-assets) app_assets=$2; shift 2 ;;
    --wait) wait_s=$2; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

root=$(cd "$(dirname "$0")/.." && pwd)
plugin_dir=$root/android/src/main/assets/dart3d/materials
device_dir=/sdcard/Android/data/$package/files/dart3d-materials
work=$(mktemp -d)

front=$(adb -s "$serial" shell dumpsys activity activities 2>/dev/null |
  grep -m1 -E 'mResumedActivity|topResumedActivity' || true)
case "$front" in
  *"$package"*|*[Ll]auncher*) ;;
  *) echo "another app is in the foreground, not launching over it:" >&2
     echo "$front" >&2
     exit 3 ;;
esac

# `monkey -p` would also launch it, but monkey switches auto-rotate on
# when it exits, which unlocks a rotation-locked device.
activity=$(adb -s "$serial" shell "cmd package resolve-activity --brief \
  -c android.intent.category.LAUNCHER $package" | tail -1 | tr -d '\r')
case "$activity" in
  "$package"/*) ;;
  *) echo "$package has no launcher activity on $serial (is it installed?)" >&2
     exit 4 ;;
esac

filament=$(sed -n "s/^def filamentVersion = '\(.*\)'.*/\1/p" "$root/android/build.gradle")
commit=$(git -C "$root" rev-parse --short HEAD)
if [ -n "$(git -C "$root" status --porcelain -- android/src/main/kotlin android/build.gradle)" ]; then
  commit="$commit+uncommitted"
fi
header="# filament $filament, source $commit"

dart3d_log() {
  adb -s "$serial" shell "logcat -d -T '$since' -s dart3d"
}

cleanup() {
  adb -s "$serial" shell setprop log.tag.dart3d.bake '""' || true
  adb -s "$serial" shell am force-stop "$package" || true
}
trap cleanup EXIT

adb -s "$serial" shell setprop log.tag.dart3d.bake DEBUG
adb -s "$serial" shell am force-stop "$package"
adb -s "$serial" shell rm -rf "$device_dir"
since=$(adb -s "$serial" shell "date +'%m-%d %H:%M:%S.000'" | tr -d '\r')
adb -s "$serial" shell am start -n "$activity" >/dev/null

echo "compiling the fixed set on $serial (about a minute) ..."
tries=0
until dart3d_log | grep -q -E 'bake: fixed set (exported|INCOMPLETE)|bake failed'; do
  tries=$((tries + 1))
  if [ "$tries" -gt 150 ]; then
    echo "timed out waiting for the bake; see: adb logcat -s dart3d" >&2
    exit 1
  fi
  sleep 2
done
dart3d_log | grep -E 'bake:|bake failed'
if ! dart3d_log | grep -q 'bake: fixed set exported'; then
  echo "the fixed set is incomplete; nothing was copied" >&2
  exit 1
fi

if [ "$wait_s" -gt 0 ]; then
  echo "visit the app's screens now; collecting variants in ${wait_s}s ..."
  sleep "$wait_s"
fi

# A variant queued near the end of the wait is still compiling (each is
# built for both backends). The app logs when its compile lane starts
# and when it is empty again; the last such line has to be the idle one.
tries=0
while dart3d_log | grep -E 'bake: variants (compiling|idle)' | tail -1 |
    grep -q 'compiling'; do
  if [ "$tries" -eq 0 ]; then echo "waiting for variant compiles to finish ..."; fi
  tries=$((tries + 1))
  if [ "$tries" -gt 150 ]; then
    echo "variant compiles still running after 5 minutes; nothing was copied" >&2
    exit 1
  fi
  sleep 2
done

adb -s "$serial" pull "$device_dir" "$work/out" >/dev/null
sort -u "$work/out/index.txt" > "$work/index.txt"

mkdir -p "$plugin_dir"
: > "$work/plugin-index.txt"
: > "$work/app-index.txt"
while read -r fingerprint key; do
  case "$key" in
    'lit|'*'|e0|s31|'*|'trail|'*|'catcher|'*|'particle|'*)
      cp "$work/out/$fingerprint.filamat" "$plugin_dir/"
      echo "$fingerprint $key" >> "$work/plugin-index.txt" ;;
    *)
      if [ -n "$app_assets" ]; then
        mkdir -p "$app_assets/dart3d/materials"
        cp "$work/out/$fingerprint.filamat" "$app_assets/dart3d/materials/"
      fi
      echo "$fingerprint $key" >> "$work/app-index.txt" ;;
  esac
done < "$work/index.txt"

# Prints the .filamat files in directory $1 that index file $2 does not name.
list_stale() {
  for f in "$1"/*.filamat; do
    [ -e "$f" ] || continue
    name=$(basename "$f" .filamat)
    grep -q "^$name " "$2" || echo "  $f"
  done
}

{ echo "$header"; sort -k2 "$work/plugin-index.txt"; } > "$plugin_dir/index.txt"
echo "plugin: $(wc -l < "$work/plugin-index.txt" | tr -d ' ') packages in $plugin_dir"
stale=$(list_stale "$plugin_dir" "$plugin_dir/index.txt")
if [ -n "$stale" ]; then
  echo "stale plugin packages (no recipe produces them any more; remove them):"
  echo "$stale"
fi

if [ -n "$app_assets" ]; then
  app_dir=$app_assets/dart3d/materials
  if [ -s "$work/app-index.txt" ]; then
    { echo "$header"; sort -k2 "$work/app-index.txt"; } > "$app_dir/variants.txt"
  fi
  echo "app: $(wc -l < "$work/app-index.txt" | tr -d ' ') variants in $app_dir"
  if [ -d "$app_dir" ]; then
    stale=$(list_stale "$app_dir" "$work/app-index.txt")
    if [ -n "$stale" ]; then
      echo "stale app variants (this bake did not produce them: the recipe or"
      echo "Filament changed, or their screen was not visited; nothing was deleted):"
      echo "$stale"
    fi
  fi
elif [ -s "$work/app-index.txt" ]; then
  echo "app variants compiled but not collected (no --app-assets):"
  sed 's/^/  /' "$work/app-index.txt"
fi
