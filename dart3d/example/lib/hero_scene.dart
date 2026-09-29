/// The launch hero's scene document (P4) — pure Dart (no `dartnative`
/// imports) so it runs under `dart test`. The screen lives in
/// `hero_screen.dart`.
///
/// It is the Showcase's DartNative logo on a hero [DnLogoStage], with
/// the camera and the whole light rig reparented under one
/// `hero.pivot` node at the logo's centre. Rotating the pivot orbits
/// the camera *and* carries the key/rim/fill rig with it, so the pink
/// and cyan rims stay behind the subject from every angle of the 360°
/// orbit — one transform per frame drives the whole move. The studio
/// IBL stays world-fixed, so reflections still travel over the glossy
/// surface as the camera goes round.
// ignore_for_file: implementation_imports
library;

import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart' show manifestIdKey;
import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

import 'dn_logo_stage.dart';
import 'hero_motion.dart';
import 'showcase_loader.dart';

/// The hero lens: a long-ish vertical FOV (the brief's 30–35°) for a
/// flat, product-shot perspective.
const double heroFovY = 32 * 3.141592653589793 / 180;

/// The logo's bounding sphere fills this fraction of the view width —
/// deliberately small: the operator asked for a generous zoom-out.
const double heroWidthFraction = 0.5;

/// Cap on the sphere's share of the view height (landscape / tablets).
const double heroHeightFraction = 0.34;

/// The orbit target sits this far above screen centre, as a fraction
/// of the half-height — the logo lives in the upper part of the
/// screen, over the text block.
const double heroScreenLift = 0.44;

/// Node names the loader gives the camera and the light rig — the
/// hero reparents all of them under the pivot.
const heroRigNodeNames = {
  'showcase.camera',
  'showcase.key',
  'showcase.rim.pink',
  'showcase.rim.cyan',
  'showcase.fill',
};

/// The built hero document plus the handles the screen animates.
final class HeroScene {
  const HeroScene({
    required this.document,
    required this.pivot,
    required this.center,
    required this.frameRadius,
    required this.distance,
    required this.glowMaterials,
  });

  final SceneDocument document;

  /// The orbit pivot — write [heroPivotRotation] to it.
  final LocalId pivot;

  /// The logo's bounds centre (the pivot's translation).
  final Vector3 center;

  /// The logo's bounding radius and the boom length it framed to.
  final double frameRadius;
  final double distance;

  /// The self-glowing (textured) materials — the breath re-sends these
  /// with a new emissive factor.
  final List<LocalId> glowMaterials;
}

/// The pivot rotation for an orbit at [yaw] / [pitch]: yaw about world
/// up, then the elevation about the pivot's right axis (the camera
/// sits on the pivot's −Z side looking +Z, so +pitch raises it).
Quaternion heroPivotRotation(double yaw, double pitch) =>
    Quaternion.axisAngle(Vector3(0, 1, 0), yaw) *
    Quaternion.axisAngle(Vector3(1, 0, 0), pitch);

/// Where the camera sits in world space for an orbit at [yaw] /
/// [pitch] around [center] at [distance] — the pivot composition, for
/// tests and logs. (Through the rotation matrix: vector_math's
/// `Quaternion.rotated` applies the inverse rotation.)
Vector3 heroCameraPosition({
  required Vector3 center,
  required double distance,
  required double yaw,
  required double pitch,
}) =>
    center +
    heroPivotRotation(yaw, pitch)
        .asRotationMatrix()
        .transformed(Vector3(0, 0, -distance));

/// Builds the hero document for a view of [aspect] (width / height).
/// [initialYaw] / [initialPitch] author the pivot's first pose so the
/// first frame already sits on the orbit. Returns null when the logo
/// asset is missing.
HeroScene? buildHeroScene({
  required Uint8List? Function(String key) bytesFor,
  required DnLogoStage stage,
  required double aspect,
  double initialYaw = 0,
  double initialPitch = 8 * 3.141592653589793 / 180,
  void Function(String message)? log,
}) {
  final scene = loadShowcaseScene(
    ShowcaseItem(
      'dartnative_logo',
      'assets/showcase/dn_logo.fsceneb',
      'hero',
      // Level and face-on from the glyph's reading side (−Z); the
      // pivot adds the elevation.
      cameraDir: (0.0, 0.0, -1.0),
      stage: stage,
    ),
    bytesFor: bytesFor,
    log: log,
  );
  if (scene == null) return null;
  final doc = scene.document;
  final center = scene.cameraTarget;
  final distance = heroBoomDistance(
    frameRadius: scene.frameRadius,
    fovY: heroFovY,
    aspect: aspect,
    widthFraction: heroWidthFraction,
    heightFraction: heroHeightFraction,
  );

  final pivot = doc.createNode(
    name: 'hero.pivot',
    transform: TrsTransform(
      translation: center.clone(),
      rotation: heroPivotRotation(initialYaw, initialPitch),
    ),
    root: true,
  );
  for (final node in doc.nodes.values.toList()) {
    if (!heroRigNodeNames.contains(node.name)) continue;
    doc.roots.remove(node.id);
    pivot.children.add(node.id);
    final t = node.transform;
    if (t is TrsTransform) {
      node.transform = TrsTransform(
        translation: t.translation - center,
        rotation: t.rotation,
        scale: t.scale,
      );
    }
  }

  // The camera: on the pivot's −Z axis looking +Z, tipped down so the
  // target rides above screen centre; the hero lens.
  final camera = doc.nodes[scene.cameraNode]!;
  camera.transform = TrsTransform(
    translation: Vector3(0, 0, -distance),
    rotation: Quaternion.axisAngle(
      Vector3(1, 0, 0),
      heroAimDrop(fovY: heroFovY, screenLift: heroScreenLift),
    ),
  );
  final cam = camera.components.firstWhere((c) => c.type == 'camera');
  cam.properties['fovRadiansY'] = DoubleValue(heroFovY);
  cam.properties['far'] = DoubleValue(distance + scene.frameRadius * 40);

  final glow = [
    for (final r in doc.resources.values)
      if (r is MaterialResource && r.properties['baseColorTexture'] != null)
        r.id,
  ];
  log?.call(
    'dart3d: hero — frameRadius ${scene.frameRadius.toStringAsFixed(3)} '
    'dist ${distance.toStringAsFixed(3)} aspect ${aspect.toStringAsFixed(3)} '
    'glow ${glow.length} mat(s)',
  );
  return HeroScene(
    document: doc,
    pivot: pivot.id,
    center: center,
    frameRadius: scene.frameRadius,
    distance: distance,
    glowMaterials: glow,
  );
}

/// The `upsertResource` ops that set every glow material in [doc] to
/// emit its base-color texture at [glow] — the breath's wire form.
/// Mutates the document's materials (the controller mirror folds the
/// same state back in).
List<Map<String, Object?>> heroGlowOps(
  SceneDocument doc,
  List<LocalId> materials,
  double glow,
) {
  final idKey = manifestIdKey(doc);
  final ops = <Map<String, Object?>>[];
  for (final id in materials) {
    final r = doc.resources[id];
    if (r is! MaterialResource) continue;
    final base = r.properties['baseColorTexture'];
    if (base == null) continue;
    r.properties['emissiveTexture'] = base;
    r.properties['emissive'] = ColorValue(glow, glow, glow, 1);
    ops.add({
      'op': 'upsertResource',
      'id': idKey(id),
      'resource': encodeResource(r, idKey),
    });
  }
  return ops;
}
