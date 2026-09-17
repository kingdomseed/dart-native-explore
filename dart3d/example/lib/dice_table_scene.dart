/// The dice-table document builder — pure Dart (no `dartnative`
/// imports) so the compose path is reachable under `dart test`. The
/// screen lives in `dice_table.dart`, which passes `loadAssetBytes`
/// and `dnLog` in through the parameters. Pulls the pure-Dart dart3d
/// libraries directly — the barrel needs DartNative's patched SDK.
// ignore_for_file: implementation_imports
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/physics.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

/// One rollable face of a die: the outward [normal] in the mesh's local
/// (Y-up) space and the [value] that face reports.
final class DieFace {
  const DieFace(this.normal, this.value);

  final Vector3 normal;
  final int value;
}

/// A die's face map plus how it reports: `up` reads the +Y face's
/// value; `down` reads the −Y face's `landing_value` (already folded
/// into [faces] by the extractor, so only the axis differs).
final class DieFaceMap {
  const DieFaceMap({required this.resultSide, required this.faces});

  final String resultSide;
  final List<DieFace> faces;

  /// The value showing after a settle: rotate each face normal into
  /// world space and take the one most aligned with the read axis.
  int read(Quaternion worldRotation) {
    final up = resultSide == 'down' ? -1.0 : 1.0;
    var best = faces.first;
    var bestDot = -2.0;
    for (final f in faces) {
      final d = worldRotation.rotated(f.normal).y * up;
      if (d > bestDot) {
        bestDot = d;
        best = f;
      }
    }
    return best.value;
  }
}

/// One die on the table: its composed node id (the instance id — a
/// single-root prefab merges its root into the instance node), its
/// display label, and its face map.
final class TableDie {
  const TableDie({
    required this.node,
    required this.label,
    required this.faceMap,
    required this.restY,
  });

  final LocalId node;
  final String label;
  final DieFaceMap faceMap;

  /// Node-origin height at which the hull rests on the felt — spawn
  /// and reset use it so dice start in contact instead of dropping.
  final double restY;
}

/// Everything the screen needs from [buildDiceTable]: the composed
/// document, the dice by node id, the camera rig, and the die scale
/// for throw magnitudes.
final class DiceTableScene {
  const DiceTableScene({
    required this.document,
    required this.dice,
    required this.cameraNode,
    required this.cameraTarget,
    required this.cameraDir,
    required this.cameraDist,
    required this.cameraFovY,
    required this.cameraElevation,
    required this.dieRadius,
    required this.trayHalf,
    required this.frameExtent,
  });

  final SceneDocument document;
  final List<TableDie> dice;
  final LocalId cameraNode;

  /// The point the camera looks at, and the normalized direction from
  /// the target to the camera (the zoom boom axis).
  final Vector3 cameraTarget;
  final Vector3 cameraDir;

  /// The authored boom distance, vertical fov, and camera pitch —
  /// the screen's tap unprojection, zoom clamp, and live camera
  /// slider derive from these.
  final double cameraDist;
  final double cameraFovY;
  final double cameraElevation;
  final double dieRadius;

  /// Tray inner half-extents (x, z) — spawn positions and the roll
  /// scatter stay inside the rails.
  final Vector2 trayHalf;

  /// Half-extents the camera fit must cover: tray + rails + the wall
  /// tops' inward projection.
  final Vector2 frameExtent;
}

/// The bundled dice set — label → `.fsceneb` asset key, in table order.
const _diceAssets = {
  'd4': 'assets/dice/scene.d4.dbe53cde.fsceneb',
  'd6': 'assets/dice/scene.d6.dbe505b8.fsceneb',
  'd8': 'assets/dice/scene.d8.dbe51f72.fsceneb',
  'd10t': 'assets/dice/scene.d10t.862039c2.fsceneb',
  'd10u': 'assets/dice/scene.d10u.86203b0d.fsceneb',
  'd12': 'assets/dice/scene.d12.a5cbecd0.fsceneb',
  'd20': 'assets/dice/scene.d20.a5fdb0b1.fsceneb',
};

/// The variant name the selection highlight selects on each die's
/// `materialsVariants` component.
const kSelectedVariant = 'sel';

/// Spawn slots — two staggered columns along the tray's long axis,
/// shared by the table's initial placement and the screen's reset.
/// (x, z) in world units; slots are ~38+ apart so no hulls overlap.
const dieSpawnSlots = <String, (double, double)>{
  'd4': (-19, -57),
  'd8': (-19, -19),
  'd12': (-19, 19),
  'd20': (-19, 57),
  'd6': (19, -38),
  'd10u': (19, 0),
  'd10t': (19, 38),
};

/// A 256² RGBA wood texture, synthesized at build time — no asset
/// file, so the document carries it as an `rgba8` payload that both
/// backends upload verbatim.
///
/// The grain is elongated turbulence-driven banding (walnut tones);
/// the vignette is *baked*: Filament measures point/spot intensity in
/// candela while SceneKit uses a unitless multiplier, so a real lamp
/// would fall off differently per platform. Darkening the texture
/// toward the edges gives the pool-table lamp look identically
/// everywhere — the wood is still lit, so dice shadows and speculars
/// land on it normally.
Uint8List _woodTexture({double halfX = 146, double halfZ = 220}) {
  const n = 256;
  final px = Uint8List(n * n * 4);
  // The texture maps the tabletop's whole face — scale the vignette
  // by the world radius so it reads circular, not elliptical.
  final worldHalfX = halfX, worldHalfZ = halfZ;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final nx = x / (n / 2) - 1, ny = y / (n / 2) - 1;
      // Grain: rings stretched along v → long wavy lines running
      // down the table, like boards.
      final gx = nx * 3.0, gy = ny * 0.55;
      final d = sqrt(gx * gx + gy * gy);
      final turb = 0.55 * sin(gx * 4.2 + gy * 9.1) +
          0.3 * sin(gx * 11.7 - gy * 3.3) +
          0.18 * sin(gx * 23.1 + gy * 6.7);
      final band = d * 5.5 + turb - (d * 5.5 + turb).floorToDouble();
      // Sharp dark pore lines where the band wraps.
      final line = (band - 0.5).abs() * 2;
      // Broad tonal bands across the grain.
      final tone = 0.5 + 0.5 * sin(d * 2.2 + turb * 0.9);
      // Fine per-pixel hash noise — keeps the wood from airbrushing.
      final h = (x * 1973 + y * 9277) ^ (x * y * 2699);
      final noise = ((h & 0xffff) / 0xffff - 0.5) * 0.14;
      var t = (line * 0.55 + tone * 0.45 + noise).clamp(0.0, 1.0);
      // Walnut: light ↔ dark.
      var r = 0.32 + 0.30 * t, g = 0.20 + 0.185 * t, b = 0.10 + 0.10 * t;
      // Baked vignette — bright center, ~55% at the play-bounds edge.
      final rw = sqrt(
        (nx * worldHalfX) * (nx * worldHalfX) +
            (ny * worldHalfZ) * (ny * worldHalfZ),
      );
      final edge = ((rw - 110) / 170).clamp(0.0, 1.0);
      final vig = 1.0 - 0.45 * edge * edge * (3 - 2 * edge);
      r *= vig;
      g *= vig;
      b *= vig;
      final i = (y * n + x) * 4;
      px[i] = (r * 255).round().clamp(0, 255);
      px[i + 1] = (g * 255).round().clamp(0, 255);
      px[i + 2] = (b * 255).round().clamp(0, 255);
      px[i + 3] = 255;
    }
  }
  return px;
}

/// Parses `assets/dice/dice_faces.json` (extracted host-side from each
/// glb's `extras.face_map_json`; normals already rotated into the Y-up
/// mesh space the `.fsceneb` ships). [bytesFor] overrides the bundle
/// lookup for tests.
Map<String, DieFaceMap> loadDiceFaceMaps({
  Uint8List? Function(String key)? bytesFor,
}) {
  final bytes = bytesFor?.call('assets/dice/dice_faces.json');
  if (bytes == null) return {};
  final Object? decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic>) return {};
  final out = <String, DieFaceMap>{};
  decoded.forEach((die, raw) {
    if (raw is! Map<String, dynamic>) return;
    final faces = <DieFace>[];
    for (final f in (raw['faces'] as List? ?? const [])) {
      if (f is! Map<String, dynamic>) continue;
      final n = f['n'] as List?;
      final v = f['v'];
      if (n == null || n.length != 3 || v is! num) continue;
      faces.add(
        DieFace(
          Vector3(
            (n[0] as num).toDouble(),
            (n[1] as num).toDouble(),
            (n[2] as num).toDouble(),
          ),
          v.toInt(),
        ),
      );
    }
    out[die] = DieFaceMap(
      resultSide: (raw['resultSide'] as String?) ?? 'up',
      faces: faces,
    );
  });
  return out;
}

/// Tunable table physics + geometry. Structural fields (tray, rails,
/// gravity, materials, damping) bake into the document — changing them
/// needs a rebuild; [throwScale]/[spinScale] are read at roll time and
/// apply live.
///
/// The defaults mirror the MythicGME2e dice overlay's tuned Rapier
/// profile (its `DicePhysicsProfile.baseline`), scaled to this table's
/// ~Ø33-unit dice: gravity/die-size ≈ 26 s⁻², dice nearly frictionless
/// and lively against each other, walls near-elastic so a die that
/// reaches a rail kicks back in instead of dying against it.
final class DiceTableSpec {
  const DiceTableSpec({
    this.trayHalfX = 66.0,
    this.trayHalfZ = 140.0,
    this.railHeight = 320.0,
    this.gravity = 900.0,
    this.dieRestitution = 0.68,
    this.dieFriction = 0.25,
    this.feltFriction = 0.9,
    this.feltRestitution = 0.28,
    this.wallFriction = 0.05,
    this.wallRestitution = 0.92,
    this.linearDamping = 0.1,
    this.angularDamping = 0.3,
    this.throwScale = 1.0,
    this.spinScale = 1.0,
  });

  /// Play-bounds half-extents — the walls are invisible, so these are
  /// the screen edges the dice bounce off.
  final double trayHalfX, trayHalfZ;

  /// Wall height — the invisible bounds are a glass box: far taller
  /// than any bounce or pile-up can loft a die, sunk below the felt
  /// so there is no seam to wedge through. Nothing escapes.
  final double railHeight;

  /// Gravity magnitude (positive; the world's gravity vector is −Y).
  /// True mm-scale is 9800; the reference feel is g/die-size ≈ 26,
  /// which lands at ~900 for ~Ø33 dice — dice visibly travel, bounce,
  /// and roll out rather than popping up and dropping dead.
  final double gravity;

  /// Dice are nearly frictionless (they slide and glance) but lively
  /// against each other — the clatter comes from die-vs-die bounces.
  final double dieRestitution, dieFriction;

  /// The felt slab — grippy and comparatively dead: it kills the
  /// vertical quickly while letting dice slide and roll out.
  final double feltFriction, feltRestitution;

  /// The rails — nearly elastic (a real tray's wood kicks dice back
  /// into the felt) with almost no grip.
  final double wallFriction, wallRestitution;

  /// Velocity bleed per second — the roll-out tail. Low values keep
  /// dice moving through the scatter; contact friction does the stop.
  final double linearDamping, angularDamping;

  /// Master multipliers on the throw's launch speed and tumble rate —
  /// applied at roll time, no rebuild needed.
  final double throwScale, spinScale;

  /// Fields that change the baked document (everything but the live
  /// multipliers) — the screen rebuilds only when one moves.
  bool structurallySame(DiceTableSpec o) =>
      trayHalfX == o.trayHalfX &&
      trayHalfZ == o.trayHalfZ &&
      railHeight == o.railHeight &&
      gravity == o.gravity &&
      dieRestitution == o.dieRestitution &&
      dieFriction == o.dieFriction &&
      feltFriction == o.feltFriction &&
      feltRestitution == o.feltRestitution &&
      wallFriction == o.wallFriction &&
      wallRestitution == o.wallRestitution &&
      linearDamping == o.linearDamping &&
      angularDamping == o.angularDamping;

  DiceTableSpec copyWith({
    double? trayHalfX,
    double? trayHalfZ,
    double? railHeight,
    double? gravity,
    double? dieRestitution,
    double? dieFriction,
    double? feltFriction,
    double? feltRestitution,
    double? wallFriction,
    double? wallRestitution,
    double? linearDamping,
    double? angularDamping,
    double? throwScale,
    double? spinScale,
  }) => DiceTableSpec(
    trayHalfX: trayHalfX ?? this.trayHalfX,
    trayHalfZ: trayHalfZ ?? this.trayHalfZ,
    railHeight: railHeight ?? this.railHeight,
    gravity: gravity ?? this.gravity,
    dieRestitution: dieRestitution ?? this.dieRestitution,
    dieFriction: dieFriction ?? this.dieFriction,
    feltFriction: feltFriction ?? this.feltFriction,
    feltRestitution: feltRestitution ?? this.feltRestitution,
    wallFriction: wallFriction ?? this.wallFriction,
    wallRestitution: wallRestitution ?? this.wallRestitution,
    linearDamping: linearDamping ?? this.linearDamping,
    angularDamping: angularDamping ?? this.angularDamping,
    throwScale: throwScale ?? this.throwScale,
    spinScale: spinScale ?? this.spinScale,
  );
}

/// Builds the composed dice-table document: tray, rails, seven prefab
/// dice, camera, lights, environment. [bytesFor] overrides the bundle
/// lookup for tests; [spec] tunes the physics table.
DiceTableScene? buildDiceTable({
  Uint8List? Function(String key)? bytesFor,
  void Function(String message)? log,
  DiceTableSpec spec = const DiceTableSpec(),
}) {
  final bytesOf = bytesFor ?? (_) => null;
  final faceMaps = loadDiceFaceMaps(bytesFor: bytesFor);
  final host = SceneDocument();

  // The imported dice are authored ~Ø23–33 units (mm-scale). True
  // mm-scale gravity (-9800) falls so fast at this size that a thrown
  // die reads as lead — ~⅓ scale (earth ≈ 370×) keeps the toss on
  // screen: ~0.5s aloft, a few decaying bounces, then the roll-out.
  final gravity = -spec.gravity;
  final trayHalfX = spec.trayHalfX, trayHalfZ = spec.trayHalfZ;
  final railHeight = spec.railHeight;
  // The felt is a deep slab, not a skin — a die at sweep speed can
  // travel ~6 units per substep, and a 2.5-thick floor is tunnelable
  // even with CCD on the dice. 14 units is unpassable.
  const slabThick = 14.0;

  MaterialResource mat(
    SceneDocument doc, {
    required ColorValue color,
    double roughness = 0.8,
    double metallic = 0.0,
  }) => doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': color,
        'roughness': DoubleValue(roughness),
        'metallic': DoubleValue(metallic),
      },
    ),
  );

  void fixedBox(
    String name,
    Vector3 center,
    Vector3 extents,
    MaterialResource material, {
    double friction = 0.6,
    double restitution = 0.25,
  }) {
    final geo = host.addResource(
      GeometryResource(
        host.newId(),
        procedural: CuboidGeometrySpec(extents: extents),
      ),
    );
    host.createNode(
      name: name,
      transform: TrsTransform(translation: center),
      components: [
        ComponentSpec(
          'mesh',
          properties: {
            'geometry': ResourceRefValue(geo.id),
            'material': ResourceRefValue(material.id),
          },
        ),
        colliderComponent(
          shape: 'box',
          extents: extents,
          friction: friction,
          restitution: restitution,
        ),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );
  }

  // Wood tabletop — the whole screen is the tray; walls are
  // invisible. The synthesized texture carries the grain and the
  // lamp vignette; roughness ~0.55 gives a satin sheen under the key.
  final woodPixels = _woodTexture(
    halfX: trayHalfX + 80,
    halfZ: trayHalfZ + 80,
  );
  final woodPayload = host.addPayload(
    PayloadSpec(
      host.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 256,
      height: 256,
      length: woodPixels.length,
      bytes: woodPixels,
    ),
  );
  final woodTex = host.addResource(
    TextureResource(host.newId(), payload: woodPayload.id),
  );
  final wood = host.addResource(
    MaterialResource(
      host.newId(),
      type: 'physicallyBased',
      properties: {
        'baseColor': ColorValue(1, 1, 1, 1),
        'baseColorTexture': ResourceRefValue(woodTex.id),
        'roughness': DoubleValue(0.55),
        'metallic': DoubleValue(0.0),
      },
    ),
  );

  /// Walls are invisible collision planes at the play bounds — the
  /// screen edges are the tray walls. Near-elastic and near-
  /// frictionless, so a die that reaches an edge rebounds into view.
  void wallBox(String name, Vector3 center, Vector3 extents) {
    host.createNode(
      name: name,
      transform: TrsTransform(translation: center),
      components: [
        colliderComponent(
          shape: 'box',
          extents: extents,
          friction: spec.wallFriction,
          restitution: spec.wallRestitution,
        ),
        rigidBodyComponent(type: 'fixed'),
      ],
      root: true,
    );
  }
  // The tabletop covers the bounds plus a generous margin — the
  // camera's visible area is always wood, so the screen itself is
  // the tray.
  fixedBox(
    'tray.top',
    Vector3(0, -slabThick / 2, 0),
    Vector3(
      trayHalfX * 2 + 160,
      slabThick,
      trayHalfZ * 2 + 160,
    ),
    wood,
    friction: spec.feltFriction,
    restitution: spec.feltRestitution,
  );
  // The table under the tray — backstop below the felt slab.
  fixedBox(
    'table.surface',
    Vector3(0, -slabThick - 4.0, 0),
    Vector3(560, 4.0, 420),
    mat(
      host,
      color: ColorValue(0.16, 0.105, 0.07, 1),
      roughness: 0.7,
    ),
    friction: 0.7,
    restitution: 0.2,
  );
  // Glass-box walls: 24 thick (a ~900 u/s die moves ~7.5 per 120Hz
  // substep — untunnelable), and sunk below the felt surface so the
  // wall/felt seam has no gap a sliding die can wedge into.
  const wallThick = 24.0;
  const wallSink = 10.0;
  final wallSpan = railHeight + wallSink;
  final wallCenterY = (railHeight - wallSink) / 2;
  for (final side in [-1.0, 1.0]) {
    wallBox(
      'tray.wall.z$side',
      Vector3(0, wallCenterY, side * (trayHalfZ + wallThick / 2)),
      Vector3(trayHalfX * 2 + wallThick * 4, wallSpan, wallThick),
    );
    wallBox(
      'tray.wall.x$side',
      Vector3(side * (trayHalfX + wallThick / 2), wallCenterY, 0),
      Vector3(wallThick, wallSpan, trayHalfZ * 2 + wallThick * 4),
    );
  }
  // One physicsWorld component on a root — mm-scale gravity (the dice
  // are authored ~mm). 120Hz substeps keep mm-scale impacts (dice hit
  // the felt at ~700 u/s — ~6 units per 60Hz step) from tunneling.
  host.createNode(
    name: 'tray.world',
    components: [
      physicsWorldComponent(
        gravity: Vector3(0, gravity, 0),
        fixedTimestep: 1.0 / 120.0,
        maxSubsteps: 4,
      ),
    ],
    root: true,
  );

  // Pre-decode each die once: `resolve` reuses the cached (and
  // variant-injected) document, and the bounds give each die's rest
  // height — spawn puts the hull on the felt so boot doesn't drop the
  // dice into an unrequested roll.
  final prefabDocs = <String, SceneDocument>{};
  final restHeights = <String, double>{};
  for (final e in _diceAssets.entries) {
    final bytes = bytesOf(e.value);
    if (bytes == null) continue;
    final doc = readFsceneb(bytes);
    prefabDocs[e.value] = doc;
    var minY = double.infinity;
    for (final res in doc.resources.values) {
      if (res is GeometryResource && res.bounds != null) {
        minY = min(minY, res.bounds!.min.y);
      }
    }
    if (minY.isFinite) restHeights[e.key] = -minY + 0.4;
  }

  // Dice in two staggered columns along the tray's long (portrait)
  // axis — ~38 units apart, inside the ±66 bounds with margin.
  // `dieSpawnSlots` is shared with the screen's reset.
  final dice = <TableDie>[];
  var dieRadius = 12.0;
  void place(String label, double x, double z) {
    final restY = restHeights[label] ?? 12.0;
    final node = host.createNode(
      name: 'die.$label',
      transform: TrsTransform(translation: Vector3(x, restY, z)),
      root: true,
    );
    node.instance = PrefabInstanceSpec(
      source: AssetRef(_diceAssets[label]!),
      addedComponents: [
        colliderComponent(
          shape: 'convexHull',
          friction: spec.dieFriction,
          restitution: spec.dieRestitution,
        ),
        rigidBodyComponent(
          type: 'dynamic',
          mass: 1.0,
          linearDamping: spec.linearDamping,
          // Rolling-resistance proxy — Coulomb friction barely damps
          // pure rolling, and felt should.
          angularDamping: spec.angularDamping,
          ccdEnabled: true,
        ),
      ],
    );
    dice.add(
      TableDie(
        node: node.id,
        label: label,
        faceMap: faceMaps[label] ?? const DieFaceMap(resultSide: 'up', faces: []),
        restY: restY,
      ),
    );
  }

  for (final e in _diceAssets.entries) {
    final slot = dieSpawnSlots[e.key]!;
    place(e.key, slot.$1, slot.$2);
  }

  // The prefab resolver: decode each die's .fsceneb, inject the
  // `sel` materialsVariant (a warm emissive clone of each primitive's
  // material — the resolver can see the prefab's own ids, which the
  // host doc cannot), and hand it to composeScene.
  SceneDocument resolve(AssetRef ref) {
    final prefab = prefabDocs[ref.key] ?? () {
      final bytes = bytesOf(ref.key);
      if (bytes == null) {
        throw StateError('missing bundled asset ${ref.key}');
      }
      return readFsceneb(bytes);
    }();
    for (final node in prefab.nodes.values) {
      ComponentSpec? mesh;
      for (final c in node.components) {
        if (c.type == 'mesh') mesh = c;
      }
      if (mesh == null) continue;
      final prims = (mesh.properties['primitives'] as ListValue?)?.values;
      final singleMat = mesh.properties['material'] as ResourceRefValue?;
      final bindings = <PropertyValue>[];
      void bindPrim(int slot, PropertyValue? matRef) {
        if (matRef is! ResourceRefValue) return;
        final orig = prefab.resources[matRef.id];
        final selProps = <String, PropertyValue>{
          if (orig is MaterialResource) ...orig.properties,
          'emissive': ColorValue(1.0, 0.55, 0.15, 1.0),
          'emissiveStrength': DoubleValue(0.9),
        };
        final selMat = prefab.addResource(
          MaterialResource(
            prefab.newId(),
            type: orig is MaterialResource ? orig.type : 'physicallyBased',
            properties: selProps,
          ),
        );
        bindings.add(
          MapValue({
            'node': NodeRefValue(node.id),
            'primitive': IntValue(slot),
            'default': matRef,
            'materials': MapValue({'0': ResourceRefValue(selMat.id)}),
          }),
        );
      }

      if (prims != null) {
        for (var i = 0; i < prims.length; i++) {
          final entry = prims[i];
          bindPrim(i, entry is MapValue ? entry.values['material'] : null);
        }
      } else {
        bindPrim(0, singleMat);
      }
      node.components.add(
        ComponentSpec(
          'materialsVariants',
          properties: {
            'variants': ListValue([StringValue(kSelectedVariant)]),
            'bindings': ListValue(bindings),
          },
        ),
      );
      // Track the die's size for throw scaling — bounds diagonal/2
      // is the bounding-sphere radius (~16.7 for these dice).
      final primList = prims ?? const <PropertyValue>[];
      for (final entry in primList) {
        if (entry is! MapValue) continue;
        final geoRef = entry.values['geometry'];
        if (geoRef is! ResourceRefValue) continue;
        final geo = prefab.resources[geoRef.id];
        if (geo is! GeometryResource) continue;
        final b = geo.bounds;
        if (b == null) continue;
        dieRadius = max(dieRadius, (b.max - b.min).length * 0.5);
      }
    }
    return prefab;
  }

  final composed = composeScene(host, resolve: resolve);

  // Camera: above the tray on the −z side (the harness's convention).
  // Straight down for the demo readout — the screen can re-pitch it
  // live via a camera transform write. With forward +Z, a camera at
  // target + dist·(0, sin·e, −cos·e) looks at the target under a pure
  // +X pitch of `e`.
  const elevation = pi / 2; // directly down
  const cameraDist = 310.0;
  const cameraFovY = 0.95;
  final cameraDir = Vector3(0, sin(elevation), -cos(elevation));
  final cameraTarget = Vector3(0, 2, 0);
  final camera = composed.createNode(
    name: 'table.camera',
    transform: TrsTransform(
      translation: cameraTarget + cameraDir * cameraDist,
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), elevation),
    ),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': StringValue('perspective'),
          'fovRadiansY': DoubleValue(cameraFovY),
          'near': DoubleValue(5.0),
          'far': DoubleValue(1200.0),
        },
      ),
    ],
    root: true,
  );

  // Warm key steeply overhead — shadows sit mostly under the dice
  // like the lamp-over-table reference — plus a cool fill; studio env
  // dimmed so the key's shadows stay visible. Lights emit along −Z —
  // same Ry(yaw)·Rx(pitch) decomposition as the showcase camera,
  // aiming +Z at the negated light direction.
  Quaternion aimLight(Vector3 dir) {
    final fwd = -dir;
    final pitch = -asin(fwd.y.clamp(-1.0, 1.0));
    final yaw = atan2(fwd.x, fwd.z);
    return Quaternion.axisAngle(Vector3(0, 1, 0), yaw) *
        Quaternion.axisAngle(Vector3(1, 0, 0), pitch);
  }

  composed.createNode(
    name: 'table.key',
    transform: TrsTransform(
      rotation: aimLight(Vector3(-0.28, -1.0, -0.22)..normalize()),
    ),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': ColorValue(1.0, 0.93, 0.82, 1),
          'intensity': DoubleValue(2400),
          'castsShadow': BoolValue(true),
          'shadowRadius': DoubleValue(2.5),
          'shadowDepthBias': DoubleValue(0.01),
        },
      ),
    ],
    root: true,
  );
  composed.createNode(
    name: 'table.fill',
    transform: TrsTransform(
      translation: Vector3(-trayHalfX, 90, trayHalfZ * 1.6),
    ),
    components: [
      ComponentSpec(
        'pointLight',
        properties: {
          'color': ColorValue(0.55, 0.68, 1.0, 1),
          'intensity': DoubleValue(1500),
          'range': DoubleValue(600),
        },
      ),
    ],
    root: true,
  );
  composed.stage.environmentRef = composed
      .addResource(
        EnvironmentResource(
          composed.newId(),
          environment: const StudioEnvironment(),
          environmentIntensity: 0.5,
          exposure: 1.0,
          toneMapping: 'pbrNeutral',
          skybox: SkyboxSpec(EnvironmentSkySpec()),
        ),
      )
      .id;

  log?.call(
    'dart3d: dice table — ${dice.length} dice, '
    '${composed.nodes.length} nodes, ${composed.payloads.length} payloads',
  );
  return DiceTableScene(
    document: composed,
    dice: dice,
    cameraNode: camera.id,
    cameraTarget: cameraTarget,
    cameraDir: cameraDir,
    cameraDist: cameraDist,
    cameraFovY: cameraFovY,
    cameraElevation: elevation,
    dieRadius: dieRadius,
    // Roll spawns stay a die-width inside the rails.
    trayHalf: Vector2(
      trayHalfX - dieRadius * 0.9,
      trayHalfZ - dieRadius * 0.9,
    ),
    // Camera-fit extent: the play bounds plus a hair — a die pressed
    // against a wall stays fully in frame, so the screen edges read
    // as the tray walls.
    frameExtent: Vector2(trayHalfX + 6, trayHalfZ + 6),
  );
}

