# Final T2 log excerpts — stabilize/final-t2 7c6dbcb

## ft-vk-harness (logcat)

Fatal-pattern lines (`FATAL|Fatal signal|CS_FATAL|unrecoverable|E AndroidRuntime|init failed|cannot render|compile FAILED`): 0
surgical journal 2048 warn: 0

```
09-28 17:37:27.920 dart3d  : re-realize replay: 51 plain op(s), 0 subtree(s)
09-28 17:37:31.684 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 17:37:39.682 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 17:37:39.684 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 17:37:51.687 dartnative: dart3d: w13 phase — environment effects toggles
09-28 17:38:07.682 dartnative: dart3d: w14 phase — render textures + views
09-28 17:38:35.682 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 17:38:38.712 dartnative: dart3d: wloose ccd pose=(3.30,0.38,2.60) PASS rests on slab
09-28 17:38:38.768 dartnative: dart3d: wloose bowl pose=(-2.28,-0.31,2.05) PASS contained
09-28 17:38:42.713 dartnative: dart3d: wloose margin pose=(5.50,0.08,0.50) PASS gap=0.53 above visual
09-28 17:38:45.213 dartnative: dart3d: wloose settle: 4709ms (roll 1 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:38:51.413 dartnative: dart3d: wloose settle: 4698ms (roll 2 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:38:57.612 dartnative: dart3d: wloose settle: 4696ms (roll 3 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:39:05.692 dartnative: dart3d: wloose settled event path: absent
09-28 17:39:09.683 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 17:39:21.702 dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
09-28 17:39:23.682 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 17:39:37.682 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 17:40:03.685 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 17:40:27.705 dartnative: dart3d: w25 lane complete — dice regression FAIL: die 02JNYM800004Y rolled but no settle event within 10 s
09-28 17:40:29.687 dartnative: dart3d: w18 phase — particle emitters
09-28 17:40:29.698 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 17:40:29.706 dart3d  : upsertPayload 2006474889510256756: texture 2006474889510256757 re-uploaded, rebound 0 consumer(s)
09-28 17:40:45.700 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## ft-vk-surfaces (logcat)

Fatal-pattern lines (`FATAL|Fatal signal|CS_FATAL|unrecoverable|E AndroidRuntime|init failed|cannot render|compile FAILED`): 0
surgical journal 2048 warn: 0

```
09-28 17:41:21.463 dartnative: dart3d: rolled d4:3 d6:4 d8:2 d10t:90 d10u:5 d12:2 d20:19 d%:95  ·  total 125
09-28 17:42:46.663 dartnative: dart3d: rolled d4:4 d6:1 d8:1 d10t:30 d10u:3 d12:2 d20:1 d%:33  ·  total 42
```

## ft-gl-harness (logcat)

Fatal-pattern lines (`FATAL|Fatal signal|CS_FATAL|unrecoverable|E AndroidRuntime|init failed|cannot render|compile FAILED`): 0
surgical journal 2048 warn: 0

```
09-28 17:46:52.055 dart3d  : re-realize replay: 51 plain op(s), 0 subtree(s)
09-28 17:46:54.247 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 17:47:02.247 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 17:47:02.249 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 17:47:14.247 dartnative: dart3d: w13 phase — environment effects toggles
09-28 17:47:30.247 dartnative: dart3d: w14 phase — render textures + views
09-28 17:47:58.248 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 17:48:01.277 dartnative: dart3d: wloose ccd pose=(3.30,0.38,2.60) PASS rests on slab
09-28 17:48:01.327 dartnative: dart3d: wloose bowl pose=(-2.28,-0.31,2.05) PASS contained
09-28 17:48:05.279 dartnative: dart3d: wloose margin pose=(5.50,0.08,0.50) PASS gap=0.53 above visual
09-28 17:48:07.728 dartnative: dart3d: wloose settle: 4667ms (roll 1 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:48:13.929 dartnative: dart3d: wloose settle: 4697ms (roll 2 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:48:20.127 dartnative: dart3d: wloose settle: 4697ms (roll 3 via pose-quiescence, die (-0.00,-0.00,2.50))
09-28 17:48:28.254 dartnative: dart3d: wloose settled event path: absent
09-28 17:48:32.251 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 17:48:44.285 dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
09-28 17:48:46.247 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 17:49:00.248 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 17:49:26.247 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 17:49:50.284 dartnative: dart3d: w25 lane complete — dice regression FAIL: die PA34CBG00004Y rolled but no settle event within 10 s
09-28 17:49:52.247 dartnative: dart3d: w18 phase — particle emitters
09-28 17:49:52.259 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 17:49:52.289 dart3d  : upsertPayload -7467254510470037388: texture -7467254510470037387 re-uploaded, rebound 0 consumer(s)
09-28 17:50:08.262 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## ft-vk-materials-cold (logcat)

CS_FATAL/unrecoverable lines: 0  (whole device buffer at collection time)

## ft-ios-harness (dn run output)

fatal/crash lines: 0

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
dartnative: dart3d: wloose settle: 4694ms (roll 1 via pose-quiescence, die (0.00,-0.00,2.49))
dartnative: dart3d: wloose settle: 4697ms (roll 2 via pose-quiescence, die (0.00,-0.00,2.49))
dartnative: dart3d: wloose settle: 4697ms (roll 3 via pose-quiescence, die (0.00,-0.00,2.49))
dartnative: dart3d: wloose settled event path: absent
dartnative: dart3d: w15 phase — lazy prefab subtree streaming
dartnative: dart3d: w15 lane complete — 5 loads, 3 unloads (3 cycles on streamA; expected final state: both grids live)
dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
dartnative: dart3d: w25 phase — LUT + effects matrix lanes
dartnative: dart3d: w25 lane complete — dice regression FAIL: die 5X8XQNG00004Y rolled but no settle event within 10 s
dartnative: dart3d: w18 phase — particle emitters
dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## ft-ios-dice (dn run output)

fatal/crash lines: 0

```
dartnative: dart3d: rolled d4:3 d6:1 d8:1 d10t:0 d10u:0 d12:1 d20:1 d%:100  ·  total 107
```

## ft-ios-dash (dn run output)

fatal/crash lines: 0

```
dartnative: dart3d: showcase — dash: 41 nodes · 2 geo · 2 mat · 2 tex · 1 skins · 9 anims
```

## ft-ios-fcar (dn run output)

fatal/crash lines: 0

```
dartnative: dart3d: showcase — fcar: 22 nodes · 40 geo · 12 mat
```

## ft-ios-glb (dn run output)

fatal/crash lines: 0

```
dartnative: dart3d: showcase — glb: 6 nodes · 2 geo · 2 mat · 1 tex
```

## ft-ios-materials (dn run output)

fatal/crash lines: 0

```
dartnative: dart3d: showcase — materials: 11 nodes · 8 geo · 8 mat · 3 tex
```

