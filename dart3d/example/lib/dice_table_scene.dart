/// The dice-table document builder — pure Dart (no `dartnative`
/// imports) so the compose path is reachable under `dart test`. The
/// screen lives in `dice_table.dart`, which passes `loadAssetBytes`
/// and `dnLog` in through the parameters. Pulls the pure-Dart dart3d
/// libraries directly — the barrel needs DartNative's patched SDK.
///
/// The table is the DartNative set (`dice_set.dart`: black frosted
/// dice, the 3D logo glowing inside each) on the Obsidian tray
/// (`dice_obsidian_tray.dart`), top-down, the walls fitted to the
/// screen (`dice_tray_layout.dart`).
// ignore_for_file: implementation_imports
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/physics.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

import 'dice_obsidian_tray.dart';
import 'dice_polyhedra.dart';
import 'dice_set.dart';
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

/// One die on the table: its node, display label, face map and size,
/// and the logo inside it.
final class TableDie {
  const TableDie({
    required this.node,
    required this.label,
    required this.faceMap,
    required this.restY,
    required this.restRotation,
    required this.radius,
    this.logo,
    this.logoFacing,
  });

  final LocalId node;
  final String label;
  final DieFaceMap faceMap;

  /// The rack pose: [restRotation] puts the highest face squarely up,
  /// reading upright, and [restY] is the node-origin height at which the
  /// die then rests on the table.
  final double restY;
  final Quaternion restRotation;

  /// Bounding-sphere radius — keeps racked dice clear of the walls.
  final double radius;

  /// The logo node inside the die (a child), and the world rotation it
  /// is held at whatever the die does: level, reading side up, with a
  /// small per-die roll ([logoLocalRotation]).
  final LocalId? logo;
  final Quaternion? logoFacing;

  /// The logo's local rotation for the die at world [dieRotation].
  Quaternion? logoLocalRotation(Quaternion dieRotation) {
    final f = logoFacing;
    return f == null ? null : dieRotation.conjugated() * f;
  }
}

/// Everything the screen needs from [buildDiceTable].
final class DiceTableScene {
  const DiceTableScene({
    required this.document,
    required this.dice,
    required this.cameraNode,
    required this.wallNodes,
    required this.ceilingNode,
    required this.rimNodes,
    required this.layout,
  });

  final SceneDocument document;

  /// The dice in rack order.
  final List<TableDie> dice;
  final LocalId cameraNode;

  /// +X, −X, +Z, −Z walls, matching [TrayLayout.walls].
  final List<LocalId> wallNodes;
  final LocalId ceilingNode;

  /// The rim pieces, in [kRimPieces] order ([rimPoses]).
  final List<LocalId> rimNodes;

  /// The layout the document was built with; the screen refits it to
  /// the real view and writes the new poses.
  final TrayLayout layout;
}

/// Rack order.
const kDiceOrder = kDieKinds;

/// Diameter of the d20 in world units.
const double kD20Diameter = kD20Span;

/// Rendered d20 size as a fraction of the screen's short side — about
/// upstream's (its d6 is ~70 px on a ~400 px-wide phone).
const double kD20ScreenFraction = 0.21;

/// Logical px per world unit on the table for a view whose short side
/// is [shortestSide] — constant across rotation, so dice keep their
/// size when the phone turns.
double trayPxPerUnit(double shortestSide) =>
    kD20ScreenFraction * shortestSide / kD20Diameter;

/// The logo asset (P4, `tool/dn_logo/build.sh`).
const kLogoAsset = 'assets/showcase/dn_logo.fsceneb';

/// The logo's half-diagonal in its own units (bounds ±1.0 × ±0.69).
const double kLogoHalfDiagonal = 1.21;

/// Logo size inside a die: its half-diagonal over the die's inradius
/// (look-dev `LOGO_FILL`) — visible, never crowding the faces.
const double kLogoFill = 0.72;

/// The logo's self-glow (its gradient texture as emissive), strong
/// enough to shine through the smoky shell.
const double kLogoGlow = 1.5;

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
    this.shell = const DiceShellLook(),
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

  /// The dice's shell material.
  final DiceShellLook shell;
}

/// Builds the table document: the Obsidian tray, walls and ceiling
/// fitted to [layout], the seven DartNative dice with a logo inside
/// each, camera, lights, environment. [bytesFor] supplies the logo
/// asset (the dice are procedural; without it they're built logo-less);
/// [spec] tunes the physics. The screen refits the layout to its real
/// size.
DiceTableScene? buildDiceTable({
  Uint8List? Function(String key)? bytesFor,
  void Function(String message)? log,
  DiceTableSpec spec = const DiceTableSpec(),
  TrayLayout? layout,
}) {
  final sw = Stopwatch()..start();
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

  final tray = addObsidianTray(
    host,
    fit,
    collider: boundsCollider,
    body: rigidBodyComponent(type: 'fixed'),
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

  final built = [
    for (final kind in kDiceOrder)
      addDartNativeDie(host, kind, look: spec.shell),
  ];
  final diceMs = sw.elapsedMilliseconds;
  final slots = fit.rack(
    built.length,
    _rackSpacing(built.map((d) => d.radius)),
  );

  // The logo: one prefab instance inside the first die, then the same
  // geometry and material shared by every other die's logo node.
  final logoBytes = bytesFor?.call(kLogoAsset);
  final logoDoc = logoBytes == null ? null : readFsceneb(logoBytes);
  final rng = Random(0xD1CE);
  final dieNodes = <NodeSpec>[];
  final logoNodes = <LocalId?>[];
  final facings = <Quaternion>[];
  for (final (i, d) in built.indexed) {
    final (x, z) = slots[i];
    final node = host.createNode(
      name: 'die.${d.kind}',
      transform: TrsTransform(
        translation: Vector3(x, d.restY, z),
        rotation: d.restRotation,
      ),
      components: [d.mesh, dieCollider(), dieBody()],
      root: true,
    );
    dieNodes.add(node);
    // Held level with its reading side (−Z) to the camera, screen-up
    // (+Z) its up, turned a little per die so the set doesn't look
    // stamped.
    final roll = (rng.nextDouble() - 0.5) * 2 * 12 * pi / 180;
    final facing =
        Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2) *
        Quaternion.axisAngle(Vector3(0, 0, 1), roll);
    facings.add(facing);
    if (logoDoc == null) {
      logoNodes.add(null);
      continue;
    }
    final scale = kLogoFill * d.inradius / kLogoHalfDiagonal;
    final logo = host.createNode(
      name: 'die.${d.kind}.logo',
      transform: TrsTransform(
        rotation: d.restRotation.conjugated() * facing,
        scale: Vector3.all(scale),
      ),
    );
    node.children.add(logo.id);
    if (i == 0) {
      logo.instance = PrefabInstanceSpec(source: AssetRef(kLogoAsset));
    }
    logoNodes.add(logo.id);
  }

  final composeStart = sw.elapsedMilliseconds;
  final composed = composeScene(
    host,
    resolve: (ref) => ref.key == kLogoAsset && logoDoc != null
        ? logoDoc
        : (throw StateError('missing bundled asset ${ref.key}')),
  );

  // Share the first logo's mesh with the others, and make it glow.
  final firstLogo = logoNodes.firstOrNull;
  if (firstLogo != null) {
    final mesh = composed.nodes[firstLogo]!.components.firstWhere(
      (c) => c.type == 'mesh',
    );
    final matRef = mesh.properties['material'];
    if (matRef is ResourceRefValue) {
      final mat = composed.resources[matRef.id];
      if (mat is MaterialResource) {
        final base = mat.properties['baseColorTexture'];
        if (base != null) mat.properties['emissiveTexture'] = base;
        mat.properties['emissive'] = ColorValue(1, 1, 1, 1);
        mat.properties['emissiveStrength'] = DoubleValue(kLogoGlow);
        // Opaque: the asset's blended material is depth-sorted against
        // the shell around it (same centre, so either order), and drawn
        // last it covered the numerals. In the opaque pass it writes
        // depth and the shell always composites over it.
        mat.properties['alphaMode'] = StringValue('opaque');
      }
    }
    for (final id in logoNodes.skip(1)) {
      if (id == null) continue;
      composed.nodes[id]!.components.add(
        ComponentSpec('mesh', properties: Map.of(mesh.properties)),
      );
    }
  }

  final dice = [
    for (final (i, d) in built.indexed)
      TableDie(
        node: dieNodes[i].id,
        label: d.kind,
        faceMap: d.faceMap,
        restY: d.restY,
        restRotation: d.restRotation,
        radius: d.radius,
        logo: logoNodes[i],
        logoFacing: logoNodes[i] == null ? null : facings[i],
      ),
  ];

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

  // One key from screen upper-left at ~50° — low enough that its mirror
  // image never lands on the glossy floor or the top faces (look-dev
  // §0.2 rule 5) — casting the dice's shadows; a dim studio IBL for the
  // clear coats and bevels to catch.
  composed.createNode(
    name: 'table.key',
    transform: TrsTransform(rotation: aimAlong(Vector3(0.55, -1.0, -0.62))),
    components: [
      ComponentSpec(
        'directionalLight',
        properties: {
          'color': ColorValue(1.0, 0.96, 0.9, 1),
          'intensity': DoubleValue(keyLightIntensity(2200)),
          'castsShadow': BoolValue(true),
          'shadowRadius': DoubleValue(2.5),
          'shadowDepthBias': DoubleValue(0.01),
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
          environmentIntensity: 0.25,
          exposure: 1.0,
          toneMapping: 'pbrNeutral',
          skybox: SkyboxSpec(
            GradientSkySpec(
              zenithColor: Vector3(0.0027, 0.0044, 0.006),
              horizonColor: Vector3(0.0027, 0.0044, 0.006),
              groundColor: Vector3(0.0027, 0.0044, 0.006),
              sunColor: Vector3.zero(),
            ),
          ),
          effects: EnvironmentEffectsSpec(
            // Bloom only well above the numerals' level (look-dev §5
            // risk 1): the rim and the logos' hottest parts glow, the
            // numerals' keylines stay crisp.
            bloomEnabled: true,
            bloomThreshold: 1.1,
            bloomIntensity: 0.35,
            bloomScatter: 0.6,
          ),
        ),
      )
      .id;

  log?.call(
    'dart3d: dice table — ${dice.length} DartNative dice '
    '(logo ${logoDoc == null ? 'missing' : 'inside'}), '
    '${composed.nodes.length} nodes, ${composed.payloads.length} payloads, '
    'built in ${sw.elapsedMilliseconds} ms (dice $diceMs, compose from '
    '$composeStart)',
  );
  return DiceTableScene(
    document: composed,
    dice: dice,
    cameraNode: camera.id,
    wallNodes: wallNodes,
    ceilingNode: ceilingNode,
    rimNodes: tray.rim,
    layout: fit,
  );
}

/// Rack spacing: the widest die plus a little air.
double _rackSpacing(Iterable<double> radii) => radii.reduce(max) * 2.3;

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
