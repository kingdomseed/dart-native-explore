# s0g-ios-anim-orbit — #27 evidence (iOS sim)

Device: iPhone 17 Pro simulator `9151BBE4-8453-4F3F-8FD6-17535A25A18E`
(iOS 26.5 runtime, Xcode 27). Debug build via
`dn run -d 9151BBE4-… --dart-define=DART3D_SCENE=showcase`. Base: main
after #26 (DN logo) and #28.

## Root cause

There are two independent causes. Neither involves the W24 split-view/POV
change: the camera writes hit the right node (`pov=true` below).

### 1. Clips: the deferred re-realize drops clip playback

Showcase documents ship with deferred payloads: textures, geometry, and
animation channel chunks. When the last chunk lands, `drainPendingWork`
re-realizes the manifest (`FsceneRealizer.realize(preserveStage: true)`),
and `install()` resets `animClips`. The Showcase's autoplay `anim` op
drains in the same batch, just before that re-realize, so the clip is
created (`playing=true`) and then wiped before its first sampled frame.
The chip's later `anim` ops take the same path while chunks are still
landing. Android has carried clip state across this re-realize since
#16, and iOS never got the same change.

Instrumented run (temporary `DBG27` logs, removed before commit), dash
before the fix:

```
09:34:57.379 DBG27 install: dropping 0 clips                       <- initial realize
09:35:02.043 DBG27 anim key=26147370056024743 playing=true channels=105 clips=1
09:35:02.043 DBG27 setTransforms node=123773540062199811 hit=true pov=true povName=showcase.camera
09:35:02.043 DBG27 deferred re-realize
09:35:03.696 DBG27 install: dropping 1 clips                       <- Idle wiped
```

A screenshot diff 0.7 s apart showed changes only in the status bar
(`(0, 0, 792, 153)`): dash was frozen.

### 2. Orbit: the iOS scale recognizer takes one-finger drags

The Showcase registers both `onPanUpdate` (orbit) and `onScaleUpdate`
(pinch). On DartNative iOS, a one-finger drag is delivered to the scale
recognizer as `pointerCount == 1` updates, and `onPanUpdate` never fires,
so the orbit handler never ran. The camera wire path is fine: the
`setTransforms` above hits the POV node.

```
dartnative: DBG27 scale 1.0 pc=1      <- one-finger drag arrives as scale
dartnative: DBG27 scale 1.0 pc=1
(no "DBG27 orbit" line: onPanUpdate never called; 0 across the fixed run too)
```

The dice table already pans through `onScaleUpdate` with
`pointerCount == 1`, which is why it wasn't affected.

## Fix

- `dart3d/ios/Classes/SceneViewHost.swift`: `drainPendingWork` snapshots
  `animClips` before the deferred re-realize and restores each clip whose
  animation def survives and that has no newer state. This mirrors
  Android's `Dart3dView` in #16. Bind poses are not carried, because the
  re-realized nodes return at the manifest pose. Logs
  `deferred re-realize: carried N clip state(s)`.
- `dart3d/example/lib/showcase_scene.dart`: the one-finger orbit reads
  focal-point deltas from the scale stream as well as pan deltas. The
  first recognizer to deliver a one-finger delta owns the gesture, so a
  platform that fires both can't double-rotate. The latch resets on
  pan/scale end. A pinch that grows out of a one-finger drag re-bases on
  the current boom.

## After the fix

Native log, same run:

```
09:41:02.524 … anim key=26147370056024075 playing=true channels=2 clips=1   (DN logo Spin)
09:41:03.045 … install: dropping 1 clips
09:41:03.045 … deferred re-realize: carried 1 clip state(s)
09:42:27.542 … anim key=26147370056024743 playing=true channels=105 clips=1 (dash Idle)
09:42:29.342 … deferred re-realize: carried 1 clip state(s)
```

Screenshot diffs 0.7 s apart below the status bar:

- DN logo Spin: `(287, 803, 1206, 1418)`, so the logo moves.
- dash Idle: `(362, 845, 771, 1401)`, so dash moves.
- dash after the chip tap (Idle → Jump 4/9): `(498, 984, 842, 1228)`.

| file | what |
|---|---|
| `logo-spin-t0.png`, `logo-spin-t1.png` | DN logo `Spin` autoplaying, 1 s apart |
| `dash-idle-t0.png`, `dash-idle-t1.png` | dash `Idle` autoplaying; pose A (authored 3/4 camera) |
| `orbit-pose-b-yaw.png` | after a one-finger horizontal drag: camera swung around (beak now faces left) |
| `orbit-pose-c-pitch.png` | after a one-finger vertical drag: camera lifted near top-down |
| `pinch-zoom-in.png` | after a two-finger spread: boom pulled in |
| `dash-clip-next.png` | after a pinch-out plus a chip tap: `Jump · 4/9` playing |
| `harness-w11-t0.png`, `harness-w11-t1.png` | Harness: `anims: 2 playing`, 60 fps |
| `final-build-orbit-left.png` | committed build (debug logs removed, rebased on `ba39a61`), `DART3D_MODEL=dash`: Idle playing (`carried 1 clip state(s)`, diff `(364, 850, 770, 1400)`) and a one-finger drag to the left orbits |

## Harness animation lanes (W11)

The W11 lane animates on iOS with or without this fix. Its documents
don't take the deferred-payload re-realize path. Dart log:

```
dart3d: w11 j1 rot=(0.00,0.00,0.22,0.98) t=1.60 live=(-0.00,-0.00,0.04,1.00)
dart3d: w11 j1 rot=(-0.00,-0.00,-0.08,1.00) t=0.15 live=(-0.00,-0.00,-0.01,1.00)
dart3d: w11 j1 rot=(0.00,0.00,0.19,0.98) t=1.35 live=(-0.00,-0.00,0.03,1.00)
```

The clip time advances and the live joint rotation follows. The status
reads `anims: 2 playing`. This was not a broad regression: only
documents whose `anim` op lands before their last payload chunk were
affected.

## Checks

- `dn analyze`: clean in `dart3d/` and `dart3d/example/`.
- `dn test`: 273/273 pass in `dart3d/` and 126/126 in `dart3d/example/`.
- `swiftc -typecheck -target arm64-apple-ios16.0-simulator` (iPhoneSimulator 27.0 SDK)
  on `dart3d/ios/Classes/*.swift`: clean.

## Follow-ups (not in this PR)

- The deferred re-realize also resets node transforms to the manifest
  pose on both iOS and Android, so a `setTransforms` that drains ahead of
  the last chunk is lost. #26 works around this for the Showcase camera
  by writing the fitted pose into the document before it ships.
- Android needs a re-check of the Showcase orbit. The change is shared
  Dart, and the ownership latch keeps it from double-rotating if Android
  fires both pan and scale.
- Device check (iPhone/iPad): not run. Nothing in either cause is
  simulator-specific.
