// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/dart3d.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:dart3d_example/u3_outline_views_scene.dart';
import 'package:test/test.dart';

class _Sink extends SceneViewElement {
  _Sink(SceneController controller)
    : super(SceneViewLeaf(controller: controller));
  final mutations = <({int tag, Uint8List data})>[];
  @override
  int? get viewId => null;
  @override
  void sendMutation(int tag, Uint8List data) =>
      mutations.add((tag: tag, data: data));
  List<dynamic> get commands => [
    for (final mutation in mutations)
      if (mutation.tag == D3Protocol.command)
        jsonDecode(utf8.decode(mutation.data)),
  ];
}

void main() {
  test(
    'real public color batches and separate null clears never request a target render',
    () {
      final controller = SceneController()
        ..loadDocument(buildU3OutlineViewsDocument());
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      setU3OutlineColors(controller);
      clearU3OutlineColors(controller);
      expect(sink.mutations.map((m) => m.tag), [
        D3Protocol.command,
        D3Protocol.command,
      ]);
      expect(sink.commands, [
        {
          'op': 'setNodeHighlights',
          'updates': [
            {
              'node': u3OutlineMesh.toToken(),
              'color': [1.0, 0.25, 0.0625, 0.0],
            },
            {
              'node': u3OutlineBatch.toToken(),
              'color': [0.0625, 0.5, 1.0, 0.5],
            },
          ],
        },
        {
          'op': 'setNodeHighlights',
          'updates': [
            {'node': u3OutlineMesh.toToken(), 'color': null},
            {'node': u3OutlineBatch.toToken(), 'color': null},
          ],
        },
      ]);
      final target = controller.document!.resources.values
          .whereType<RenderTextureResource>()
          .single;
      controller.renderTexture(target.id);
      expect(sink.commands.last, {
        'op': 'render',
        'target': 'rt:${target.id.toToken()}',
      });
      expect(controller.serializeScene()!.nodes[u3OutlineMesh]!.children, [
        u3OutlineChild,
      ]);
    },
  );

  test(
    'fixture modes and camera toggle use real transforms; view rebind sends no render',
    () {
      final doc = buildU3OutlineViewsDocument();
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      setU3OutlineMode(controller, U3OutlineMode.control, cameraB: true);
      setU3OutlineCameraPose(controller, alternate: true);
      expect(sink.mutations.map((m) => m.tag), [
        D3Protocol.setTransforms,
        D3Protocol.setTransforms,
      ]);
      final marker = ByteData.sublistView(sink.mutations.first.data);
      expect(marker.getUint32(0, Endian.little), 1);
      expect(marker.getUint32(4, Endian.little), u3OutlineControl.session);
      expect(marker.getUint32(8, Endian.little), u3OutlineControl.index);
      expect(marker.getUint8(12), 1);
      expect(
        [
          for (var i = 0; i < 3; i++)
            marker.getFloat32(13 + i * 4, Endian.little),
        ],
        [1, 1, 0],
      );
      final before = controller.serializeScene()!;
      expect(
        (before.nodes[u3OutlineCameraB]!.transform as TrsTransform)
            .translation
            .x,
        closeTo(2.2, 0.00001),
      );
      expect(
        (before.nodes[u3OutlineCameraA]!.transform as TrsTransform)
            .translation
            .x,
        0,
      );
      setU3OutlineCameraPose(controller, alternate: true, single: true);
      expect(
        (controller.serializeScene()!.nodes[u3OutlineCameraA]!.transform
                as TrsTransform)
            .translation
            .x,
        closeTo(2.2, 0.00001),
      );
      controller.updateViews(doc.views);
      expect(sink.commands.single['op'], 'updateViews');
      expect(sink.commands.single['views'], hasLength(3));
      expect(
        controller.serializeScene()!.resources.keys,
        before.resources.keys,
      );
      expect(
        controller
            .serializeScene()!
            .views
            .singleWhere((v) => v.target != null)
            .target,
        before.views.singleWhere((v) => v.target != null).target,
      );
    },
  );

  for (final (publishInUpdate, bindBeforeInstall) in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    test(
      'publication=$publishInUpdate bindBeforeInstall=$bindBeforeInstall survive public mode/camera writes without requesting a draw',
      () {
        final doc = buildU3OutlineViewsDocument(
          publishInUpdate: publishInUpdate,
          bindBeforeInstall: bindBeforeInstall,
        );
        final controller = SceneController()..loadDocument(doc);
        addTearDown(controller.dispose);
        final sink = _Sink(controller);
        controller.attachElement(sink);
        final loaded =
            jsonDecode(
                  utf8.decode(
                    sink.mutations
                        .firstWhere((m) => m.tag == D3Protocol.loadScene)
                        .data,
                  ),
                )
                as Map;
        final baseline = SceneController()
          ..loadDocument(buildU3OutlineViewsDocument());
        addTearDown(baseline.dispose);
        final baselineSink = _Sink(baseline);
        baseline.attachElement(baselineSink);
        final original =
            jsonDecode(
                  utf8.decode(
                    baselineSink.mutations
                        .firstWhere((m) => m.tag == D3Protocol.loadScene)
                        .data,
                  ),
                )
                as Map;
        final marker = (loaded['nodes'] as Map).values.cast<Map>().singleWhere(
          (n) => n['name'] == u3OutlineMarker,
        );
        final originalMarker = (original['nodes'] as Map).values
            .cast<Map>()
            .singleWhere((n) => n['name'] == u3OutlineMarker);
        expect(((marker['transform'] as Map)['trs'] as Map)['t'], [
          0,
          0,
          publishInUpdate ? 1 : 0,
        ]);
        expect(
          (controller.document!.nodes[u3OutlineControl]!.transform
                  as TrsTransform)
              .scale
              .x,
          bindBeforeInstall ? 2 : 1,
        );
        marker['transform'] = originalMarker['transform'];
        loaded['documentId'] = original['documentId'];
        expect(loaded, original);
        sink.mutations.clear();
        for (final mode in U3OutlineMode.values) {
          setU3OutlineMode(
            controller,
            mode,
            cameraB: true,
            publishInUpdate: publishInUpdate,
            bindBeforeInstall: bindBeforeInstall,
          );
        }
        expect(sink.mutations, hasLength(3));
        for (var i = 0; i < sink.mutations.length; i++) {
          final mutation = sink.mutations[i];
          expect(mutation.tag, D3Protocol.setTransforms);
          final data = ByteData.sublistView(mutation.data);
          expect(data.getUint8(12), bindBeforeInstall ? 5 : 1);
          expect(
            [
              for (var c = 0; c < 3; c++)
                data.getFloat32(13 + c * 4, Endian.little),
            ],
            [i.toDouble(), 1, publishInUpdate ? 1 : 0],
          );
          if (bindBeforeInstall) {
            expect(
              [
                for (var c = 0; c < 3; c++)
                  data.getFloat32(25 + c * 4, Endian.little),
              ],
              [2, 1, 1],
            );
          }
        }
        expect(sink.commands, isEmpty);
        setU3OutlineColors(controller);
        final target = doc.resources.values
            .whereType<RenderTextureResource>()
            .single;
        controller.renderTexture(target.id);
        clearU3OutlineColors(controller);
        controller.renderTexture(target.id);
        expect(sink.commands.map((c) => c['op']), [
          'setNodeHighlights',
          'render',
          'setNodeHighlights',
          'render',
        ]);
      },
    );
  }

  for (final single in [false, true]) {
    for (final msaa in [false, true]) {
      test(
        'serialized ${single ? "host" : "split"} fixture retains cameras/layers/manual target AA=$msaa',
        () {
          final doc = buildU3OutlineViewsDocument(
            single: single,
            targetMsaa: msaa,
          );
          final controller = SceneController()..loadDocument(doc);
          addTearDown(controller.dispose);
          final sink = _Sink(controller);
          controller.attachElement(sink);
          final wire =
              jsonDecode(
                    utf8.decode(
                      sink.mutations
                          .firstWhere((m) => m.tag == D3Protocol.loadScene)
                          .data,
                    ),
                  )
                  as Map;
          final restored = readFsceneWithExtensions(
            writeFsceneWithExtensions(controller.serializeScene()!),
          );
          final target = restored.resources.values
              .whereType<RenderTextureResource>()
              .single;
          expect(
            [target.width, target.height, target.update],
            [96, 72, 'manual'],
          );
          final targetView = restored.views.singleWhere(
            (v) => v.target != null,
          );
          expect(
            [
              targetView.cameraNode,
              targetView.layerMask,
              targetView.antiAliasingMode,
            ],
            [u3OutlineCameraTarget, 3, msaa ? 'msaa' : 'none'],
          );
          final screens = restored.views
              .where((v) => v.target == null)
              .toList();
          expect(screens, hasLength(single ? 1 : 2));
          expect(screens.first.cameraNode, u3OutlineCameraA);
          expect(
            (screens.first as Dart3dRenderViewSpec).viewport,
            single ? isNull : [0.0, 0.0, 570.0, 570.0],
          );
          if (!single) {
            expect(
              [screens[1].cameraNode, screens[1].layerMask],
              [u3OutlineCameraB, 1],
            );
            expect((screens[1] as Dart3dRenderViewSpec).viewport, [
              590.0,
              140.0,
              380.0,
              430.0,
            ]);
          }
          expect(wire['views'], hasLength(single ? 2 : 3));
          final mesh = restored.nodes[u3OutlineMesh]!;
          final primitives =
              (mesh.components.single.properties['primitives']! as ListValue)
                  .values;
          expect(primitives, hasLength(2));
          for (final primitive in primitives.cast<MapValue>()) {
            final id = (primitive.values['geometry']! as ResourceRefValue).id;
            final geometry = restored.resources[id]! as GeometryResource;
            final vertices = controller
                .serializeScene()!
                .payloads[geometry.vertices]!
                .bytes!;
            final indices = controller
                .serializeScene()!
                .payloads[geometry.indices]!
                .bytes!;
            expect(vertices.length, VertexPack.unskinnedUv1TangentStride * 3);
            expect(indices, [0, 0, 2, 0, 1, 0]);
          }
          expect(mesh.children, [u3OutlineChild]);
          expect(
            restored.nodes[u3OutlineChild]!.components.single.type,
            'd3:procMesh',
          );
          final batch = restored.nodes[u3OutlineBatch]!;
          expect(batch.layers, 2);
          expect(batch.components.single.type, 'd3:instances');
          expect(
            (batch.components.single.properties['transforms']! as ListValue)
                .values,
            hasLength(3),
          );
        },
      );
    }
  }

  test(
    'public native animation carries changing asymmetric mesh pose and play/pause commands',
    () {
      final doc = buildU3OutlineViewsDocument();
      final controller = SceneController()..loadDocument(doc);
      addTearDown(controller.dispose);
      final sink = _Sink(controller);
      controller.attachElement(sink);
      sink.mutations.clear();
      final clip = controller.serializeScene()!.animations.values.single;
      final channel = clip.channels.single;
      expect(channel.target, u3OutlineMesh);
      expect(channel.property, AnimationProperty.translation);
      final bytes = controller
          .serializeScene()!
          .payloads[channel.keyframes]!
          .bytes!;
      final data = ByteData.sublistView(bytes);
      expect(
        [for (var i = 0; i < 9; i++) data.getFloat32(i * 4, Endian.little)],
        orderedEquals(
          [
            -0.85,
            0.2,
            0,
            -0.35,
            0.7,
            0.3,
            -0.85,
            0.2,
            0,
          ].map((v) => closeTo(v, 0.00001)),
        ),
      );
      controller.playAnimation(clip.id, weight: 1, loop: true);
      controller.pauseAnimation(clip.id);
      expect(sink.commands, [
        {
          'op': 'anim',
          'anim': clip.id.toToken(),
          'play': true,
          'weight': 1.0,
          'loop': true,
        },
        {'op': 'anim', 'anim': clip.id.toToken(), 'pause': true},
      ]);
    },
  );
}
