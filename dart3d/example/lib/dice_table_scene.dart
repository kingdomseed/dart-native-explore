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

import 'dice_shard_d4.dart';
import 'dice_tray_layout.dart';
import 'light_aim.dart';

/// One rollable face of a die: the outward [normal] in the die's
/// document-space mesh frame (Y-up, left-handed like every `.fscene`
/// document) and the [value] that face reports.
final class DieFace {
  const DieFace(this.normal, this.value);

  final Vector3 normal;
  final int value;
}

/// A die's face map: which face is up for a given world rotation.
final class DieFaceMap {
  const DieFaceMap({required this.faces});

  final List<DieFace> faces;

  /// The face pointing up under [worldRotation] (a settle pose), and how
  /// squarely: the dot of its world normal with +Y (1 = flat).
  ///
  /// The normal is rotated with the rotation *matrix*. vector_math's
  /// `Quaternion.rotated` computes conj(q)·v·q — the inverse rotation —
  /// which is why the old readout disagreed with the visible faces
  /// (docs/triage/integration.md §"Dice readout mismatch").
  (DieFace, double) top(Quaternion worldRotation) {
    final m = worldRotation.asRotationMatrix();
    var best = faces.first;
    var bestDot = -2.0;
    for (final f in faces) {
      final d = (m * f.normal).y;
      if (d > bestDot) {
        bestDot = d;
        best = f;
      }
    }
    return (best, bestDot);
  }

  /// The value showing after a settle.
  int read(Quaternion worldRotation) => top(worldRotation).$1.value;
}

/// One die on the table: its composed node id (the instance id — a
/// single-root prefab merges its root into the instance node), its
/// display label, its face map, and its size.
final class TableDie {
  const TableDie({
    required this.node,
    required this.label,
    required this.faceMap,
    required this.restY,
    required this.restRotation,
    required this.radius,
  });

  final LocalId node;
  final String label;
  final DieFaceMap faceMap;

  /// The rack pose: [restRotation] puts a face squarely up, and
  /// [restY] is the node-origin height at which the die then rests on
  /// the table — racking puts it there so a reset doesn't tip or drop
  /// the dice into an unrequested roll.
  final double restY;
  final Quaternion restRotation;

  /// Bounding-sphere radius — keeps racked dice clear of the walls.
  final double radius;
}

/// Everything the screen needs from [buildDiceTable].
final class DiceTableScene {
  const DiceTableScene({
    required this.document,
    required this.dice,
    required this.cameraNode,
    required this.wallNodes,
    required this.ceilingNode,
    required this.layout,
  });

  final SceneDocument document;

  /// The dice in rack order.
  final List<TableDie> dice;
  final LocalId cameraNode;

  /// +X, −X, +Z, −Z walls, matching [TrayLayout.walls].
  final List<LocalId> wallNodes;
  final LocalId ceilingNode;

  /// The layout the document was built with; the screen refits it to
  /// the real view and writes the new poses.
  final TrayLayout layout;
}

/// The bundled imported dice — label → `.fsceneb` asset key. The d4 is
/// the procedural crystal shard ([addShardD4]), not an asset.
const _diceAssets = {
  'd6': 'assets/dice/scene.d6.dbe505b8.fsceneb',
  'd8': 'assets/dice/scene.d8.dbe51f72.fsceneb',
  'd10t': 'assets/dice/scene.d10t.862039c2.fsceneb',
  'd10u': 'assets/dice/scene.d10u.86203b0d.fsceneb',
  'd12': 'assets/dice/scene.d12.a5cbecd0.fsceneb',
  'd20': 'assets/dice/scene.d20.a5fdb0b1.fsceneb',
};

/// Rack order.
const kDiceOrder = ['d4', 'd6', 'd8', 'd10t', 'd10u', 'd12', 'd20'];

/// Diameter of the d20 in world units (its bounds span ±9.63).
const double kD20Diameter = 19.26;

/// Rendered d20 size as a fraction of the screen's short side — about
/// upstream's (its d6 is ~70 px on a ~400 px-wide phone).
const double kD20ScreenFraction = 0.15;

/// Logical px per world unit on the table for a view whose short side
/// is [shortestSide] — constant across rotation, so dice keep their
/// size when the phone turns.
double trayPxPerUnit(double shortestSide) =>
    kD20ScreenFraction * shortestSide / kD20Diameter;

/// Half-extent of the (square) tabletop — wider than the visible area
/// of any phone or tablet at [trayPxPerUnit], so the view is always
/// wood.
const double kTableHalf = 320.0;

/// Edge of the synthesized wood texture, in pixels.
const int kWoodTextureSize = 512;

/// A [kWoodTextureSize]² RGBA wood texture, synthesized at build time —
/// no asset file, so the document carries it as an `rgba8` payload that
/// both backends upload verbatim.
///
/// The grain is elongated turbulence-driven banding (walnut tones);
/// the vignette is *baked*: Filament measures point/spot intensity in
/// candela while SceneKit uses a unitless multiplier, so a real lamp
/// would fall off differently per platform. Darkening the texture
/// toward the edges gives the pool-table lamp look identically
/// everywhere — the wood is still lit, so dice shadows and speculars
/// land on it normally.
Uint8List _woodTexture() {
  const n = kWoodTextureSize;
  final px = Uint8List(n * n * 4);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final nx = x / (n / 2) - 1, ny = y / (n / 2) - 1;
      // Grain: rings stretched along v → long wavy lines running
      // down the table, like boards.
      final gx = nx * 5.0, gy = ny * 0.9;
      final d = sqrt(gx * gx + gy * gy);
      final turb =
          0.55 * sin(gx * 4.2 + gy * 9.1) +
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
      final t = (line * 0.55 + tone * 0.45 + noise).clamp(0.0, 1.0);
      // Walnut: light ↔ dark.
      var r = 0.32 + 0.30 * t, g = 0.20 + 0.185 * t, b = 0.10 + 0.10 * t;
      // Baked vignette — bright centre, darker toward a phone's long
      // edges (world radius ~150).
      final rw = sqrt(nx * nx + ny * ny) * kTableHalf;
      final edge = ((rw - 70) / 150).clamp(0.0, 1.0);
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
/// glb's `extras.face_map_json`). The JSON normals are glTF (right-
/// handed, Y-up); the `.fsceneb` meshes and the settle poses are in the
/// document's left-handed frame, so z is mirrored here, once, on load.
/// [bytesFor] overrides the bundle lookup for tests.
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
            -(n[2] as num).toDouble(),
          ),
          v.toInt(),
        ),
      );
    }
    out[die] = DieFaceMap(faces: faces);
  });
  return out;
}

/// The shard d4's face map (document space, from [kShardFaces]).
final DieFaceMap shardFaceMap = DieFaceMap(
  faces: [for (final (n, v) in kShardFaces) DieFace(n, v)],
);

/// Table physics, ported from upstream "Dice Shadows"
/// (docs/design/demo-program.md §3.2) and scaled by [kUpstreamUnit]:
/// heavy gravity (−30 u/s² ≈ 3 g), lively-but-damped contacts, CCD on
/// the dice, contact coefficients averaged per pair like Rapier.
/// [throwScale]/[spinScale] are read at roll time; the rest bake into
/// the document.
final class DiceTableSpec {
  const DiceTableSpec({
    this.gravity = 30 * kUpstreamUnit,
    this.dieRestitution = 0.35,
    this.dieFriction = 0.5,
    this.boundsRestitution = 0.45,
    this.boundsFriction = 0.4,
    this.linearDamping = 0.0,
    this.angularDamping = 0.3,
    this.throwScale = 1.0,
    this.spinScale = 1.0,
  });

  /// Gravity magnitude (the world's gravity vector is −Y).
  final double gravity;

  /// Dice: `friction 0.5, restitution 0.35` upstream.
  final double dieRestitution, dieFriction;

  /// Table, walls and ceiling: `friction 0.4, restitution 0.45`.
  final double boundsRestitution, boundsFriction;

  /// Velocity bleed per second. Upstream: none linear, 0.3 angular.
  final double linearDamping, angularDamping;

  /// Multipliers on the throw's launch speed and tumble rate.
  final double throwScale, spinScale;
}

/// Builds the composed dice-table document: table, walls and ceiling
/// fitted to [layout], the seven dice, camera, lights, environment.
/// [bytesFor] overrides the bundle lookup for tests; [spec] tunes the
/// physics. The screen refits the layout to its real size.
DiceTableScene? buildDiceTable({
  Uint8List? Function(String key)? bytesFor,
  void Function(String message)? log,
  DiceTableSpec spec = const DiceTableSpec(),
  TrayLayout? layout,
}) {
  final bytesOf = bytesFor ?? (_) => null;
  final faceMaps = loadDiceFaceMaps(bytesFor: bytesFor);
  final host = SceneDocument();
  // Until the screen measures itself: a typical portrait phone.
  final fit =
      layout ??
      TrayLayout.fit(
        width: 412,
        height: 915,
        pxPerUnit: trayPxPerUnit(412),
        insetTop: 96,
        insetBottom: 120,
      );

  ComponentSpec boundsCollider(Vector3 extents) => colliderComponent(
    shape: 'box',
    extents: extents,
    friction: spec.boundsFriction,
    restitution: spec.boundsRestitution,
    frictionCombine: 'average',
    restitutionCombine: 'average',
  );

  // Wood tabletop: a deep slab (a die at full throw speed moves ~5
  // units per substep; 40 is unpassable), its top face at y = 0.
  const slabThick = 40.0;
  final woodPixels = _woodTexture();
  final woodPayload = host.addPayload(
    PayloadSpec(
      host.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: kWoodTextureSize,
      height: kWoodTextureSize,
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
  final topExtents = Vector3(kTableHalf * 2, slabThick, kTableHalf * 2);
  final topGeo = host.addResource(
    GeometryResource(
      host.newId(),
      procedural: CuboidGeometrySpec(extents: topExtents),
    ),
  );
  host.createNode(
    name: 'tray.top',
    transform: TrsTransform(translation: Vector3(0, -slabThick / 2, 0)),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(topGeo.id),
          'material': ResourceRefValue(wood.id),
        },
      ),
      boundsCollider(topExtents),
      rigidBodyComponent(type: 'fixed'),
    ],
    root: true,
  );

  // Invisible walls in the camera frustum's side planes, plus a
  // ceiling — the screen edges are the tray. The screen moves them
  // (transform writes) whenever its size or insets change.
  LocalId slab(String name, TrayPose pose, Vector3 extents) => host
      .createNode(
        name: name,
        transform: TrsTransform(
          translation: pose.position,
          rotation: pose.rotation,
        ),
        components: [
          boundsCollider(extents),
          rigidBodyComponent(type: 'fixed'),
        ],
        root: true,
      )
      .id;
  final wallExtents = Vector3(kTrayWallThick, kTrayWallSpan, kTrayWallSpan);
  final wallNodes = [
    for (final (i, side) in const ['x+', 'x-', 'z+', 'z-'].indexed)
      slab('tray.wall.$side', fit.walls[i], wallExtents),
  ];
  final ceilingNode = slab(
    'tray.ceiling',
    fit.ceiling,
    Vector3(kTrayWallSpan, kTrayWallThick, kTrayWallSpan),
  );
  // 120 Hz substeps: at full throw speed (~600 u/s) a die moves ~5
  // units per step against 15+ unit dice, CCD on top.
  host.createNode(
    name: 'tray.world',
    components: [
      physicsWorldComponent(
        gravity: Vector3(0, -spec.gravity, 0),
        fixedTimestep: 1.0 / 120.0,
        maxSubsteps: 4,
      ),
    ],
    root: true,
  );

  ComponentSpec dieCollider() => colliderComponent(
    shape: 'convexHull',
    friction: spec.dieFriction,
    restitution: spec.dieRestitution,
    frictionCombine: 'average',
    restitutionCombine: 'average',
  );
  ComponentSpec dieBody() => rigidBodyComponent(
    type: 'dynamic',
    mass: 1.0,
    linearDamping: spec.linearDamping,
    angularDamping: spec.angularDamping,
    ccdEnabled: true,
  );

  // Pre-decode each imported die once: `resolve` reuses the cached
  // document, and the mesh gives each die's rack pose (its highest
  // face turned squarely up, resting on the table) and radius.
  final prefabDocs = <String, SceneDocument>{};
  final restPoses = <String, (double, Quaternion)>{};
  final radii = <String, double>{};
  for (final e in _diceAssets.entries) {
    final bytes = bytesOf(e.value);
    if (bytes == null) continue;
    final doc = readFsceneb(bytes);
    prefabDocs[e.value] = doc;
    final faces = faceMaps[e.key]?.faces ?? const <DieFace>[];
    final rotation = faces.isEmpty
        ? Quaternion.identity()
        : faceUpRotation(
            faces.reduce((a, b) => a.normal.y >= b.normal.y ? a : b).normal,
          );
    final m = rotation.asRotationMatrix();
    var minY = double.infinity;
    var radius = 0.0;
    for (final res in doc.resources.values.whereType<GeometryResource>()) {
      for (final p in _positions(doc, res)) {
        minY = min(minY, (m * p).y);
        radius = max(radius, p.length);
      }
    }
    if (minY.isFinite) restPoses[e.key] = (-minY + 0.2, rotation);
    radii[e.key] = radius;
  }

  final slots = fit.rack(kDiceOrder.length, _rackSpacing(radii.values));
  final dice = <TableDie>[];
  for (final (i, label) in kDiceOrder.indexed) {
    final (x, z) = slots[i];
    if (label == 'd4') {
      final shard = addShardD4(host);
      final node = host.createNode(
        name: 'die.d4',
        transform: TrsTransform(translation: Vector3(x, shard.restY, z)),
        components: [shard.mesh, dieCollider(), dieBody()],
        root: true,
      );
      dice.add(
        TableDie(
          node: node.id,
          label: label,
          faceMap: shardFaceMap,
          restY: shard.restY,
          restRotation: Quaternion.identity(),
          radius: shard.radius,
        ),
      );
      continue;
    }
    final asset = _diceAssets[label]!;
    if (!prefabDocs.containsKey(asset)) continue;
    final (restY, restRotation) =
        restPoses[label] ?? (12.0, Quaternion.identity());
    final node = host.createNode(
      name: 'die.$label',
      transform: TrsTransform(
        translation: Vector3(x, restY, z),
        rotation: restRotation,
      ),
      root: true,
    );
    node.instance = PrefabInstanceSpec(
      source: AssetRef(asset),
      addedComponents: [dieCollider(), dieBody()],
    );
    dice.add(
      TableDie(
        node: node.id,
        label: label,
        faceMap: faceMaps[label] ?? const DieFaceMap(faces: []),
        restY: restY,
        restRotation: restRotation,
        radius: radii[label] ?? 12.0,
      ),
    );
  }

  SceneDocument resolve(AssetRef ref) =>
      prefabDocs[ref.key] ??
      (throw StateError('missing bundled asset ${ref.key}'));

  final composed = composeScene(host, resolve: resolve);

  final cam = fit.camera;
  final camera = composed.createNode(
    name: 'table.camera',
    transform: TrsTransform(translation: cam.position, rotation: cam.rotation),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': StringValue('perspective'),
          'fovRadiansY': DoubleValue(kTrayFovY),
          'near': DoubleValue(10.0),
          'far': DoubleValue(3000.0),
        },
      ),
    ],
    root: true,
  );

  // Warm key steeply overhead — shadows sit mostly under the dice
  // like the lamp-over-table reference — plus a cool fill; studio env
  // dimmed so the key's shadows stay visible. Lights travel along +Z
  // (upstream DirectionalLightComponent.worldDirection = rotation ×
  // (0,0,1)); `aimAlong` points +Z along the travel direction.
  composed.createNode(
    name: 'table.key',
    transform: TrsTransform(rotation: aimAlong(Vector3(-0.28, -1.0, -0.22))),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': ColorValue(1.0, 0.93, 0.82, 1),
          'intensity': DoubleValue(keyLightIntensity(2400)),
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
    transform: TrsTransform(translation: Vector3(-70, 90, 220)),
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
    wallNodes: wallNodes,
    ceilingNode: ceilingNode,
    layout: fit,
  );
}

/// Rack spacing: the widest die plus a little air.
double _rackSpacing(Iterable<double> radii) =>
    radii.fold(kShardSection * (kShardHalfRatio + kShardCapRatio), max) * 2.3;

/// Rack spacing for [dice] — the screen's reset uses the same grid.
double rackSpacingFor(List<TableDie> dice) =>
    _rackSpacing(dice.map((d) => d.radius));

/// A rotation taking the mesh-space direction [n] to world +Y.
Quaternion faceUpRotation(Vector3 n) {
  final up = Vector3(0, 1, 0);
  final u = n.normalized();
  final axis = u.cross(up);
  if (axis.length < 1e-9) {
    return u.y > 0
        ? Quaternion.identity()
        : Quaternion.axisAngle(Vector3(1, 0, 0), pi);
  }
  return Quaternion.axisAngle(
    axis.normalized(),
    acos(u.dot(up).clamp(-1.0, 1.0)),
  );
}

/// Vertex positions of an imported geometry's payload (the importer's
/// SoA layout, or an interleaved one).
Iterable<Vector3> _positions(SceneDocument doc, GeometryResource geo) sync* {
  final payload = doc.payloads[geo.vertices];
  final bytes = payload?.bytes;
  if (payload == null || bytes == null) return;
  final soa = payload.layout?.contains('soa') ?? false;
  final stride = switch (payload.layout) {
    'unskinned_soa_uv1_tangent' || 'unskinned_uv1_tangent' => 72,
    'unskinned_soa' || 'unskinned' || null => 48,
    _ => 0,
  };
  if (stride == 0) return;
  final data = ByteData.sublistView(bytes);
  final count = bytes.length ~/ stride;
  for (var i = 0; i < count; i++) {
    final o = soa ? i * 12 : i * stride;
    yield Vector3(
      data.getFloat32(o, Endian.little),
      data.getFloat32(o + 4, Endian.little),
      data.getFloat32(o + 8, Endian.little),
    );
  }
}
