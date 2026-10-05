#!/bin/sh
# Measures native heap growth of the dart3d example across scene
# loads/unloads and dice rolls, from `dumpsys meminfo` (the Native Heap
# row; "alloc" is malloc'd bytes, the column a leak shows in first).
#
#   tool/native_heap_soak.sh <adb-serial> --open X,Y --roll X,Y [options]
#
#   --open X,Y     the hero's "Roll the dice" button, device pixels
#   --roll X,Y     the dice screen's Roll button, device pixels
#   --loads <n>    hero -> dice -> Back cycles (default 50)
#   --rolls <n>    rolls on one dice screen afterwards (default 200)
#   --every <n>    sample every n loads (default 10); rolls sample
#                  every 2.5 n
#   --package <id> app under test (default: the dart3d example)
#
# The app must be running on the hero screen (`dn run -d <serial>
# --release`). Read both coordinates off a fresh screenshot of this
# device; keep them 100 px clear of the screen edges. Every input is
# gated on the app being in the foreground: if anything else is, the
# run stops rather than typing into it. Output is CSV on stdout, sizes
# in kB.
set -eu

serial=${1:?usage: native_heap_soak.sh <adb-serial> --open X,Y --roll X,Y [--loads n] [--rolls n] [--every n]}
shift
package=com.jasonholtdigital.dart3d_example
open=
roll=
loads=50
rolls=200
every=10
while [ $# -gt 0 ]; do
  case "$1" in
    --open) open=$2; shift 2 ;;
    --roll) roll=$2; shift 2 ;;
    --loads) loads=$2; shift 2 ;;
    --rolls) rolls=$2; shift 2 ;;
    --every) every=$2; shift 2 ;;
    --package) package=$2; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
[ -n "$open" ] && [ -n "$roll" ] || { echo "--open and --roll are required" >&2; exit 2; }

sh_dev() { adb -s "$serial" shell "$@"; }

require_foreground() {
  front=$(sh_dev dumpsys activity activities 2>/dev/null |
    grep -m1 -E 'mResumedActivity|topResumedActivity' || true)
  case "$front" in
    *"$package"*) ;;
    *) echo "foreground is not $package, stopping: $front" >&2; exit 3 ;;
  esac
}

tap() {
  require_foreground
  sh_dev input tap "${1%,*}" "${1#*,}"
}

back() {
  require_foreground
  sh_dev input keyevent 4
}

now() { sh_dev "date +'%m-%d %H:%M:%S.000'" | tr -d '\r'; }

# Waits until the dart3d log has a line matching $2 newer than $1.
wait_log() {
  tries=0
  until sh_dev "logcat -d -T '$1' -s dart3d" | grep -q -E "$2"; do
    tries=$((tries + 1))
    if [ "$tries" -gt 40 ]; then
      echo "no '$2' in the log after 20 s" >&2
      exit 1
    fi
    sleep 0.5
  done
}

sample() {
  sleep 3
  sh_dev dumpsys meminfo "$package" | awk -v phase="$1" -v n="$2" '
    $1 == "Native" && $2 == "Heap" && !native { native = $3 "," $4 "," $8 "," $9 }
    $1 == "Dalvik" && $2 == "Heap" && !dalvik { dalvik = $9 }
    $1 == "TOTAL" && $2 != "PSS:" && !total { total = $2 }
    END { print phase "," n "," native "," dalvik "," total }'
}

open_dice() {
  since=$(now)
  tap "$open"
  # The dice document lands in two realizes; the second one ends the load.
  wait_log "$since" 're-realize: restored'
  sleep 1
}

close_dice() {
  since=$(now)
  back
  wait_log "$since" 'released \(disposeView'
  sleep 1
}

echo "phase,count,native_pss_kb,native_private_dirty_kb,native_heap_size_kb,native_heap_alloc_kb,dalvik_alloc_kb,total_pss_kb"
sample loads 0
i=1
while [ "$i" -le "$loads" ]; do
  open_dice
  close_dice
  if [ $((i % every)) -eq 0 ]; then sample loads "$i"; fi
  i=$((i + 1))
done

open_dice
sample rolls 0
roll_every=$((every * 5 / 2))
i=1
while [ "$i" -le "$rolls" ]; do
  tap "$roll"
  sleep 3
  if [ $((i % roll_every)) -eq 0 ]; then sample rolls "$i"; fi
  i=$((i + 1))
done
close_dice
sample end "$loads+$rolls"
