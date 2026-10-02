#!/bin/sh
# Rebuilds the compiled Filament material packages that ship as assets.
#
# The packages are compiled by filamat on a connected Android device —
# the same compiler, at the same pinned Filament version, that the
# runtime falls back to — and pulled back over adb. Any arm64 device
# will do; both target APIs (OpenGL and Vulkan) are compiled on it.
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
# (`dn run -d <serial> --release`) and leave it in the foreground.
#
# Run it when a material recipe in MaterialPackages.kt or the Filament
# pin in android/build.gradle changes; MaterialPackagesTest fails until
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

cleanup() {
  adb -s "$serial" shell setprop log.tag.dart3d.bake '""' || true
  adb -s "$serial" shell am force-stop "$package" || true
}
trap cleanup EXIT

adb -s "$serial" shell setprop log.tag.dart3d.bake DEBUG
adb -s "$serial" shell am force-stop "$package"
adb -s "$serial" shell rm -rf "$device_dir"
adb -s "$serial" logcat -c
adb -s "$serial" shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

echo "compiling the fixed set on $serial (about a minute) ..."
tries=0
until adb -s "$serial" logcat -d -s dart3d | grep -q 'bake: fixed set exported'; do
  tries=$((tries + 1))
  if [ "$tries" -gt 150 ]; then
    echo "timed out waiting for the bake; see: adb logcat -s dart3d" >&2
    exit 1
  fi
  sleep 2
done
adb -s "$serial" logcat -d -s dart3d | grep 'bake:'

if [ "$wait_s" -gt 0 ]; then
  echo "visit the app's screens now; collecting variants in ${wait_s}s ..."
  sleep "$wait_s"
fi

adb -s "$serial" pull "$device_dir" "$work/out" >/dev/null
index=$work/out/index.txt

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
done < "$index"

sort -k2 "$work/plugin-index.txt" > "$plugin_dir/index.txt"
echo "plugin: $(wc -l < "$plugin_dir/index.txt" | tr -d ' ') packages in $plugin_dir"
for f in "$plugin_dir"/*.filamat; do
  name=$(basename "$f" .filamat)
  grep -q "^$name " "$plugin_dir/index.txt" || echo "  stale, remove: $f"
done

if [ -s "$work/app-index.txt" ]; then
  if [ -n "$app_assets" ]; then
    sort -k2 "$work/app-index.txt" > "$app_assets/dart3d/materials/variants.txt"
    echo "app: $(wc -l < "$work/app-index.txt" | tr -d ' ') variants in $app_assets/dart3d/materials"
  else
    echo "app variants compiled but not collected (no --app-assets):"
    sed 's/^/  /' "$work/app-index.txt"
  fi
fi
