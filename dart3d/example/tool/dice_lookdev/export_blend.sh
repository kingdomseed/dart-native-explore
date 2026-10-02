#!/usr/bin/env bash
# Save the procedural dice rooms and the asset libraries as .blend files for
# use in the Blender GUI (see export_blend.py). The output is not committed.
#
#   dart3d/example/tool/dice_lookdev/export_blend.sh                 # everything
#   dart3d/example/tool/dice_lookdev/export_blend.sh rooms arcane northfield
#   dart3d/example/tool/dice_lookdev/export_blend.sh library         # room-prop asset library
#   dart3d/example/tool/dice_lookdev/export_blend.sh dice            # dice asset library
#   OUT=/some/dir MAX_LOAD=8 dart3d/example/tool/dice_lookdev/export_blend.sh
#
# Output (default ~/repos/dart-native-explore-media/blend):
#   rooms/<set>.blend, library/dice-room-assets.blend, library/dice-sets.blend,
#   library/blender_assets.cats.txt, logs/<job>.log
# One Blender at a time, niced; each job waits until the 1-minute load average
# is below MAX_LOAD. Nothing is rendered apart from Blender's asset previews.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-$HOME/repos/dart-native-explore-media/blend}"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
MAX_LOAD="${MAX_LOAD:-8}"
THREADS="${THREADS:-6}"
SETS=(arcane celestial dartnative emberforged fateengine frostbound gemcutter hearthside northfield oldroad vermilion voltline)
TMP="$(mktemp -d)"  # generated atlases and masks; they end up packed in the .blend files
mkdir -p "$OUT/logs"

wait_for_load() {
  while :; do
    local load
    load="$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || uptime | sed 's/.*averages*: *//' | awk '{print $1}')"
    awk -v l="$load" -v m="$MAX_LOAD" 'BEGIN { exit !(l < m) }' && return
    echo "export_blend: load $load >= $MAX_LOAD, waiting"
    sleep 60
  done
}

job() {  # job <log name> <export_blend.py args...>
  local name="$1"; shift
  wait_for_load
  local status=0
  PYTHONDONTWRITEBYTECODE=1 nice -n 10 "$BLENDER" --factory-startup --background --threads "$THREADS" \
    --python "$HERE/export_blend.py" -- "$@" --out "$OUT" --tmp "$TMP/$name" >"$OUT/logs/$name.log" 2>&1 || status=$?
  grep -E '^export_blend|Error|Traceback' "$OUT/logs/$name.log" || true
  if [[ $status -ne 0 ]] || grep -q 'Traceback (most recent call last)' "$OUT/logs/$name.log"; then
    echo "export_blend: FAILED $name (see $OUT/logs/$name.log)"
    FAILED+=("$name")
  fi
}

FAILED=()
what="${1:-all}"
[[ $# -gt 0 ]] && shift
case "$what" in
  all|rooms|dice|library) ;;
  *) echo "usage: $0 [all|rooms [set...]|dice|library]" >&2; exit 2 ;;
esac
if [[ "$what" == rooms && $# -gt 0 ]]; then SETS=("$@"); fi
if [[ "$what" == all || "$what" == rooms ]]; then
  for t in "${SETS[@]}"; do job "room-$t" --room "$t"; done
fi
if [[ "$what" == all || "$what" == dice ]]; then job dice --dice; fi
if [[ "$what" == all || "$what" == library ]]; then job library --library; fi
if [[ ${#FAILED[@]} -gt 0 ]]; then echo "export_blend: failed jobs: ${FAILED[*]}"; exit 1; fi
echo "export_blend: done -> $OUT"
