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

## W22 — `KHR_materials_*` extension family

The importer already emits every extension's material properties into
the resource `properties` bag (upstream `fscene_emitter` vocabulary —
factors, texture refs, and `<slot>Transform` maps for
`KHR_texture_transform`). W22 teaches both realizers that vocabulary:
what a platform can map natively it maps; what it can't lands on a
documented approximation, each logged once per material
(`material <key>: <ext> → …`). A property name outside the handled
set warn-onces as *unhandled* — that warn is the conformance matrix's
`warn` row. `unlit` materials ignore extensions, matching the
importer (which never emits extension props for `KHR_materials_unlit`).

### Support matrix

`realized` = native mapping, no log. `approx` = documented
approximation or drop, logged once — the material still renders.

| Wire property | iOS (SceneKit) | Android (Filament 1.71.6) |
|---|---|---|
| `clearcoat` | approx — environment-reflection intensity on `reflective` | realized — `material.clearCoat` (+`clearCoatIorChange`) |
| `clearcoatTexture` | approx — R×factor baked into `reflective` intensity map | realized — `clearCoat × map.r` |
| `clearcoatRoughness` | approx — dropped | realized — `material.clearCoatRoughness` |
| `clearcoatRoughnessTexture` | approx — dropped | realized — `× map.g` |
| `clearcoatNormalTexture` | approx — dropped | realized — `material.clearCoatNormal` |
| `clearcoatNormalScale` | approx — dropped | realized — scales coat-normal xy |
| `sheenColor` | approx — `reflective` tint + material `fresnelExponent` (yields to clearcoat) | realized — `material.sheenColor` |
| `sheenRoughness` | approx — folded into `fresnelExponent` | realized — `material.sheenRoughness` |
| `sheenColorTexture` | approx — dropped | realized — `× map.rgb` |
| `sheenRoughnessTexture` | approx — dropped | realized — `× map.a` |
| `specular` | approx — no dielectric-F0 lever under `.physicallyBased` | realized — `material.specularFactor` |
| `specularColor` | approx — dropped | realized — `material.specularColorFactor` |
| `specularTexture` | approx — dropped | realized — `× map.a` |
| `specularColorTexture` | approx — dropped | realized — `× map.rgb` |
| `anisotropy` | approx — no anisotropic lobe | realized — `material.anisotropy` |
| `anisotropyRotation` | approx — dropped | realized — rotates `anisotropyDirection` |
| `anisotropyTexture` | approx — dropped | realized — `rg`→direction ([0,1]→[-1,1]), `b`→strength |
| `iridescence*` (6 props) | approx — logged drop | approx — logged drop (no Filament input) |
| `transmission` | approx — alpha-blend via `transparent` (α = 1−t), blend-pass depth rules | realized — `refractionMode: SCREEN_SPACE`, `material.transmission` |
| `transmissionTexture` | approx — baked α = 1−R×factor | realized — `× map.r` |
| `thickness` | approx — dropped (no refraction volume) | realized — SOLID→`thickness`, THIN→`microThickness` |
| `thicknessTexture` | approx — dropped | realized — `× map.g` |
| `attenuationColor`/`attenuationDistance` | approx — dropped | realized — `absorption = −ln(color)/distance` |
| `dispersion` | approx — logged drop | realized — `material.dispersion`, **SOLID refraction only**; otherwise warn+drop |
| `ior` | approx — no IOR lever | realized — `material.ior` (refraction, or reflectance alternative when lit) |
| `diffuseTransmission*` (4 props) | approx — logged drop | approx — logged drop (no Filament input) |

glTF `KHR_materials_volume` props without `transmission` are inert
(spec-consistent); both platforms warn-once and drop. An extension
present at its no-op defaults (e.g. `ior:1.5`, `dispersion:0`) needs
no variant and logs nothing.

### Android variant mechanics

Filament bakes feature availability into the compiled `Material`, so
each material resource computes an `extFlags` bitset at decode
(`FsceneRealizer.extFlagsFor` — a feature is *active* when a factor
deviates from its no-op default or a texture slot resolves).
`Dart3dView.materialForVariant(unlit, alphaMode, extFlags, boundSlots)`
lazily compiles `d3_lit_<blend>_e<flags>` on first use inside the render
callback — the same lane every decode runs — and caches it;
zero-flag materials stay on the six prebuilt variants. One registry
(`EXT_TEXTURE_SLOTS`/`EXT_FACTORS`) names every extension uniform,
sampler, and UV-transform prefix so the builder's declarations and
the instance writes can't drift. `view.setScreenSpaceRefractionEnabled(true)`
is set once at init — without it Filament skips the refraction pass.

**Sampler budget.** Filament's feature level 1 caps *declared*
samplers at 9 (8 when the transmission flag arms screen-space
refraction, which reserves one). A variant therefore declares — and
the shader samples — only the texture slots the material binds:
`boundTextureMask` computes the bound set (bits 0–4 base slots, bits
5+ `EXT_TEXTURE_SLOTS`), it rides in the variant key, and unbound
slots emit the factor-only term their 1×1 fallback used to produce.
A bound set that still exceeds the cap, or any filamat/engine
compile failure, warn-onces and degrades to the matching base
`d3_lit` prebuilt — the material renders base-PBR (extension lobes
dropped) instead of fataling on `check(pkg.isValid)` as it did
before the round-3 fix.

### iOS approximation notes

SceneKit's `.physicallyBased` exposes one specular lobe and no
refraction/sheen/anisotropy/iridescence inputs, so the iOS column is
mostly approximation: clearcoat rides `reflective` (environment
intensity, factor-gray or baked map), sheen reuses the same slot with
a fresnel exponent when clearcoat didn't claim it, and transmission
becomes straight alpha blend through `transparent` (per-texel alpha
bake, `.aOne`, depth reads on / writes off — the `blend` alphaMode
rules). Every drop is named in its once-per-material log.

### `KHR_texture_transform` on extension slots

Every extension texture slot decodes `<slot>Transform`: Android gets
per-slot `UVTransform`/`UVRotation`/`UVSet` uniforms (uv0/uv1 select,
same as the base slots); iOS gets `contentsTransform` +
`mappingChannel` on the bound property. Transforms on dropped
textures drop with them.

### Conformance harness

`dart3d/example/tool/conformance_runner.dart` walks the vendored
Khronos glTF-Sample-Assets catalog (`assets/conformance/catalog.json`
— a distilled manifest, not binary assets), encodes every catalog
material through the real `writeFscene` path, and classifies each
wire property against the support table above
(`kMaterialPropertySupport` — the doc and the table share one
contract). `dart run tool/conformance_runner.dart` emits the
per-asset pass/approx/warn matrix plus golden fixtures under
`dart3d/example/build/conformance/`; `test/material_extensions_test.dart`
asserts the matrix stays clean (no `warn` rows on either platform).
Upstream's 37 `smoke_render` scenes are classified for dart3d
applicability — 19 apply, 16 get generated fixture manifests; the
live golden comparison is the verify swarm's lane.
