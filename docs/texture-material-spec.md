# Texture and material payload spec (W4)

How `dart3d` realizes `TextureResource` chunks and material texture
slots on SceneKit (iOS) and Filament (Android), tracking
`scene-0.3.0`/`flutter_scene-0.23.0` wire vocabulary. Extends the
deferred-payload lifecycle from `payload-geometry-spec.md`.

## Wire contract (upstream-true)

**Texture resource** (`resources` map):

```json
"<id>": {"kind": "texture",
         "payload": "<payload-id>"   // xor
         "ref": "<asset-key>",
         "content": "color|data|normal"}   // default "color"
```

**Image payload** (`payloads` map — bytes stream as `payload`
mutations like every other chunk):

```json
"<id>": {"encoding": "image", "format": "rgba8",
         "width": W, "height": H, "length": N}
```

| `format`   | Bytes                                   | Required fields   |
|------------|-----------------------------------------|-------------------|
| `rgba8`    | raw RGBA8, `length == width*height*4`   | `width`, `height` |
| `ktx2`     | KTX2 container (own mip chain)          | none (in header)  |
| other/absent | encoded container — magic bytes decide (PNG, JPEG) | none |

Upstream emits only `rgba8` and `ktx2`; encoded containers are the
asset/`format`-agnostic path (`imageFromBytes` on the runtime side).
dart3d accepts all three.

**Material slots** (`MaterialResource.properties`; a `physicallyBased`
or `unlit` material). Factor × texture always applies — never
texture-instead-of-factor:

| Property                     | Value type | Meaning                        |
|------------------------------|------------|--------------------------------|
| `baseColor`                  | color      | albedo factor (default white)  |
| `baseColorTexture`           | ref→tex    | albedo map (sRGB decode)       |
| `metallic`                   | double     | factor (default 0)             |
| `roughness`                  | double     | factor (default 0.5)           |
| `metallicRoughnessTexture`   | ref→tex    | glTF-packed: metallic=B, roughness=G |
| `normalTexture`              | ref→tex    | tangent-space normal map       |
| `normalScale`                | double     | normal map strength (default 1)|
| `occlusionTexture`           | ref→tex    | AO map, R channel              |
| `occlusionStrength`          | double     | AO strength (default 1)        |
| `emissive`                   | color      | emissive factor (default black)|
| `emissiveStrength`           | double     | KHR_materials_emissive_strength|
| `emissiveTexture`            | ref→tex    | emissive map (sRGB decode)     |
| `doubleSided`                | bool       | already decoded                |
| `alphaMode`/`alphaCutoff`    | str/double | opaque|mask|blend (W4: decode; blend W7) |

**Per-slot UV transform** — KHR_texture_transform, emitted as
`<slot>TextureTransform`:

```json
"baseColorTextureTransform": {"offset": [x,y], "scale": [x,y],
                              "rotation": rad, "texCoord": 0}
```

Effective uv: `uv' = offset + Rz(rotation) · scale ⊙ uv` (glTF
convention — offset applied after scale+rotation). `texCoord` selects
the UV channel; **only channel 0 is realized in W4** — the payload
vertex path carries uv0 only (iOS drops uv1 at decode; the Android
52B vertex has one UV slot). `texCoord != 0` → log-once, treat as 0.
Carrying uv1 is a later vertex-format revision, not W4 scope.

## Platform realization

### iOS — SceneKit

- `rgba8`: `CGImage` over a `CGDataProvider` — 8bpc, 32bpp, `w*4`
  bytes/row, `byteOrder32Big | alphaLast` (straight alpha). Color
  space by `content`: `color` → `sRGB`, `data`/`normal` →
  `linearSRGB`. Wrapped in `UIImage` for `SCNMaterialProperty`.
- Encoded containers: `UIImage(data:)` (UIImage handles the
  colorspace tagging).
- `ref` asset: `UIImage(named:)`; miss → log-once + slot absent.
- `ktx2`: log-once `texture <id>: ktx2 needs a basisu/ASTC path —
  deferred`, slot absent. (No transcoder in W4.)
- Slots: `baseColorTexture` → `diffuse.contents`;
  `normalTexture` → `normal.contents` (+`intensity` from
  `normalScale`); `occlusionTexture` → `ambientOcclusion.contents`;
  `emissiveTexture` → `emission.contents`.
- **MR channel split**: SceneKit samples `metalness`/`roughness`
  textures as scalar — it cannot read glTF's packed G/B. Split the
  decoded RGBA CPU-side into two gray `CGImage`s (G→roughness,
  B→metallic), and **bake the factors in** (`roughness`,
  `metallic`) since a texture-backed `SCNMaterialProperty` does not
  multiply a color factor.
- `emissive` factor × `emissiveTexture`: same bake — multiply the
  factor RGB into the decoded pixels when both are present.
- UV transform → `contentsTransform` (`CATransform3D` built as
  `translate(offset) · rotate(rotation) · scale(scale)`).
- Mips: SceneKit generates them; `content: normal` cannot steer the
  downsample — deviation from upstream's renormalizing mips, noted.

### Android — Filament

- Upload: `Texture.Builder().sampler(SAMPLER_2D).levels(mipCount)
  .format(...)` then `setImage(PixelBufferDescriptor)` +
  `generateMipmaps(engine)`. `content: color` → `SRGB8_A8`
  (hardware sRGB decode — upstream's shader-side SRGBToLinear,
  same result); `data`/`normal` → `RGBA8`.
- `rgba8`: `PixelBufferDescriptor(bytes, Format.RGBA, UBYTE)`.
- Encoded: `BitmapFactory.decodeByteArray` → `ARGB_8888` memory is
  B,G,R,A → upload `Format.BGRA`, or repack to RGBA.
- `ref` asset: `context.assets.open(key)` → decode; miss → log-once.
- `ktx2`: same deferred log-once (Filament could consume KTX — kept
  for parity with iOS until a transcoder lands).
- Custom material (`Dart3dView.buildMaterial`) gains samplers
  `baseColorMap`, `normalMap`, `metallicRoughnessMap`,
  `occlusionMap`, `emissiveMap` plus per-slot `float4
  <slot>UVTransform` `(offset.xy, scale.xy)` and `float
  <slot>UVRotation`.
- **Neutral 1×1 fallbacks** bound at material-instance creation so
  the shader always samples: white for `baseColorMap`, flat
  `(128,128,255,255)` for `normalMap`, white G/B for `mrMap`
  (samples as factor 1 → factor-only result), white for
  `occlusionMap`, black for `emissiveMap`. Missing texture ==
  factor-only appearance — lane 9's fallback.
- `metallicRoughnessMap`: `metallic = tex.b * metallic`,
  `roughness = tex.g * roughness` (no split needed — the shader
  reads the packed channels).
- Normal mapping: TBN from the tangent-frame quaternion attribute
  (`getWorldTangentFrame` or manual TBN); `normalScale` scales the
  map's xy before normalize.
- Emissive: `material.emissive = vec4(emissiveFactor.rgb *
  emissiveTex.rgb * emissiveStrength, 0.0)`. **`emissive.w` must be
  0** — Filament attenuates by `mix(1.0, getExposure(), w)`, and
  `w=1.0` crushed emission to black under this view's exposure. The
  unattenuated write matches both glTF's additive-emissive semantics
  and SceneKit's `emission` (which has no exposure weighting). The
  factor uniform is named `emissiveColor`, not `emissive` — sharing
  the `MaterialInputs.emissive` field name invites a codegen
  collision.
- UV transform in shader per slot.

## Deferred lifecycle (reuses W3 machinery)

- Manifest pass: texture whose payload hasn't landed →
  `deferredResourceIds` + `texture <id>: awaiting payload`. A
  material referencing it binds the fallback for now.
- `payload` arrival → full re-realize (existing path) → texture
  uploads, material slots bind. `d3Log` the upload ms + size.
- Malformed (rgba8 length ≠ w·h·4, undecodable container) →
  log-once `texture <id>: <reason>`; slot binds fallback; process
  survives.

## Surgical updates (lane 10 — `upsertResource`, `upsertPayload`)

Full re-realize would respawn physics bodies mid-scene — wrong for a
runtime texture swap. Slice of W5 pulled forward:

- Host retains the resource dictionaries at `install` (iOS drops
  them today — keep `materials`/`textures`/`geometries` plus a
  `textureConsumers: [texKey: [(material, slot)]]` / Android
  `[(MaterialInstance, slotParam)]` binding map built at material
  decode).
- `upsertResource` `{id, resource:{kind:"texture",...}}`: re-decode
  that resource only; on success rebind every recorded consumer
  slot. `kind:"material"`: re-decode + re-attach to recorded
  consumer geometries. Other kinds → log-once `not implemented`.
- `upsertPayload` `{id, bytes}`: store into `payloadStore`; if the
  payload backs a texture, re-upload + rebind. Other encodings →
  store + log-once `deferred to W5`.

## W4 lanes → probes

| Lane | Probe in `feature_scene`                                     |
|------|--------------------------------------------------------------|
| 2/3  | existing `textured` checker box (PNG-encoded path)            |
| 8*   | W3 UV payload quad retargeted to a textured material          |
| 4    | rgba8 normal-mapped quad (generated brick pattern) + MR map   |
| 5    | emissive-texture quad (dark cells, bright dots)               |
| 6    | second checker box, `baseColorTextureTransform` offset+scale  |
| 7/8  | texture payload with `bytes:null`, `sendPayload` at +3s       |
| 9    | material → texture → payload that never arrives               |
| 10   | `upsertResource` at +6s repoints checkerTex → inverted payload |

*W3 lane 8 closes here.

Perf: log upload ms; 1k texture < 1s; frame time within 15% of the
W3 baseline (iOS ~60fps, Android ~90fps).
