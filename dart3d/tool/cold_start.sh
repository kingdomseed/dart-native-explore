#!/bin/sh
# Measures Android cold starts from the plugin's `start +<ms>ms` log
# lines (ColdStart.kt): time from process start to each milestone.
#
#   tool/cold_start.sh <adb-serial> [options]
#
#   --package <id>   app to launch (default: the dart3d example)
#   --fresh          clear the app's data before every launch, which is
#                    what a first launch after install sees (no cache)
#   --runs <n>       launches to time (default 3)
#   --settle <s>     seconds to keep reading the log after the first
#                    frame, to catch late variant compiles (default 8)
#
# The app must already be installed (`dn run -d <serial> --release`).
# It refuses to launch over another app: the foreground must be this
# app or the launcher. The dart3d.perf log tag is switched on for the
# run (the first frame then waits for the driver, giving `first frame
# rendered`) and off again afterwards.
set -eu

serial=${1:?usage: cold_start.sh <adb-serial> [--package id] [--fresh] [--runs n] [--settle s]}
shift
package=com.jasonholtdigital.dart3d_example
fresh=0
runs=3
settle=8
while [ $# -gt 0 ]; do
  case "$1" in
    --package) package=$2; shift 2 ;;
    --fresh) fresh=1; shift ;;
    --runs) runs=$2; shift 2 ;;
    --settle) settle=$2; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

foreground() {
  adb -s "$serial" shell dumpsys activity activities 2>/dev/null |
    grep -m1 -E 'mResumedActivity|topResumedActivity' || true
}

front=$(foreground)
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

adb -s "$serial" shell setprop log.tag.dart3d.perf DEBUG
trap 'adb -s "$serial" shell setprop log.tag.dart3d.perf "\"\""' EXIT

dart3d_log() {
  adb -s "$serial" shell "logcat -d -T '$since' -s dart3d"
}

work=$(mktemp -d)
i=1
while [ "$i" -le "$runs" ]; do
  adb -s "$serial" shell am force-stop "$package"
  if [ "$fresh" = 1 ]; then
    adb -s "$serial" shell pm clear "$package" >/dev/null
  fi
  sleep 2
  since=$(adb -s "$serial" shell "date +'%m-%d %H:%M:%S.000'" | tr -d '\r')
  adb -s "$serial" shell am start -n "$activity" >/dev/null
  tries=0
  until dart3d_log | grep -q 'first frame rendered'; do
    tries=$((tries + 1))
    if [ "$tries" -gt 90 ]; then
      echo "run $i: no first frame after 90 s" >&2
      exit 1
    fi
    sleep 1
  done
  sleep "$settle"
  dart3d_log > "$work/run-$i.log"
  echo "run $i"
  grep -E 'start \+|material package .* compiled in' "$work/run-$i.log" |
    sed -E 's/^[0-9-]+ ([0-9:.]+) .* dart3d *: /  \1 /'
  i=$((i + 1))
done

echo "median over $runs runs, ms since process start"
for event in 'engine created' 'base materials loaded' 'scene installed' \
    'first frame submitted' 'first frame rendered'; do
  median=$(grep -h "start +.*ms $event" "$work"/run-*.log |
    sed -E 's/.*start \+([0-9]+)ms.*/\1/' | sort -n |
    awk '{ v[NR] = $1 } END { if (NR) print v[int((NR + 1) / 2)] }')
  printf '  %-22s %s\n' "$event" "${median:-n/a}"
done
