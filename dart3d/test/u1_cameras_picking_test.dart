// ignore_for_file: implementation_imports
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/src/bvh.dart';
import 'package:dart3d/src/camera.dart';
import 'package:dart3d/src/camera_controllers.dart';
import 'package:dart3d/src/geometry/instances.dart';
import 'package:dart3d/src/geometry/proc.dart';
import 'package:dart3d/src/raycast.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/scene_pointer.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('SceneCamera & lookAt helpers', () {
    test('lookAtRotation composes to the literal camera basis', () {
      final eye = Vector3(0, 2, -6);
      final target = Vector3(0, 0, 0);
      final rot = lookAtRotation(eye, target);
      expect(rot.length, closeTo(1.0, 1e-6));

      final matrix = Matrix4.compose(Vector3.zero(), rot, Vector3.all(1));
      final right = matrix.transform3(Vector3(1, 0, 0));
      final trueUp = matrix.transform3(Vector3(0, 1, 0));
      final forward = matrix.transform3(Vector3(0, 0, 1));
      expect(right.x, closeTo(1, 1e-5));
      expect(right.y, closeTo(0, 1e-5));
      expect(right.z, closeTo(0, 1e-5));
      expect(trueUp.x, closeTo(0, 1e-5));
      expect(trueUp.y, closeTo(3 / math.sqrt(10), 1e-5));
      expect(trueUp.z, closeTo(1 / math.sqrt(10), 1e-5));
      expect(forward.x, closeTo(0, 1e-5));
      expect(forward.y, closeTo(-1 / math.sqrt(10), 1e-5));
      expect(forward.z, closeTo(3 / math.sqrt(10), 1e-5));
    });

    test(
      'screenPointToRay and worldToScreen round-trip in perspective mode',
      () {
        final cam = SceneCamera.perspective(
          position: Vector3(0, 1.5, -6),
          target: Vector3(0, 0.5, 0),
          fovRadiansY: 50 * degrees2Radians,
        );
        const viewW = 800.0;
        const viewH = 600.0;

        // Center of screen projects to camera target.
        final centerScreen = cam.worldToScreen(cam.target, viewW, viewH);
        expect(centerScreen, isNotNull);
        expect(centerScreen!.$1, closeTo(viewW * 0.5, 1e-4));
        expect(centerScreen.$2, closeTo(viewH * 0.5, 1e-4));

        // Arbitrary off-center world point in front of camera round-trips.
        final worldPt = Vector3(1.2, -0.4, 2.0);
        final screenPt = cam.worldToScreen(worldPt, viewW, viewH);
        expect(screenPt, isNotNull);

        final ray = cam.screenPointToRay(
          screenPt!.$1,
          screenPt.$2,
          viewW,
          viewH,
        );
        final dist = (worldPt - cam.position).length;
        final reconstructed = ray.origin + ray.direction * dist;
        expect(reconstructed.x, closeTo(worldPt.x, 1e-4));
        expect(reconstructed.y, closeTo(worldPt.y, 1e-4));
        expect(reconstructed.z, closeTo(worldPt.z, 1e-4));

        // Point behind camera returns null.
        expect(cam.worldToScreen(Vector3(0, 1.5, -10), viewW, viewH), isNull);
      },
    );

    test(
      'screenPointToRay and worldToScreen round-trip in orthographic mode',
      () {
        final cam = SceneCamera.orthographic(
          position: Vector3(0, 0, -10),
          target: Vector3(0, 0, 0),
          orthoScale: 4.0,
        );
        const viewW = 800.0;
        const viewH = 400.0; // aspect = 2.0 -> halfW = 8.0, halfH = 4.0

        final worldPt = Vector3(4.0, 2.0, 0.0);
        final screenPt = cam.worldToScreen(worldPt, viewW, viewH);
        expect(screenPt, isNotNull);
        expect(screenPt!.$1, closeTo(600.0, 1e-4)); // ndcX = +0.5 -> 0.75 * 800
        expect(screenPt.$2, closeTo(100.0, 1e-4)); // ndcY = +0.5 -> 0.25 * 400

        final ray = cam.screenPointToRay(
          screenPt.$1,
          screenPt.$2,
          viewW,
          viewH,
        );
        expect(ray.origin.x, closeTo(4.0, 1e-4));
        expect(ray.origin.y, closeTo(2.0, 1e-4));
        expect(ray.origin.z, closeTo(-10.0, 1e-4));
        expect(ray.direction.z, closeTo(1.0, 1e-5));
      },
    );

    test('SceneCamera.fromDocument extracts primary view camera', () {
      final doc = SceneDocument();
      final camId = doc.newId();
      doc.addNode(
        NodeSpec(
          id: camId,
          transform: lookAtTransform(Vector3(0, 3, -8), Vector3(0, 0, 0)),
          components: [
            ComponentSpec(
              'camera',
              properties: {
                'projection': const StringValue('perspective'),
                'fovRadiansY': const DoubleValue(0.9),
                'near': const DoubleValue(0.2),
                'far': const DoubleValue(250.0),
              },
            ),
          ],
        ),
      );
      doc.roots.add(camId);
      doc.views.add(RenderViewSpec(cameraNode: camId));

      final cam = SceneCamera.fromDocument(doc);
      expect(cam, isNotNull);
      expect(cam!.nodeId, equals(camId));
      expect(cam.position.x, closeTo(0, 1e-5));
      expect(cam.position.y, closeTo(3, 1e-5));
      expect(cam.position.z, closeTo(-8, 1e-5));
      expect(cam.fovRadiansY, closeTo(0.9, 1e-5));
      expect(cam.near, closeTo(0.2, 1e-5));
      expect(cam.far, closeTo(250.0, 1e-5));
    });
  });

  group('CameraController implementations', () {
    test('OrbitCameraController orbits, pans, zooms, and damps', () {
      final orbit = OrbitCameraController(
        target: Vector3.zero(),
        distance: 10.0,
        azimuth: 0.0,
        elevation: 0.0,
        damping: 0.0,
      );
      expect(orbit.camera.position.x, closeTo(0.0, 1e-5));
      expect(orbit.camera.position.y, closeTo(0.0, 1e-5));
      expect(orbit.camera.position.z, closeTo(-10.0, 1e-5));

      // Orbit by +pi/2 azimuth -> camera moves to (+10, 0, 0).
      orbit.orbitBy(math.pi / 2, 0.0);
      expect(orbit.camera.position.x, closeTo(10.0, 1e-5));
      expect(orbit.camera.position.z, closeTo(0.0, 1e-5));

      // Zoom in by 0.5 -> distance becomes 5.0.
      orbit.zoomByFactor(0.5);
      expect(orbit.distance, closeTo(5.0, 1e-5));
      expect(orbit.camera.position.x, closeTo(5.0, 1e-5));

      // Pan up by +2.0 -> target.y and camera.position.y both shift by +2.0.
      orbit.panBy(0.0, 2.0);
      expect(orbit.target.y, closeTo(2.0, 1e-5));
      expect(orbit.camera.position.y, closeTo(2.0, 1e-5));

      // Damped orbit converges toward desired azimuth over update steps.
      final damped = OrbitCameraController(
        distance: 8.0,
        azimuth: 0.0,
        elevation: 0.0,
        damping: 0.5,
      );
      damped.orbitBy(1.0, 0.4);
      expect(damped.azimuth, closeTo(0.0, 1e-6));
      for (var i = 0; i < 60; i++) {
        damped.update(1 / 60);
      }
      expect(damped.azimuth, closeTo(1.0, 1e-3));
      expect(damped.elevation, closeTo(0.4, 1e-3));
    });

    test('FlyCameraController supports WASD keys and V6f setMoveInput', () {
      final fly = FlyCameraController(
        position: Vector3(0, 1, -5),
        yaw: 0.0,
        pitch: 0.0,
        moveSpeed: 4.0,
        boostMultiplier: 2.5,
      );

      fly.setMoveInput(Vector2(0.0, 1.0), elevate: 0.5, boost: false);
      fly.update(1.0);
      expect(fly.camera.position.z, greaterThan(-5.0));
      expect(fly.camera.position.y, greaterThan(1.0));

      // Clear external input and use keyboard W + Shift boost.
      fly.setMoveInput(Vector2.zero());
      final zBefore = fly.camera.position.z;
      fly.onKeyEvent(CameraKey.keyW, isDown: true);
      fly.onKeyEvent(CameraKey.shiftLeft, isDown: true);
      fly.update(0.5);
      // 4.0 * 2.5 * 0.5 = 5.0 units along +Z.
      expect(fly.camera.position.z - zBefore, closeTo(5.0, 1e-4));
      fly.onKeyEvent(CameraKey.keyW, isDown: false);
      fly.onKeyEvent(CameraKey.shiftLeft, isDown: false);

      // Look right (+yaw) by pi/2 -> forward direction points along +X.
      fly.lookBy(math.pi / 2, 0.0);
      expect(fly.forwardDirection.x, closeTo(1.0, 1e-5));
      expect(fly.forwardDirection.z, closeTo(0.0, 1e-5));
    });

    test('FollowCameraController tracks moving and rotating target node', () {
      final doc = SceneDocument();
      final subjectId = doc.newId();
      doc.addNode(
        NodeSpec(
          id: subjectId,
          transform: TrsTransform(
            translation: Vector3(0, 0, 0),
            rotation: Quaternion.identity(),
          ),
        ),
      );
      doc.roots.add(subjectId);

      final follow = FollowCameraController(
        document: doc,
        targetNode: subjectId,
        offset: Vector3(0, 2, -6),
        lookAtOffset: Vector3(0, 1, 0),
        rotateOffsetWithTarget: true,
        positionSmoothing: 0.0,
        targetSmoothing: 0.0,
      );
      expect(follow.camera.position.x, closeTo(0, 1e-5));
      expect(follow.camera.position.y, closeTo(2, 1e-5));
      expect(follow.camera.position.z, closeTo(-6, 1e-5));
      expect(follow.camera.target.y, closeTo(1, 1e-5));

      // Move subject to (10, 0, 5) and rotate +90 deg around Y.
      // Local offset (0, 2, -6) rotated by +90 deg around Y becomes (-6, 2, 0).
      doc.nodes[subjectId]!.transform = TrsTransform(
        translation: Vector3(10, 0, 5),
        rotation: Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2),
      );
      follow.update(1 / 60);
      expect(follow.camera.position.x, closeTo(4.0, 1e-4));
      expect(follow.camera.position.y, closeTo(2.0, 1e-4));
      expect(follow.camera.position.z, closeTo(5.0, 1e-4));
      expect(follow.camera.target.x, closeTo(10.0, 1e-4));
      expect(follow.camera.target.y, closeTo(1.0, 1e-4));
      expect(follow.camera.target.z, closeTo(5.0, 1e-4));
    });
  });

  group('BVH & Render-Geometry Raycast + ScenePointer (5 targets)', () {
    test('Bvh build, queryRay, and updateBounds refit', () {
      final bvh = Bvh<String>.build([
        (item: 'near', min: Vector3(-1, -1, 1), max: Vector3(1, 1, 3)),
        (item: 'far', min: Vector3(-1, -1, 8), max: Vector3(1, 1, 10)),
      ]);
      final visited = <String>[];
      bvh.queryRay(
        Ray.originDirection(Vector3(0, 0, -5), Vector3(0, 0, 1)),
        visitItem: (item, maxDist) {
          visited.add(item);
          return maxDist;
        },
      );
      expect(visited, equals(['near', 'far']));

      // Move 'near' off the ray axis and refit.
      expect(
        bvh.updateBounds('near', Vector3(10, 10, 1), Vector3(12, 12, 3)),
        isTrue,
      );
      visited.clear();
      bvh.queryRay(
        Ray.originDirection(Vector3(0, 0, -5), Vector3(0, 0, 1)),
        visitItem: (item, maxDist) {
          visited.add(item);
          return maxDist;
        },
      );
      expect(visited, equals(['far']));
    });

    test(
      'raycastDocument & ScenePointer pick 5 distinct targets (procedural, payload, d3:procMesh, skinned, d3:instances)',
      () {
        final doc = SceneDocument();
        final camId = doc.newId();
        final camTransform = lookAtTransform(
          Vector3(0, 0, -10),
          Vector3(0, 0, 0),
        );
        doc.addNode(
          NodeSpec(
            id: camId,
            name: 'camera',
            transform: camTransform,
            components: [
              ComponentSpec(
                'camera',
                properties: {
                  'projection': const StringValue('perspective'),
                  'fovRadiansY': DoubleValue(45 * degrees2Radians),
                },
              ),
            ],
          ),
        );
        doc.roots.add(camId);
        doc.views.add(RenderViewSpec(cameraNode: camId));

        final matId = doc.newId();
        doc.addResource(MaterialResource(matId, type: 'physicallyBased'));

        // Target 1: Upstream procedural cuboid at (-4, 0, 0).
        final procGeoId = doc.newId();
        doc.addResource(
          GeometryResource(
            procGeoId,
            procedural: CuboidGeometrySpec(extents: Vector3.all(1.2)),
          ),
        );
        final target1 = doc.newId();
        doc.addNode(
          NodeSpec(
            id: target1,
            name: 'target_procedural',
            transform: TrsTransform(translation: Vector3(-4, 0, 0)),
            components: [
              ComponentSpec(
                'mesh',
                properties: {
                  'geometry': ResourceRefValue(procGeoId),
                  'material': ResourceRefValue(matId),
                },
              ),
            ],
          ),
        );
        doc.roots.add(target1);

        // Target 2: Payload mesh (`unskinned_uv1_tangent`) at (-2, 0, 0).
        final boxMesh = buildCuboid(Vector3.all(1.2));
        final vtxPositions = <Vector3>[
          for (var i = 0; i < boxMesh.vertexCount; i++)
            Vector3(
              boxMesh.positions[i * 3],
              boxMesh.positions[i * 3 + 1],
              boxMesh.positions[i * 3 + 2],
            ),
        ];
        final vtxNormals = <Vector3>[
          for (var i = 0; i < boxMesh.vertexCount; i++)
            Vector3(
              boxMesh.normals[i * 3],
              boxMesh.normals[i * 3 + 1],
              boxMesh.normals[i * 3 + 2],
            ),
        ];
        final vtxUvs = <Vector2>[
          for (var i = 0; i < boxMesh.vertexCount; i++)
            Vector2(boxMesh.uvs[i * 2], boxMesh.uvs[i * 2 + 1]),
        ];
        final vtxBytes = VertexPack.unskinned(
          positions: vtxPositions,
          normals: vtxNormals,
          uvs: vtxUvs,
        );
        final idxBytes = Uint8List(boxMesh.indices.length * 2);
        final idxBd = ByteData.sublistView(idxBytes);
        for (var i = 0; i < boxMesh.indices.length; i++) {
          idxBd.setUint16(i * 2, boxMesh.indices[i], Endian.little);
        }
        final vtxPayload = doc.addPayload(
          PayloadSpec(
            doc.newId(),
            encoding: PayloadEncoding.vertexBuffer,
            layout: 'unskinned_uv1_tangent',
            length: vtxBytes.length,
            bytes: vtxBytes,
          ),
        );
        final idxPayload = doc.addPayload(
          PayloadSpec(
            doc.newId(),
            encoding: PayloadEncoding.indexBuffer,
            format: 'uint16',
            length: idxBytes.length,
            bytes: idxBytes,
          ),
        );
        final payloadGeoId = doc.newId();
        doc.addResource(
          GeometryResource(
            payloadGeoId,
            vertices: vtxPayload.id,
            indices: idxPayload.id,
          ),
        );
        final target2 = doc.newId();
        doc.addNode(
          NodeSpec(
            id: target2,
            name: 'target_payload',
            transform: TrsTransform(translation: Vector3(-2, 0, 0)),
            components: [
              ComponentSpec(
                'mesh',
                properties: {
                  'geometry': ResourceRefValue(payloadGeoId),
                  'material': ResourceRefValue(matId),
                },
              ),
            ],
          ),
        );
        doc.roots.add(target2);

        // Target 3: `d3:procMesh` capsule at (0, 0, 0).
        final target3 = doc.newId();
        doc.addNode(
          NodeSpec(
            id: target3,
            name: 'target_d3proc',
            transform: TrsTransform(translation: Vector3(0, 0, 0)),
            components: [
              d3ProcMeshComponent(
                D3CapsuleProc(radius: 0.5, height: 0.6),
                material: matId,
              ),
            ],
          ),
        );
        doc.roots.add(target3);

        // Target 4: Skinned mesh (`skinned_uv1_tangent`) at (2, 0, 0), with a
        // joint node that shifts the mesh by (0, +1.5, 0) via LBS!
        final joint0 = doc.newId();
        doc.addNode(
          NodeSpec(
            id: joint0,
            name: 'joint0',
            // Joint moves +1.5 in Y relative to mesh bind origin (2, 0, 0).
            transform: TrsTransform(translation: Vector3(2, 1.5, 0)),
          ),
        );
        doc.roots.add(joint0);

        // Inverse bind matrix for joint0 at mesh bind origin -> identity.
        final ibmMat = Matrix4.identity();
        final ibmFloats = Float32List.fromList(ibmMat.storage);
        final ibmPayload = doc.addPayload(
          PayloadSpec(
            doc.newId(),
            encoding: PayloadEncoding.matrices,
            length: 64,
            bytes: ibmFloats.buffer.asUint8List(),
          ),
        );
        final skinId = doc.newId();
        doc.addSkin(
          SkinSpec(
            skinId,
            joints: [joint0],
            inverseBindMatrices: ibmPayload.id,
          ),
        );

        final skinnedBytes = VertexPack.skinned(
          positions: vtxPositions,
          normals: vtxNormals,
          uvs: vtxUvs,
          joints: List<Vector4>.filled(vtxPositions.length, Vector4.zero()),
          weights: List<Vector4>.filled(
            vtxPositions.length,
            Vector4(1, 0, 0, 0),
          ),
        );
        final skinnedVtxPayload = doc.addPayload(
          PayloadSpec(
            doc.newId(),
            encoding: PayloadEncoding.vertexBuffer,
            layout: 'skinned_uv1_tangent',
            length: skinnedBytes.length,
            bytes: skinnedBytes,
          ),
        );
        final skinnedGeoId = doc.newId();
        doc.addResource(
          GeometryResource(
            skinnedGeoId,
            vertices: skinnedVtxPayload.id,
            indices: idxPayload.id,
          ),
        );
        final target4 = doc.newId();
        doc.addNode(
          NodeSpec(
            id: target4,
            name: 'target_skinned',
            transform: TrsTransform(translation: Vector3(2, 0, 0)),
            skin: skinId,
            components: [
              ComponentSpec(
                'mesh',
                properties: {
                  'geometry': ResourceRefValue(skinnedGeoId),
                  'material': ResourceRefValue(matId),
                },
              ),
            ],
          ),
        );
        doc.roots.add(target4);

        // Target 5: `d3:instances` instanced mesh at (4, 0, 0) with 3 instances
        // at local Y = -1.5, 0.0, +1.5.
        final target5 = doc.newId();
        final instSpec = D3InstancesSpec(
          proc: D3SphereProc(radius: 0.55),
          material: matId,
          transforms: D3InstanceTransforms.inline([
            Matrix4.identity()..setTranslationRaw(0, -1.5, 0),
            Matrix4.identity()..setTranslationRaw(0, 0.0, 0),
            Matrix4.identity()..setTranslationRaw(0, 1.5, 0),
          ]),
        );
        doc.addNode(
          NodeSpec(
            id: target5,
            name: 'target_instanced',
            transform: TrsTransform(translation: Vector3(4, 0, 0)),
            components: [instSpec.toComponent()],
          ),
        );
        doc.roots.add(target5);

        // Use ScenePointer to tap-to-pick all 5 targets by projecting their
        // world centers to screen coordinates and tapping there.
        final cam = SceneCamera.fromDocument(doc)!;
        const viewW = 1000.0;
        const viewH = 600.0;
        final tapped = <(LocalId, int?)>[];
        final pointer = ScenePointer(
          document: doc,
          camera: cam,
          onTap: (node, hit) => tapped.add((node, hit.instanceIndex)),
        );

        final targetCenters = <(LocalId, int?, Vector3)>[
          (target1, null, Vector3(-4, 0, 0)),
          (target2, null, Vector3(-2, 0, 0)),
          (target3, null, Vector3(0, 0, 0)),
          (target4, null, Vector3(2, 1.5, 0)), // Deformed by joint0!
          (target5, 2, Vector3(4, 1.5, 0)), // Instance #2 of target5!
        ];

        for (final (expectedNode, expectedInstance, worldCenter)
            in targetCenters) {
          final screen = cam.worldToScreen(worldCenter, viewW, viewH);
          expect(screen, isNotNull, reason: 'screen for $expectedNode');
          pointer.press(
            screenX: screen!.$1,
            screenY: screen.$2,
            viewWidth: viewW,
            viewHeight: viewH,
          );
          final hit = pointer.release(
            screenX: screen.$1,
            screenY: screen.$2,
            viewWidth: viewW,
            viewHeight: viewH,
          );
          expect(
            hit,
            isNotNull,
            reason:
                'missed $expectedNode (inst=$expectedInstance) at $worldCenter',
          );
          expect(hit!.node, equals(expectedNode));
          expect(hit.instanceIndex, equals(expectedInstance));
        }

        expect(
          tapped,
          equals([
            (target1, null),
            (target2, null),
            (target3, null),
            (target4, null),
            (target5, 2),
          ]),
        );

        // Also verify that raycasting the un-deformed bind position (2, 0, 0) of
        // the skinned mesh misses because joint0 moved it to (2, 1.5, 0).
        final bindMiss = raycastDocument(
          doc,
          Ray.originDirection(Vector3(2, 0, -5), Vector3(0, 0, 1)),
        );
        expect(bindMiss, isNull);
      },
    );

    test(
      'raycastDocumentAll returns sorted intersections and decodes all 7 vertex layouts',
      () {
        final doc = SceneDocument();
        final matId = doc.newId();
        doc.addResource(MaterialResource(matId, type: 'physicallyBased'));

        final boxMesh = buildCuboid(Vector3.all(1.0));
        final vtxPositions = <Vector3>[
          for (var i = 0; i < boxMesh.vertexCount; i++)
            Vector3(
              boxMesh.positions[i * 3],
              boxMesh.positions[i * 3 + 1],
              boxMesh.positions[i * 3 + 2],
            ),
        ];
        final idxBytes = Uint8List(boxMesh.indices.length * 2);
        final idxBd = ByteData.sublistView(idxBytes);
        for (var i = 0; i < boxMesh.indices.length; i++) {
          idxBd.setUint16(i * 2, boxMesh.indices[i], Endian.little);
        }
        final idxPayload = doc.addPayload(
          PayloadSpec(
            doc.newId(),
            encoding: PayloadEncoding.indexBuffer,
            format: 'uint16',
            length: idxBytes.length,
            bytes: idxBytes,
          ),
        );

        // Build payloads for the remaining vertex layouts:
        // 1. unskinned (48 B/vtx)
        final unskinned48 = Uint8List(boxMesh.vertexCount * 48);
        final bd48 = ByteData.sublistView(unskinned48);
        for (var i = 0; i < boxMesh.vertexCount; i++) {
          bd48.setFloat32(i * 48, vtxPositions[i].x, Endian.little);
          bd48.setFloat32(i * 48 + 4, vtxPositions[i].y, Endian.little);
          bd48.setFloat32(i * 48 + 8, vtxPositions[i].z, Endian.little);
        }
        // 2. skinned (80 B/vtx)
        final skinned80 = Uint8List(boxMesh.vertexCount * 80);
        final bd80 = ByteData.sublistView(skinned80);
        for (var i = 0; i < boxMesh.vertexCount; i++) {
          bd80.setFloat32(i * 80, vtxPositions[i].x, Endian.little);
          bd80.setFloat32(i * 80 + 4, vtxPositions[i].y, Endian.little);
          bd80.setFloat32(i * 80 + 8, vtxPositions[i].z, Endian.little);
        }
        // 3. unskinned_soa (48 B/vtx)
        final soa48 = Uint8List(boxMesh.vertexCount * 48);
        final bdSoa48 = ByteData.sublistView(soa48);
        for (var i = 0; i < boxMesh.vertexCount; i++) {
          bdSoa48.setFloat32(i * 12, vtxPositions[i].x, Endian.little);
          bdSoa48.setFloat32(i * 12 + 4, vtxPositions[i].y, Endian.little);
          bdSoa48.setFloat32(i * 12 + 8, vtxPositions[i].z, Endian.little);
        }
        // 4. unskinned_soa_uv1_tangent (72 B/vtx)
        final soa72 = Uint8List(boxMesh.vertexCount * 72);
        final bdSoa72 = ByteData.sublistView(soa72);
        for (var i = 0; i < boxMesh.vertexCount; i++) {
          bdSoa72.setFloat32(i * 12, vtxPositions[i].x, Endian.little);
          bdSoa72.setFloat32(i * 12 + 4, vtxPositions[i].y, Endian.little);
          bdSoa72.setFloat32(i * 12 + 8, vtxPositions[i].z, Endian.little);
        }
        // 5. p3t4 (28 B/vtx)
        final p3t4Bytes = Uint8List(boxMesh.vertexCount * 28);
        final bdP3t4 = ByteData.sublistView(p3t4Bytes);
        for (var i = 0; i < boxMesh.vertexCount; i++) {
          bdP3t4.setFloat32(i * 28, vtxPositions[i].x, Endian.little);
          bdP3t4.setFloat32(i * 28 + 4, vtxPositions[i].y, Endian.little);
          bdP3t4.setFloat32(i * 28 + 8, vtxPositions[i].z, Endian.little);
        }

        final layouts = <(String, Uint8List, double)>[
          ('unskinned', unskinned48, 2.0),
          ('skinned', skinned80, 5.0),
          ('unskinned_soa', soa48, 8.0),
          ('unskinned_soa_uv1_tangent', soa72, 11.0),
          ('p3t4', p3t4Bytes, 14.0),
        ];

        final expectedNodeOrder = <LocalId>[];
        for (final (layout, bytes, z) in layouts) {
          final vp = doc.addPayload(
            PayloadSpec(
              doc.newId(),
              encoding: PayloadEncoding.vertexBuffer,
              layout: layout,
              length: bytes.length,
              bytes: bytes,
            ),
          );
          final gid = doc.newId();
          doc.addResource(
            GeometryResource(gid, vertices: vp.id, indices: idxPayload.id),
          );
          final nid = doc.newId();
          doc.addNode(
            NodeSpec(
              id: nid,
              name: 'node_$layout',
              transform: TrsTransform(translation: Vector3(0, 0, z)),
              components: [
                ComponentSpec(
                  'mesh',
                  properties: {
                    'geometry': ResourceRefValue(gid),
                    'material': ResourceRefValue(matId),
                  },
                ),
              ],
            ),
          );
          doc.roots.add(nid);
          expectedNodeOrder.add(nid);
        }

        final allHits = raycastDocumentAll(
          doc,
          Ray.originDirection(Vector3(0, 0, -5), Vector3(0, 0, 1)),
        );
        // Each cuboid has a front and back face intersection along Z -> 2 hits per node.
        expect(allHits.length, greaterThanOrEqualTo(layouts.length));
        final seenNodes = <LocalId>[];
        for (final h in allHits) {
          if (!seenNodes.contains(h.node)) {
            seenNodes.add(h.node);
          }
        }
        expect(seenNodes, equals(expectedNodeOrder));
      },
    );
  });
}
