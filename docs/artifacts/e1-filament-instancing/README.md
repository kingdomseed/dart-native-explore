# E1 — Filament 1.77.3 upgrade + GPU `InstanceBuffer` instancing (D3)

Upgrade Filament `1.71.6` → `1.77.3` in lockstep across `filament-android`,
`filament-utils-android`, `filamat-android`, and `gltfio-android`, and replace
CPU-baked instancing with GPU `InstanceBuffer` instancing (`D3`).

## 1. Summary of Changes

1. **Filament 1.71.6 → 1.77.3 lockstep bump (`dart3d/android/build.gradle`)**
   - Updated `filamentVersion` to `1.77.3`.
   - Scoped `check*AarMetadata` rewrite strictly to `*-1.77.3` Filament AARs (`minCompileSdk=37` → `minCompileSdk=26` metadata header only; runtime AAR minSdk remains 21).
   - Updated `dart3d_jni.cpp` `D3FrameInfo` struct field layout to match Filament 1.77.3 `Renderer::FrameInfo` (`duration`, `gpuFrameComplete`, `vsync`, `displayPresent`, `presentDeadline`, `displayPresentInterval`, `compositionToPresentLatency`, `expectedPresentTime`, `frameId`, `valid`, `backendFrameComplete`, `submitFrameComplete`).
   - Regenerated all 20 shipped precompiled `.filamat` material packages under `dart3d/android/src/main/assets/dart3d_materials/` via `tool/bake_materials.sh`.

2. **Material shader & GPU `InstanceBuffer` instancing (`d3:instances`)**
   - Added `uniform float4 instanceColors[64]` to `MaterialPackages.kt` (indexed via `instanceColor(getInstanceIndex())`) so per-instance `attributes.color` multiplies base color on GPU `InstanceBuffer` chunks without expanding vertex buffers.
   - Partitioned `d3:instances` transforms in `FsceneRealizer.kt` (`decodeInstances`):
     - **Conformal invertible transforms (`posIndices`, `negIndices`):** Realized as GPU `InstanceBuffer` chunks of up to `MAX_GPU_INSTANCES_PER_CHUNK = 64` (Filament `CONFIG_MAX_INSTANCES` UBO limit), calling `InstanceBuffer.setLocalTransforms(flatTransforms, count, 0)` directly (avoiding `InstanceBuffer.Builder.localTransforms`'s `JNI_ABORT` native copy bug in Filament 1.77.3).
     - **Reflected conformal transforms (`det3x3 < 0`):** Bound to a cached reflected-tangent `VertexBuffer` (`MeshFactory.reflectedTangentCopy` / `GeoState.reflectedVertexBuffer`) with `culling(NONE)` material instances so tangent-frame lighting and backface visibility match CPU-baked parity.
     - **Non-conformal (non-uniform scale / shear) or singular transforms (`bakedIndices`):** Routed to `MeshFactory.bakeInstances` on a supplementary child entity (`rec.instanceBakedGpuMesh`) so cofactor inverse-transpose normals and re-orthogonalized tangents stay exact.
   - Preserved `rec.instanceBaseMaterial`, `rec.instanceMaterialInstances`, `rec.instanceChunkColors`, `applyMaterialToNode`, `upsertMaterial`, `applyVariantBinding`, and `redecodeDoubleSidedInstancesForMaterial` across async variant compilation and live material/texture updates.
   - Deferred collider-side vertex/index concatenation into `ensureInstanceColliderGeometry` so nodes without `convexHull` / `triMesh` / `concaveMesh` colliders skip CPU expansion entirely.

3. **Mesh particle emitters (`W18` / `ParticleRuntime.kt`)**
   - Migrated `MeshEmitterRuntime` from per-particle entities (`MAX_MESH_POOL = 64` per bucket) to a single instanced entity + `InstanceBuffer` per mesh bucket (`InstanceBuffer.setLocalTransforms(transforms, count, 0)` + `RenderableManager.setInstanceCount`).

## 2. 10,000-Instance Scene Performance (Before vs. After on A142)

Measured on Android phone **A142 (`00064149A002033`, Mali-G610 MC6)** using `--dart-define=DART3D_MODEL=w26 --dart-define=DART3D_W26_INSTANCES=10000` (10,000 procedural spheres, 42 vertices / 240 indices per sphere = 420,000 total vertices, 2,400,000 indices, plus a +3 s deferred `colors` payload arrival triggering a second realize pass):

| Metric | Before (CPU-baked `MeshFactory.bakeInstances`) | After (E1 GPU `InstanceBuffer`, 157 chunks) | Improvement |
|---|---|---|---|
| **Pass 1 realize time (Vulkan)** | `1,909 ms` (main-thread stall, 119 frames skipped) | **`27 ms`** | **70.7× faster** |
| **Pass 1 realize time (OpenGL)** | `1,935 ms` (main-thread stall, 165 frames skipped) | **`27 ms`** | **71.7× faster** |
| **Pass 2 realize (`colors` arrival, Vulkan)** | **CRASH (`java.lang.OutOfMemoryError`, 268 MB heap exhausted)** | **`16 ms`** | **OOM eliminated** |
| **Pass 2 realize (`colors` arrival, OpenGL)** | **CRASH (`java.lang.OutOfMemoryError`, 268 MB heap exhausted)** | **`28 ms`** | **OOM eliminated** |
| **Steady-state FPS (OpenGL, 10k instances)** | N/A (crashed on pass 2) | **`89.8 fps`** (`0/180` skipped, `frame p50=11.1ms p95=11.2ms`, `gpu p50=11.1ms`) | Full 90 Hz |
| **Steady-state FPS (Vulkan, 10k instances)** | N/A (crashed on pass 2) | **`79.8 fps`** (`frame p50=11.1ms p95=22.3ms`, `gpu p50=11.4ms p95=11.9ms`) | `11.1 ms` p50 |

Logs:
- Before (CPU-baked 10k): `a142-vk-w26-10k-cpu-baked.log`, `a142-gl-w26-10k-cpu-baked.log`
- After (GPU `InstanceBuffer` 10k): `a142-vk-w26-10k.log`, `a142-gl-w26-10k.log`, `a142-vk-w26-10k.png`, `a142-gl-w26-10k.png`

## 3. W26 Visual Parity vs. Pre-Upgrade Baseline (`android-c679636`)

Compared full-viewport 3D renders (`y ∈ [250, 2150]`) of `DART3D_MODEL=w26` (1,000 instances in 16 `InstanceBuffer` chunks + 14 procedural shapes + camera-facing polylines/billboards) against `docs/artifacts/integration/final/android-c679636/a142-{vk,gl}-w26.png`:

| Backend | Realize time (1,000 instances) | Viewport MAE | Pixels within `2/255` | Pixels within `5/255` | Steady-state FPS | Frame p50 / p95 |
|---|---|---|---|---|---|---|
| **A142 Vulkan** | `4 ms` | `0.964 / 255` (`0.38%`) | `96.26%` | `98.52%` | `89.8 fps` (`0/180` skipped) | `11.1 ms` / `11.2 ms` (`gpu p50=10.1ms`) |
| **A142 OpenGL** | `4 ms` | `0.963 / 255` (`0.38%`) | `96.25%` | `98.54%` | `89.8 fps` (`0/180` skipped) | `11.1 ms` / `11.2 ms` (`gpu p50=11.2ms`) |

## 4. T2 & T3 Device Matrix on A142 (Vulkan + OpenGL)

| Lane | A142 Vulkan | A142 OpenGL | Artifacts |
|---|---|---|---|
| **W26 instancing (1,000 instances)** | `89.8 fps`, `16 InstanceBuffer chunk(s)` in `4 ms`, 0 errors | `89.8 fps`, `16 InstanceBuffer chunk(s)` in `4 ms`, 0 errors | `a142-vk-w26.{png,log}`, `a142-gl-w26.{png,log}` |
| **W26 instancing (10,000 instances)** | `79.8 fps` (`p50=11.1ms`), `157 InstanceBuffer chunk(s)` in `27 ms` / `16 ms`, 0 errors | `89.8 fps` (`p50=11.1ms`), `157 InstanceBuffer chunk(s)` in `27 ms` / `28 ms`, 0 errors | `a142-vk-w26-10k.{png,log}`, `a142-gl-w26-10k.{png,log}` |
| **W22 materials conformance** | `89.8 fps` (`0/180` skipped), 0 material compile errors | `89.8 fps` (`0/180` skipped), 0 material compile errors | `a142-vk-materials.{png,log}`, `a142-gl-materials.{png,log}` |
| **T2 harness + W18 particles** | `90 fps` (`11.1 ms`), 75 entities, 13 bodies, 0 errors | `90 fps` (`11.1 ms`), 75 entities, 13 bodies, 0 errors | `a142-vk-harness.{png,log}`, `a142-gl-harness.{png,log}` |
| **T2 dice roll & settle** | `89.8 fps` (`0/180` skipped), 7 dice settled, 0 errors | `87.8 fps` (`p50=11.1ms p95=11.2ms`), 7 dice settled, 0 errors | `a142-vk-dice.{png,log}`, `a142-gl-dice.{png,log}` |

*Note on device coverage:* Android-only diff (`dart3d/android/**` + example `w26_scene.dart` `--dart-define=DART3D_W26_INSTANCES`); not run on iOS, Fire tablet, or Wacom tablet (only A142 connected).

## 5. Automated Codex Review Rounds (`gpt-6.1-sol`)

Three delegated Codex review rounds were run against the diff; every finding was verified and fixed before Round 3 closed clean:

- **Round 1 (7 findings, all fixed):**
  1. `ParticleRuntime.kt`: `InstanceBuffer.setLocalTransforms(transforms, count, 0)` argument order (`(transforms, count, offset)`).
  2. `FsceneRealizer.kt`: `InstanceBuffer.Builder.localTransforms` JNI `ReleaseFloatArrayElements(..., JNI_ABORT)` bug bypassed by calling `ib.setLocalTransforms(flatTransforms, count, 0)`.
  3. `MeshFactory.kt` / `FsceneRealizer.kt`: Added `MeshFactory.reflectedTangentCopy` + `GeoState.reflectedVertexBuffer` for `det3x3 < 0` instance chunks.
  4. `FsceneRealizer.kt`: Added `ensureInstanceColliderGeometry` so `convexHull` / `triMesh` / `concaveMesh` colliders on `d3:instances` nodes lazily build combined geometry.
  5. `FsceneRealizer.kt`: Updated `applyMaterialToNode` + `rec.instanceBaseMaterial` + `rec.instanceChunkColors` so live material updates preserve per-chunk `instanceColors` UBO and culling state.
  6. `dart3d/android/build.gradle`: Scoped `minCompileSdk=37` → `26` AAR metadata rewrite exclusively to `*-1.77.3` Filament AARs.
  7. `dart3d_jni.cpp`: Updated `D3FrameInfo` struct field order to match Filament 1.77.3 `Renderer::FrameInfo`.
- **Round 2 (3 findings, all fixed):**
  1. `Dart3dView.kt` / `FsceneRealizer.kt`: Replaced `rec.instanceBaseMaterial` before `engine.destroyMaterialInstance(old)` in `upsertMaterial`, and gated `applyVariantBinding` on `rec.instanceMaterialInstances.isNotEmpty()`.
  2. `FsceneRealizer.kt` / `Dart3dView.kt`: Checked `p.tag("doubleSided").d3Bool() == true` in `redecodeDoubleSidedInstancesForMaterial` and re-applied `ctx.applyVariantComponents()` after `onVariantCompiled`.
  3. `FsceneRealizer.kt`: Added `isConformalInvertible3x3(m)` check so non-uniformly scaled, sheared, or singular instance transforms route to `MeshFactory.bakeInstances` (`rec.instanceBakedGpuMesh`) while conformal transforms use GPU `InstanceBuffer`.
- **Round 3 (0 findings):** Closed clean ("No remaining actionable findings in Round 3.").
