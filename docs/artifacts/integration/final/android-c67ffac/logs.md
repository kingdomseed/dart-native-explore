# Android smoke — origin/stabilize/android @ c67ffac (A142, release)

dn analyze clean; dn test dart3d 273/273, example 126/126. Warm relaunch skipped (issue #18).
Dice screenshots were taken mid-roll (status 'rolling…'); the settle is proven by the second 'rolled' line ~9 s later.

## vk harness

native fatal (Fatal signal|CS_FATAL|unrecoverable|Page fault): 0 · Java (FATAL EXCEPTION|E AndroidRuntime): 0 · init-failed: 0 · journal 2048 warn: 0 · E dart3d: 0

```
09-28 23:35:13.635 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:35:13.724 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:35:13.731 dart3d  : re-realize replay: 55 plain op(s), 0 subtree(s)
09-28 23:35:17.542 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 23:35:25.541 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 23:35:25.543 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 23:35:37.541 dartnative: dart3d: w13 phase — environment effects toggles
09-28 23:35:53.541 dartnative: dart3d: w14 phase — render textures + views
09-28 23:35:53.559 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:35:55.561 dart3d  : views applied: 2 entries (0 screen, 2 rts)
09-28 23:35:57.558 dart3d  : views applied: 3 entries (0 screen, 2 rts)
09-28 23:35:59.557 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:36:21.541 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 23:36:51.546 dartnative: dart3d: wloose settled event path: absent
09-28 23:36:55.541 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 23:37:09.544 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 23:37:11.555 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:37:15.561 dart3d  : views applied: 2 entries (1 screen, 1 rts)
09-28 23:37:18.554 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:37:21.573 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:37:23.543 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 23:37:49.541 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 23:38:13.575 dartnative: dart3d: w25 lane complete — dice regression FAIL: die BN9KPH800004Y rolled but no settle event within 10 s
09-28 23:38:15.540 dartnative: dart3d: w18 phase — particle emitters
09-28 23:38:15.548 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 23:38:31.551 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## vk surfaces

native fatal (Fatal signal|CS_FATAL|unrecoverable|Page fault): 0 · Java (FATAL EXCEPTION|E AndroidRuntime): 0 · init-failed: 0 · journal 2048 warn: 0 · E dart3d: 0

```
09-28 23:35:25.541 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 23:35:25.543 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 23:35:37.541 dartnative: dart3d: w13 phase — environment effects toggles
09-28 23:35:53.541 dartnative: dart3d: w14 phase — render textures + views
09-28 23:35:53.559 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:35:55.561 dart3d  : views applied: 2 entries (0 screen, 2 rts)
09-28 23:35:57.558 dart3d  : views applied: 3 entries (0 screen, 2 rts)
09-28 23:35:59.557 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:36:21.541 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 23:36:51.546 dartnative: dart3d: wloose settled event path: absent
09-28 23:36:55.541 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 23:37:09.544 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 23:37:11.555 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:37:15.561 dart3d  : views applied: 2 entries (1 screen, 1 rts)
09-28 23:37:18.554 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:37:21.573 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:37:23.543 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 23:37:49.541 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 23:38:13.575 dartnative: dart3d: w25 lane complete — dice regression FAIL: die BN9KPH800004Y rolled but no settle event within 10 s
09-28 23:38:15.540 dartnative: dart3d: w18 phase — particle emitters
09-28 23:38:15.548 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 23:38:31.551 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
09-28 23:38:33.620 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:38:33.974 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:38:35.771 dartnative: dart3d: rolled d4:4 d6:1 d8:1 d10t:30 d10u:3 d12:2 d20:1 d%:33  ·  total 42
09-28 23:38:44.519 dartnative: dart3d: rolled d4:4 d6:5 d8:2 d10t:30 d10u:0 d12:10 d20:1 d%:30  ·  total 52
09-28 23:38:45.635 dartnative: dart3d: showcase — dash: 41 nodes · 2 geo · 2 mat · 2 tex · 1 skins · 9 anims
09-28 23:38:45.837 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:38:46.822 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:38:57.568 dart3d  : views applied: 0 entries (0 screen, 0 rts)
```

## gl harness

native fatal (Fatal signal|CS_FATAL|unrecoverable|Page fault): 0 · Java (FATAL EXCEPTION|E AndroidRuntime): 0 · init-failed: 0 · journal 2048 warn: 0 · E dart3d: 0

```
09-28 23:40:28.620 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:40:28.704 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:40:28.713 dart3d  : re-realize replay: 55 plain op(s), 0 subtree(s)
09-28 23:40:30.987 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 23:40:38.988 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 23:40:38.990 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 23:40:50.989 dartnative: dart3d: w13 phase — environment effects toggles
09-28 23:41:06.988 dartnative: dart3d: w14 phase — render textures + views
09-28 23:41:07.007 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:41:09.007 dart3d  : views applied: 2 entries (0 screen, 2 rts)
09-28 23:41:11.004 dart3d  : views applied: 3 entries (0 screen, 2 rts)
09-28 23:41:13.005 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:41:34.989 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 23:42:04.996 dartnative: dart3d: wloose settled event path: absent
09-28 23:42:08.989 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 23:42:22.988 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 23:42:25.010 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:42:29.004 dart3d  : views applied: 2 entries (1 screen, 1 rts)
09-28 23:42:32.001 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:42:35.016 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:42:36.992 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 23:43:02.988 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 23:43:27.002 dartnative: dart3d: w25 lane complete — dice regression FAIL: die NSY9V4G00004Y rolled but no settle event within 10 s
09-28 23:43:28.988 dartnative: dart3d: w18 phase — particle emitters
09-28 23:43:29.006 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 23:43:45.012 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
```

## gl surfaces

native fatal (Fatal signal|CS_FATAL|unrecoverable|Page fault): 0 · Java (FATAL EXCEPTION|E AndroidRuntime): 0 · init-failed: 0 · journal 2048 warn: 0 · E dart3d: 0

```
09-28 23:40:28.620 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:40:28.704 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:40:28.713 dart3d  : re-realize replay: 55 plain op(s), 0 subtree(s)
09-28 23:40:30.987 dartnative: dart3d: w11 phase — flag skin, morph blob, wave+pulse
09-28 23:40:38.988 dartnative: dart3d: w12 phase — joint components + variants + rectAreaLight
09-28 23:40:38.990 dartnative: dart3d: w12 phase — joint components, variants, rectAreaLight, enabled:false
09-28 23:40:50.989 dartnative: dart3d: w13 phase — environment effects toggles
09-28 23:41:06.988 dartnative: dart3d: w14 phase — render textures + views
09-28 23:41:07.007 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:41:09.007 dart3d  : views applied: 2 entries (0 screen, 2 rts)
09-28 23:41:11.004 dart3d  : views applied: 3 entries (0 screen, 2 rts)
09-28 23:41:13.005 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:41:34.989 dartnative: dart3d: wloose phase — ccd + bowl + margin + settle latency
09-28 23:42:04.996 dartnative: dart3d: wloose settled event path: absent
09-28 23:42:08.989 dartnative: dart3d: w15 phase — lazy prefab subtree streaming
09-28 23:42:22.988 dartnative: dart3d: w24 phase — split-screen, viewport, cascades, contact shadows, catcher, layerMask
09-28 23:42:25.010 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:42:29.004 dart3d  : views applied: 2 entries (1 screen, 1 rts)
09-28 23:42:32.001 dart3d  : views applied: 3 entries (2 screen, 1 rts)
09-28 23:42:35.016 dart3d  : views applied: 1 entries (0 screen, 1 rts)
09-28 23:42:36.992 dartnative: dart3d: w16 phase — trail ribbon + screen-size lod drive
09-28 23:43:02.988 dartnative: dart3d: w25 phase — LUT + effects matrix lanes
09-28 23:43:27.002 dartnative: dart3d: w25 lane complete — dice regression FAIL: die NSY9V4G00004Y rolled but no settle event within 10 s
09-28 23:43:28.988 dartnative: dart3d: w18 phase — particle emitters
09-28 23:43:29.006 dartnative: dart3d: w18 phase — flipbook fountain, additive streaks, mesh tumble pool, enabled:false gate
09-28 23:43:45.012 dartnative: dart3d: w18 lane complete — expected: fountain + streaks + mesh pool live, gated ran +6 s…+14 s then removed
09-28 23:43:46.020 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:43:46.368 dart3d  : views applied: 0 entries (0 screen, 0 rts)
09-28 23:43:48.212 dartnative: dart3d: rolled d4:4 d6:1 d8:1 d10t:30 d10u:3 d12:2 d20:1 d%:33  ·  total 42
09-28 23:43:57.210 dartnative: dart3d: rolled d4:3 d6:6 d8:8 d10t:60 d10u:3 d12:7 d20:8 d%:63  ·  total 95
```

