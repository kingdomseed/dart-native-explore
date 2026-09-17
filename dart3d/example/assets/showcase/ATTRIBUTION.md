# Showcase assets

The `.fsceneb` files here were converted from the upstream
[flutter_scene](https://github.com/bdero/flutter_scene) example app's
`assets_src/*.glb` by upstream's own importer (`bin/importer.dart`,
`importGltfToFsceneb`), with default settings (no texture compression —
image payloads stay `rgba8`).

The `.fscene` files are upstream-authored scenes copied verbatim from
`examples/scenes/`.

| file | source | exercises |
| --- | --- | --- |
| `dash.fsceneb` | `assets_src/dash.glb` | skinning (35 joints), 9 animations, 2×2048² rgba8 textures |
| `fcar.fsceneb` | `assets_src/fcar.glb` | 17 meshes / 39 geometries / 11 materials |
| `flutter_logo_baked.fsceneb` | `assets_src/flutter_logo_baked.glb` | 1 texture, 1 animation |
| `two_triangles.fsceneb` | `assets_src/two_triangles.glb` | minimal skinning, 2 animations |
| `prefab_demo.fscene` | `examples/scenes/` | prefab instances of `tree_prefab.fscene` |
| `tree_prefab.fscene` | `examples/scenes/` | prefab source document |
| `cube.fscene` | `examples/scenes/` | single procedural cube |
| `playground.fscene` | `examples/scenes/` | 4 procedural meshes |

## License

flutter_scene is MIT-licensed, copyright (c) 2023 Brandon DeRosier.
See `LICENSE.flutter_scene` in this directory for the full text.

The dice set under `assets/dice/` is the "Retro Classic Recessed" set,
generated in-house for the tome_keeper project (see
`tome_keeper/assets/dice/README.md`); converted to `.fsceneb` by the
same upstream importer.
