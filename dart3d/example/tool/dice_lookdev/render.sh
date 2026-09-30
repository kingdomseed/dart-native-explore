#!/usr/bin/env bash
# Dice look-dev (plan P3): renders every themed set in its environment,
# measures readability on the in-app top-down view, and builds the contact
# sheets. Output: docs/design/dice-lookdev/ (JPEG q90, full colour).
#
#   dart3d/example/tool/dice_lookdev/render.sh                  # every set
#   dart3d/example/tool/dice_lookdev/render.sh arcane northfield
#   PCT=50 SAMPLES=16 dart3d/example/tool/dice_lookdev/render.sh arcane   # quick preview
#   SHOTS=topdown dart3d/example/tool/dice_lookdev/render.sh              # the gate only
#
# Per set: <theme>-topdown.jpg (PRIMARY, 1179x2556, straight down like the
# app), <theme>-hero.jpg (3/4 view), <theme>-d4.jpg (d4 shard close-up),
# <theme>-d20.jpg for the sets in D20_SETS, and
# its entry in readability.json. Then all-sets-topdown.jpg, all-sets-hero.jpg,
# readability-crops.jpg (the seven dice of every set at phone pixels, from
# out/crops/) and the face map. Needs Blender 5.2 (Cycles on Metal).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
OUT="${OUT:-$REPO/docs/design/dice-lookdev}"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
PCT="${PCT:-100}"
SAMPLES="${SAMPLES:-0}"   # 0 = each environment's default
SHOTS="${SHOTS:-topdown,hero,d4}"
D20_SETS=" emberforged oldroad vermilion gemcutter "  # these also get a d20 close-up
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ALL=(dartnative-a emberforged frostbound arcane fateengine celestial hearthside oldroad northfield voltline vermilion gemcutter)
if [[ $# -gt 0 ]]; then SETS=("$@"); else SETS=("${ALL[@]/dartnative-a/dartnative}"); fi

mkdir -p "$OUT"
render() {  # render <theme> <shots> [extra render_set args...]
  local t="$1" shots="$2"; shift 2
  "$BLENDER" --background --python "$HERE/render_set.py" -- \
    --theme "$t" --shots "$shots" --check --pct "$PCT" --samples "$SAMPLES" \
    --out "$OUT" --tmp "$TMP/$t" "$@" 2>&1 | grep -E '^dice_lookdev|Error|Traceback'
}
for t in "${SETS[@]}"; do
  if [[ "$t" == dartnative ]]; then
    # three environment options (top-down + hero); the recommended one (a)
    # also gets d20/d4 close-ups and the real-time approximation of every shot
    for o in b c; do render dartnative "topdown,hero" --env-option "$o"; done
    render dartnative "topdown,hero,d20,d4" --env-option a
    render dartnative "topdown,hero,d20,d4" --env-option a --variant realtime
    continue
  fi
  render "$t" "$SHOTS$([[ "$SHOTS" == *hero* && "$D20_SETS" == *" $t "* ]] && echo ,d20)"
done

# Face map for the modelled set (same schema as assets/dice/dice_faces.json).
"$BLENDER" --background --python "$HERE/build_dice.py" -- \
  --faces-json "$HERE/dice_faces.lookdev.json" 2>&1 | grep -E '^dice_lookdev|Error|Traceback'

"$BLENDER" --background --python "$HERE/contact_sheet.py" -- --dir "$OUT" --themes "$(IFS=,; echo "${ALL[*]}")" 2>&1 \
  | grep -E '^dice_lookdev|Error|Traceback'
"$BLENDER" --background --python "$HERE/readability_check.py" -- --table "$OUT/readability.json" 2>/dev/null \
  | grep -E '^\|'
du -ch "$OUT"/*.jpg | tail -1
