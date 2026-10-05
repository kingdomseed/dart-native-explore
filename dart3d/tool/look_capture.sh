#!/bin/sh
# Captures one screenshot per variant of the look-reference board.
#
#   tool/look_capture.sh android <adb-serial> <run-log> <out-dir>
#   tool/look_capture.sh ios <simulator-udid> <run-log> <out-dir>
#
# Before running: start the example on the device with
#   dn run -d <device> [--release] --dart-define=DART3D_SCENE=lookref
# and send its output to <run-log>. The board steps through its
# variants on a timer and logs each one; this script waits for a
# variant's line, lets the frame settle, and saves <out-dir>/<variant>.png.
# It sends no input to the device. It ends when every variant listed in
# tool/look_reference_patches.json is captured, or after five minutes.
# Set LOOK_VARIANTS to a space-separated list to wait for those only
# (with --dart-define=DART3D_LOOKREF=<variant>, which pins the board).
#
# iOS simulator screenshots carry the display's colour profile; they are
# converted to sRGB so both platforms' files hold the same encoding.
# Compare two directories with tool/look_compare.py.
set -eu

platform=${1:?usage: look_capture.sh android|ios <device> <run-log> <out-dir>}
device=${2:?device}
log=${3:?run log}
out=${4:?output directory}
package=com.jasonholtdigital.dart3d_example
settle=4

root=$(cd "$(dirname "$0")" && pwd)
variants=${LOOK_VARIANTS:-$(python3 -c "import json,sys; print(' '.join(json.load(open(sys.argv[1]))['variants']))" "$root/look_reference_patches.json")}
mkdir -p "$out"

shot() {
  case "$platform" in
    android)
      front=$(adb -s "$device" shell dumpsys activity activities 2>/dev/null |
        grep -m1 -E 'mResumedActivity|topResumedActivity' || true)
      case "$front" in
        *"$package"*) ;;
        *) echo "the example is not in the foreground: $front" >&2; exit 3 ;;
      esac
      adb -s "$device" exec-out screencap -p > "$1" ;;
    ios)
      xcrun simctl io "$device" screenshot --type=png "$1" >/dev/null 2>&1
      sips -m "/System/Library/ColorSync/Profiles/sRGB Profile.icc" "$1" >/dev/null ;;
    *) echo "unknown platform $platform" >&2; exit 2 ;;
  esac
}

deadline=$(( $(date +%s) + 300 ))
seen=0
while :; do
  missing=
  for v in $variants; do
    [ -f "$out/$v.png" ] || missing="$missing $v"
  done
  [ -z "$missing" ] && break
  if [ "$(date +%s)" -gt "$deadline" ]; then
    echo "timed out; missing:$missing" >&2
    exit 1
  fi
  total=$(grep -c 'lookref variant ' "$log" || true)
  if [ "$total" -le "$seen" ]; then
    sleep 0.3
    continue
  fi
  seen=$total
  current=$(grep 'lookref variant ' "$log" | tail -1 | sed 's/.*lookref variant //' | tr -d '\r ')
  [ -f "$out/$current.png" ] && continue
  sleep "$settle"
  # Skip the capture if the board moved on while the frame settled.
  [ "$(grep -c 'lookref variant ' "$log" || true)" -eq "$seen" ] || continue
  shot "$out/$current.png"
  echo "captured $current"
done
