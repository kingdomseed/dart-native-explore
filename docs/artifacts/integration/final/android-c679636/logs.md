# Android T2 — origin/stabilize/android @ c679636 (A142, release)

dn analyze clean; dn test dart3d 273/273, example 126/126.

## a5-vk-harness

fatal-pattern lines (`Fatal signal|CS_FATAL|unrecoverable|Page fault|E AndroidRuntime|FATAL`): 0  ·  surgical-journal 2048 warn: 0  ·  init-failed/cannot render: 0

```
09-28 23:09:17.600 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:09:17.688 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:09:17.695 dart3d  : re-realize replay: 55 plain op(s), 0 subtree(s)
09-28 23:09:21.305 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 23:09:29.305 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 23:09:29.307 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 23:09:41.305 dartnative: dart3d: w13 phase — environment effects toggles
09-28 23:09:57.305 dartnative: dart3d: w14 phase — render textures + views
09-28 23:09:57.322 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:09:59.327 dart3d  : views applied: 2 entries (0 screen, 2 rts)
09-28 23:10:01.321 dart3d  : views applied: 3 entries (0 screen, 2 rts)
09-28 23:10:03.318 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:10:25.305 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 23:10:28.337 dartnative: dart3d: wloose ccd pose=(3.30,0.38,2.60) PASS rests on slab
09-28 23:10:28.389 dartnative: dart3d: wloose bowl pose=(-2.28,-0.31,2.05) PASS contained
09-28 23:10:32.337 dartnative: dart3d: wloose margin pose=(5.50,0.08,0.50) PASS gap=0.53 above visual
09-28 23:10:34.791 dartnative: dart3d: wloose settle: 4677ms (roll 1 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 23:10:40.992 dartnative: dart3d: wloose settle: 4699ms (roll 2 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 23:10:47.186 dartnative: dart3d: wloose settle: 4692ms (roll 3 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 23:10:55.314 dartnative: dart3d: wloose settled event path: absent
09-28 23:10:59.305 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 23:11:11.323 dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
09-28 23:11:13.304 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 23:11:15.315 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:11:19.333 dart3d  : views applied: 2 entries (1 screen, 1 rts)
09-28 23:11:22.316 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:11:25.323 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:11:27.319 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 23:11:53.311 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 23:12:17.321 dartnative: dart3d: w25 lane complete — dice regression FAIL: die 11ECVV800004Y rolled but no settle event within 10 s
09-28 23:12:19.305 dartnative: dart3d: w18 phase — particle emitters
09-28 23:12:19.317 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 23:12:35.318 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## a5-vk-surfaces

fatal-pattern lines (`Fatal signal|CS_FATAL|unrecoverable|Page fault|E AndroidRuntime|FATAL`): 22  ·  surgical-journal 2048 warn: 0  ·  init-failed/cannot render: 0

```
```

## a5-gl-harness

fatal-pattern lines (`Fatal signal|CS_FATAL|unrecoverable|Page fault|E AndroidRuntime|FATAL`): 0  ·  surgical-journal 2048 warn: 0  ·  init-failed/cannot render: 0

```
09-28 23:22:27.430 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:22:27.503 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:22:27.510 dart3d  : re-realize replay: 55 plain op(s), 0 subtree(s)
09-28 23:22:30.514 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 23:22:38.513 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 23:22:38.515 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 23:22:50.514 dartnative: dart3d: w13 phase — environment effects toggles
09-28 23:23:06.516 dartnative: dart3d: w14 phase — render textures + views
09-28 23:23:06.535 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:23:08.535 dart3d  : views applied: 2 entries (0 screen, 2 rts)
09-28 23:23:10.532 dart3d  : views applied: 3 entries (0 screen, 2 rts)
09-28 23:23:12.530 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:23:34.514 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 23:23:37.544 dartnative: dart3d: wloose ccd pose=(3.30,0.38,2.60) PASS rests on slab
09-28 23:23:37.596 dartnative: dart3d: wloose bowl pose=(-2.28,-0.31,2.05) PASS contained
09-28 23:23:41.543 dartnative: dart3d: wloose margin pose=(5.50,0.08,0.50) PASS gap=0.53 above visual
09-28 23:23:43.996 dartnative: dart3d: wloose settle: 4673ms (roll 1 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 23:23:50.202 dartnative: dart3d: wloose settle: 4705ms (roll 2 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 23:23:56.394 dartnative: dart3d: wloose settle: 4689ms (roll 3 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 23:24:04.521 dartnative: dart3d: wloose settled event path: absent
09-28 23:24:08.515 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 23:24:20.532 dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
09-28 23:24:22.515 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 23:24:24.532 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:24:28.528 dart3d  : views applied: 2 entries (1 screen, 1 rts)
09-28 23:24:31.525 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:24:34.526 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:24:36.514 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 23:25:02.514 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 23:25:26.529 dartnative: dart3d: w25 lane complete — dice regression FAIL: die 3Q9MPR000004Y rolled but no settle event within 10 s
09-28 23:25:28.514 dartnative: dart3d: w18 phase — particle emitters
09-28 23:25:28.527 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 23:25:44.533 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## a5-gl-surfaces

fatal-pattern lines (`Fatal signal|CS_FATAL|unrecoverable|Page fault|E AndroidRuntime|FATAL`): 0  ·  surgical-journal 2048 warn: 0  ·  init-failed/cannot render: 0

```
09-28 23:26:52.995 dartnative: dart3d: rolled d4:3 d6:4 d8:2 d10t:50 d10u:6 d12:9 d20:13 d%:56  ·  total 87
09-28 23:26:57.614 dartnative: dart3d: showcase — dash: 41 nodes · 2 geo · 2 mat · 2 tex · 1 skins · 9 anims
09-28 23:26:57.810 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:26:58.230 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:09.693 dartnative: dart3d: showcase — fcar: 22 nodes · 40 geo · 12 mat
09-28 23:27:09.734 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:09.800 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:22.087 dartnative: dart3d: showcase — logo: 5 nodes · 2 geo · 2 mat · 1 tex · 1 anims
09-28 23:27:22.095 dart3d  : animation 26147370056024077: awaiting channel payloads
09-28 23:27:22.110 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:22.113 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:27.259 dartnative: dart3d: showcase — triangles: 8 nodes · 3 geo · 3 mat · 1 skins · 2 anims
09-28 23:27:27.268 dart3d  : animation 26147370056024090: awaiting channel payloads
09-28 23:27:27.268 dart3d  : animation 26147370056024103: awaiting channel payloads
09-28 23:27:27.283 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:27.286 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:32.455 dartnative: dart3d: showcase — prefabs: 11 nodes · 4 geo · 4 mat
09-28 23:27:32.477 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:37.660 dartnative: dart3d: showcase — cube: 5 nodes · 2 geo · 2 mat
09-28 23:27:37.679 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:42.895 dartnative: dart3d: showcase — playground: 8 nodes · 5 geo · 5 mat
09-28 23:27:42.921 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:52.087 dartnative: dart3d: showcase — materials: 11 nodes · 8 geo · 8 mat · 3 tex
09-28 23:27:52.101 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:27:52.187 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:28:04.463 dartnative: dart3d: showcase — glb: 6 nodes · 2 geo · 2 mat · 1 tex
09-28 23:28:04.484 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:28:04.501 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:28:16.906 dartnative: dart3d: showcase — roundtrip: 11 nodes · 8 geo · 8 mat · 3 tex
09-28 23:28:16.918 dartnative: dart3d: showcase — roundtrip: 11 nodes · 10/10 chunks re-sent after the JSON leg
09-28 23:28:16.929 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:28:16.943 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:28:16.958 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:28:22.113 dartnative: dart3d: showcase — w26: 19 nodes · 1 geo · 15 mat
09-28 23:28:22.135 dart3d  : d3:instances node -1778853751809900515: transforms unresolved
09-28 23:28:22.136 dart3d  : d3:instances node -1778853751809900514: 'billboard' overrides shape/geometry
09-28 23:28:22.152 dart3d  : views applied: 0 entries (0 screen, 0 rts)
```

## a5-vk-surfaces: the fatal lines (Vulkan warm relaunch)

```
09-28 23:15:45.219 16970 16970 E AndroidRuntime: FATAL EXCEPTION: main
09-28 23:15:45.219 16970 16970 E AndroidRuntime: Process: com.jasonholtdigital.dart3d_example, PID: 16970
09-28 23:15:45.219 16970 16970 E AndroidRuntime: java.lang.RuntimeException: Postcondition
09-28 23:15:45.219 16970 16970 E AndroidRuntime: in present:140
09-28 23:15:45.219 16970 16970 E AndroidRuntime: reason: Cannot present in swapchain. error=-1000000000
09-28 23:15:45.219 16970 16970 E AndroidRuntime: 	at com.google.android.filament.Renderer.nBeginFrame(Native Method)
```

## Vulkan warm-relaunch repro (HOME + relaunch via monkey, showcase dash)

```
c679636 native : crash iter 1 — RuntimeException Postcondition in enumerate:76 'enumerate size error' at Renderer.nBeginFrame
c679636 native : (surface pass) — Postcondition in present:140 'Cannot present in swapchain. error=-1000000000' at Renderer.nBeginFrame
68f402d native : crash iter 1
d5c87a4 native : crash iter 1
origin/main native (1147af6): crash iter 1 — native abort 'vkCreateAndroidSurfaceKHR with error=-1000000001'
GL, c679636    : 5/5 relaunches, 0 new am_crash
```
