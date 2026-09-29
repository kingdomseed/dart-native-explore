#!/usr/bin/env bash
# Rebuilds the DartNative logo showcase asset end to end (plan item P4):
#
#   assets_src/dn_logo/dn-logo.svg
#     -> Blender (build_dn_logo.py) -> assets_src/dn_logo/dn_logo.glb
#     -> flutter_scene 0.23.0's own importer (`bin/import.dart`,
#        `importGltfToFsceneb`, default settings = rgba8 images)
#     -> assets/showcase/dn_logo.fsceneb
#
# The importer is pure Dart but ships inside a Flutter package, so a
# plain `dart pub get` can't resolve it. This script points the host
# `dart` (the real Flutter SDK's; the importer never touches DartNative)
# at a generated package_config over the pub cache, pinned to the
# versions the other showcase assets were converted with. If a package
# is missing: `dart pub cache add <name> --version <v>`.
#
# Usage (from anywhere): dart3d/example/tool/dn_logo/build.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE="$(cd "$HERE/../.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
DART="${DART:-dart}"
PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
HOSTED="$PUB_CACHE/hosted/pub.dev"

"$BLENDER" --background --python "$HERE/build_dn_logo.py" 2>&1 \
  | grep -E '^dn_logo|Error|Traceback'

PKGS=(
  flutter_scene-0.23.0 scene-0.3.0 vector_math-2.4.3 image-4.10.1
  archive-4.3.0 crypto-3.0.7 typed_data-1.4.0 collection-1.19.1
  meta-1.19.0 path-1.9.1 xml-7.0.1 petitparser-7.0.2 posix-6.5.2
  ffi-2.2.0 args-2.7.0
)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
{
  echo '{"configVersion": 2, "packages": ['
  sep=''
  for p in "${PKGS[@]}"; do
    if [[ ! -d "$HOSTED/$p" ]]; then
      echo "missing $HOSTED/$p — dart pub cache add ${p%-*} --version ${p##*-}" >&2
      exit 1
    fi
    printf '%s{"name": "%s", "rootUri": "file://%s", "packageUri": "lib/"}\n' \
      "$sep" "${p%-*}" "$HOSTED/$p"
    sep=','
  done
  echo ']}'
} > "$TMP/package_config.json"

"$DART" --packages="$TMP/package_config.json" \
  "$HOSTED/flutter_scene-0.23.0/bin/import.dart" \
  --input "$EXAMPLE/assets_src/dn_logo/dn_logo.glb" \
  --output "$EXAMPLE/assets/showcase/dn_logo.fsceneb"
ls -l "$EXAMPLE/assets_src/dn_logo/dn_logo.glb" \
  "$EXAMPLE/assets/showcase/dn_logo.fsceneb"
