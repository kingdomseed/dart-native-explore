# Integration T2 log excerpts (head ab62511; iOS a6b8c1a)

Fatal-pattern grep: `FATAL|Fatal signal|CS_FATAL|unrecoverable|E AndroidRuntime|init failed|cannot render|compile FAILED`.

## A142 Vulkan harness (logcat, app pid + crash lines)

Fatal-pattern lines: 0

```
09-28 17:13:50.421 dart3d  : re-realize replay: 51 plain op(s), 0 subtree(s)
09-28 17:13:54.213 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 17:14:02.213 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 17:14:02.215 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 17:14:14.213 dartnative: dart3d: w13 phase — environment effects toggles
09-28 17:14:30.214 dartnative: dart3d: w14 phase — render textures + views
09-28 17:14:58.214 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 17:15:01.234 dartnative: dart3d: wloose ccd pose=(3.30,0.38,2.60) PASS rests on slab
09-28 17:15:01.284 dartnative: dart3d: wloose bowl pose=(-2.28,-0.31,2.05) PASS contained
09-28 17:15:05.239 dartnative: dart3d: wloose margin pose=(5.50,0.08,0.50) PASS gap=0.53 above visual
09-28 17:15:07.737 dartnative: dart3d: wloose settle: 4709ms (roll 1 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:15:13.934 dartnative: dart3d: wloose settle: 4693ms (roll 2 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:15:20.133 dartnative: dart3d: wloose settle: 4697ms (roll 3 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:15:28.224 dartnative: dart3d: wloose settled event path: absent
09-28 17:15:32.215 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 17:15:44.233 dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
09-28 17:15:46.213 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 17:16:00.214 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 17:16:26.213 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 17:16:50.237 dartnative: dart3d: w25 lane complete — dice regression FAIL: die QJHVR8G00004Y rolled but no settle event within 10 s
09-28 17:16:52.216 dartnative: dart3d: w18 phase — particle emitters
09-28 17:16:52.228 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 17:17:08.236 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## A142 Vulkan dice/showcase/relaunch

Fatal-pattern lines: 0

```
09-28 17:17:42.384 dartnative: dart3d: rolled d4:1 d6:5 d8:6 d10t:60 d10u:4 d12:4 d20:20 d%:64  ·  total 100
```

## A142 GL harness incl. mid-harness tab switches

Fatal-pattern lines: 0

```
09-28 17:20:33.820 dart3d  : re-realize replay: 51 plain op(s), 0 subtree(s)
09-28 17:20:36.023 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 17:20:44.024 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 17:20:44.026 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 17:20:56.024 dartnative: dart3d: w13 phase — environment effects toggles
09-28 17:21:12.025 dartnative: dart3d: w14 phase — render textures + views
09-28 17:21:18.357 dartnative: dart3d: rolled d4:4 d6:1 d8:1 d10t:30 d10u:3 d12:2 d20:1 d%:33  ·  total 42
09-28 17:21:31.557 dartnative: dart3d: rolled d4:4 d6:1 d8:1 d10t:30 d10u:3 d12:2 d20:1 d%:33  ·  total 42
09-28 17:21:46.381 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 17:21:54.381 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 17:21:54.388 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 17:22:06.382 dartnative: dart3d: w13 phase — environment effects toggles
09-28 17:22:22.381 dartnative: dart3d: w14 phase — render textures + views
09-28 17:22:50.381 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 17:22:53.409 dartnative: dart3d: wloose ccd pose=(3.30,0.38,2.60) PASS rests on slab
09-28 17:22:53.458 dartnative: dart3d: wloose bowl pose=(-2.15,-0.31,2.05) PASS contained
09-28 17:22:57.416 dartnative: dart3d: wloose margin pose=(5.50,0.08,0.50) PASS gap=0.53 above visual
09-28 17:22:59.856 dartnative: dart3d: wloose settle: 4662ms (roll 1 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:23:06.057 dartnative: dart3d: wloose settle: 4693ms (roll 2 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:23:12.257 dartnative: dart3d: wloose settle: 4698ms (roll 3 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:23:20.391 dartnative: dart3d: wloose settled event path: absent
09-28 17:23:24.381 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 17:23:36.409 dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
09-28 17:23:38.381 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 17:23:52.381 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 17:24:18.381 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 17:24:42.400 dartnative: dart3d: w25 lane complete — dice regression FAIL: die GDNZH5000004Y rolled but no settle event within 10 s
09-28 17:24:44.380 dartnative: dart3d: w18 phase — particle emitters
09-28 17:24:44.391 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 17:25:00.392 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## A142 GL dice/showcase/relaunch

Fatal-pattern lines: 0

```
09-28 17:25:23.957 dartnative: dart3d: rolled d4:2 d6:1 d8:1 d10t:50 d10u:9 d12:1 d20:2 d%:59  ·  total 66
```

## iOS sim harness (dn run output)

Crash/Lost-connection lines: 1 (the one `Lost connection to device.` is the last line: my `simctl terminate` before the next run, after completion)

```
dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
dartnative: dart3d: w13 phase — environment effects toggles
dartnative: dart3d: w14 phase — render textures + views
dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
dartnative: dart3d: wloose ccd pose=(3.30,0.37,2.60) PASS rests on slab
dartnative: dart3d: wloose bowl pose=(-2.28,-0.31,2.05) PASS contained
dartnative: dart3d: wloose margin pose=(5.50,0.10,0.50) PASS gap=0.55 above visual
dartnative: dart3d: wloose settle: 4696ms (roll 1 via pose-quiescence, die (-0.00,-0.00,2.51))
dartnative: dart3d: wloose settle: 4697ms (roll 2 via pose-quiescence, die (-0.00,-0.00,2.51))
dartnative: dart3d: wloose settle: 4697ms (roll 3 via pose-quiescence, die (-0.00,-0.00,2.51))
dartnative: dart3d: wloose settled event path: absent
dartnative: dart3d: w15 phase — lazy prefab subtree streaming
dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
dartnative: dart3d: w25 phase — LUT + effects matrix lanes
dartnative: dart3d: w25 lane complete — dice regression FAIL: die VD37P7800004Y rolled but no settle event within 10 s
dartnative: dart3d: w18 phase — particle emitters
dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## iOS sim dice

Crash/Lost-connection lines: 1 (the one `Lost connection to device.` is the last line: my `simctl terminate` before the next run, after completion)

```
dartnative: dart3d: rolled d4:3 d6:1 d8:1 d10t:0 d10u:0 d12:1 d20:1 d%:100  ·  total 107
```

## Pre-fix crashes (for the record)

```
A142 Vulkan harness (pre-e0c5b41): Fatal signal 7 (SIGBUS), BUS_ADRALN, pc 0x12
  #01 libfilament-jni.so filament::ColorGrading::Builder::build(Engine&)+0x130c  (at 'w25 LUT blend 0.35')
A142 Vulkan harness (e0c5b41, pre-ab62511): Fatal signal 11 (SIGSEGV), SEGV_ACCERR
  #00 libfilament-jni.so filament::ColorGrading::Builder::customLut(...)+4
  #01 libfilament-jni.so Java_com_google_android_filament_ColorGrading_nBuilderCustomLut+168
A142 Vulkan materials lane (6b4dcca..ff3d591): [mali]CET: cpu queue set unrecoverable error;
  mali 13000000.mali: Unhandled Page fault in AS1; CS_FATAL.EXCEPTION_TYPE: 0x48 (CS_BUS_FAULT)
```
