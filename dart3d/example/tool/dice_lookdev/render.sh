#!/usr/bin/env bash
# Dice look-dev (plan P3): renders every themed set in its environment and
# builds the contact sheet. Output: docs/design/dice-lookdev/*.png
#
#   dart3d/example/tool/dice_lookdev/render.sh            # both batches
#   dart3d/example/tool/dice_lookdev/render.sh 1          # batch 1 only
#   PCT=40 SAMPLES=24 dart3d/example/tool/dice_lookdev/render.sh   # quick preview
#
# Batch 1 (full: hero, d20 close-up, environment mid-roll, phone in-app view):
#   emberforged frostbound arcane fateengine
# Batch 2 (hero + phone): celestial hearthside oldroad northfield voltline
#   vermilion gemcutter
#
# Needs Blender 5.2 (Cycles on Metal). ~1.5 h for everything on an M4.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
OUT="${OUT:-$REPO/docs/design/dice-lookdev}"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
PCT="${PCT:-100}"
SAMPLES="${SAMPLES:-0}"   # 0 = each environment's default
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BATCH1=(emberforged frostbound arcane fateengine)
BATCH2=(celestial hearthside oldroad northfield voltline vermilion gemcutter)
case "${1:-all}" in
  1) SETS=("${BATCH1[@]}") ;;
  2) SETS=("${BATCH2[@]}") ;;
  *) SETS=("${BATCH1[@]}" "${BATCH2[@]}") ;;
esac

mkdir -p "$OUT"
for t in "${SETS[@]}"; do
  shots="hero,phone"
  [[ " ${BATCH1[*]} " == *" $t "* ]] && shots="hero,d20,env,phone"
  "$BLENDER" --background --python "$HERE/render_set.py" -- \
    --theme "$t" --shots "$shots" --pct "$PCT" --samples "$SAMPLES" \
    --out "$OUT" --tmp "$TMP/$t" 2>&1 | grep -E '^dice_lookdev|Error|Traceback'
done

# Face map for the modelled set (same schema as assets/dice/dice_faces.json).
"$BLENDER" --background --python "$HERE/build_dice.py" -- \
  --faces-json "$HERE/dice_faces.lookdev.json" 2>&1 | grep -E '^dice_lookdev|Error|Traceback'

ALL="$(IFS=,; echo "${BATCH1[*]},${BATCH2[*]}")"
"$BLENDER" --background --python "$HERE/contact_sheet.py" -- --dir "$OUT" --themes "$ALL" 2>&1 \
  | grep -E '^dice_lookdev|Error|Traceback'
du -ch "$OUT"/*.png | tail -1
