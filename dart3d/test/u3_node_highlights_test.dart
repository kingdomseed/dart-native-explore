import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_controller.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/scene_view.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

const first = LocalId(7, 1);
const second = LocalId(7, 2);

SceneDocument document() => SceneDocument()
  ..addNode(NodeSpec(id: first, name: 'first', children: [second]))
  ..addNode(NodeSpec(id: second, name: 'second'))
  ..roots.add(first);

class _MutationSink extends SceneViewElement {
  _MutationSink(SceneController controller)
    : super(SceneViewLeaf(controller: controller));

  final mutations = <({int tag, Uint8List data})>[];

  @override
  int? get viewId => null;

  @override
  void sendMutation(int tag, Uint8List data) {
    mutations.add((tag: tag, data: data));
  }

  List<Object?> get commands => [
    for (final mutation in mutations)
      if (mutation.tag == D3Protocol.command)
        jsonDecode(utf8.decode(mutation.data)),
  ];
}

void main() {
  late SceneController controller;

  setUp(() {
    controller = SceneController();
  });

  tearDown(() {
    controller.dispose();
  });

  test('one mutation atomically clears one node and sets another', () {
    final sink = _MutationSink(controller);
    controller.attachElement(sink);
    controller.setNodeHighlights({first: null, second: Vector4(1, 0.5, 0, 1)});

    expect(sink.mutations.map((m) => m.tag), [D3Protocol.command]);
    expect(sink.commands, [
      {
        'op': 'setNodeHighlights',
        'updates': [
          {'node': first.toToken(), 'color': null},
          {
            'node': second.toToken(),
            'color': [1.0, 0.5, 0.0, 1.0],
          },
        ],
      },
    ]);
  });

  test('two independent colors and alpha values travel in one patch', () {
    final sink = _MutationSink(controller);
    controller.attachElement(sink);
    controller.setNodeHighlights({
      first: Vector4(1, 0.25, 0, 0),
      second: Vector4(0, 0.5, 1, 0.5),
    });

    expect(sink.mutations, hasLength(1));
    expect(sink.commands, [
      {
        'op': 'setNodeHighlights',
        'updates': [
          {
            'node': first.toToken(),
            'color': [1.0, 0.25, 0.0, 0.0],
          },
          {
            'node': second.toToken(),
            'color': [0.0, 0.5, 1.0, 0.5],
          },
        ],
      },
    ]);
  });

  test('a later null clears only the named node on the wire', () {
    final sink = _MutationSink(controller);
    controller.attachElement(sink);
    controller.setNodeHighlights({
      first: Vector4.all(1),
      second: Vector4.all(1),
    });
    controller.setNodeHighlights({first: null});

    expect(sink.commands, hasLength(2));
    expect(sink.commands.last, {
      'op': 'setNodeHighlights',
      'updates': [
        {'node': first.toToken(), 'color': null},
      ],
    });
  });

  test('empty attached and queued batches emit nothing', () {
    controller.setNodeHighlights({});
    final sink = _MutationSink(controller);
    controller.attachElement(sink);
    controller.setNodeHighlights({});

    expect(sink.mutations, isEmpty);
  });

  test('queued colors copy mutable vectors and map entries before attach', () {
    final color = Vector4(0.25, 0.5, 0.75, 1);
    final updates = <LocalId, Vector4?>{first: color};
    controller.setNodeHighlights(updates);
    color.setValues(1, 0, 0, 0);
    updates.clear();
    final sink = _MutationSink(controller);
    controller.attachElement(sink);

    expect(sink.commands.single, {
      'op': 'setNodeHighlights',
      'updates': [
        {
          'node': first.toToken(),
          'color': [0.25, 0.5, 0.75, 1.0],
        },
      ],
    });
    expect(controller.document, isNull);
  });

  test(
    'initial explicit load then highlight flush in order without reload',
    () {
      controller.loadDocument(document());
      controller.setNodeHighlights({first: Vector4.all(1)});
      final sink = _MutationSink(controller);
      controller.attachElement(sink);

      expect(sink.mutations.map((m) => m.tag), [
        D3Protocol.loadScene,
        D3Protocol.command,
      ]);
    },
  );

  test('a later explicit load remains after the queued highlight', () {
    controller.setNodeHighlights({first: Vector4.all(1)});
    controller.loadDocument(document());
    final sink = _MutationSink(controller);
    controller.attachElement(sink);

    expect(sink.mutations.map((m) => m.tag), [
      D3Protocol.command,
      D3Protocol.loadScene,
    ]);
  });

  test('command-built scenes flush highlights before the implicit load', () {
    controller.applyCommands([
      {
        'op': 'addNode',
        'node': first.toToken(),
        'spec': encodeNodeCommandSpec(NodeSpec(id: first), document()),
      },
    ]);
    controller.setNodeHighlights({first: Vector4.all(1)});
    final sink = _MutationSink(controller);
    controller.attachElement(sink);

    expect(sink.mutations.map((m) => m.tag), [
      D3Protocol.command,
      D3Protocol.command,
      D3Protocol.loadScene,
    ]);
    expect((sink.commands.last as Map)['op'], 'setNodeHighlights');
  });

  test('recreated views receive authored content without highlight replay', () {
    controller.loadDocument(document());
    final oldSink = _MutationSink(controller);
    controller.attachElement(oldSink);
    controller.setNodeHighlights({first: Vector4.all(1)});
    controller.detachElement(oldSink);
    final newSink = _MutationSink(controller);
    controller.attachElement(newSink);

    expect(oldSink.commands, hasLength(1));
    expect(newSink.mutations.map((m) => m.tag), [D3Protocol.loadScene]);
  });

  test('detached highlights precede the implicit reconstruction load', () {
    controller.loadDocument(document());
    final oldSink = _MutationSink(controller);
    controller.attachElement(oldSink);
    controller.detachElement(oldSink);
    controller.setNodeHighlights({first: Vector4.all(1)});
    final newSink = _MutationSink(controller);
    controller.attachElement(newSink);

    expect(newSink.mutations.map((m) => m.tag), [
      D3Protocol.command,
      D3Protocol.loadScene,
    ]);
    expect(oldSink.commands, isEmpty);
  });

  test('highlight set and clear leave authored serialization unchanged', () {
    final doc = document();
    final before = writeFsceneWithExtensions(doc);
    controller.loadDocument(doc);
    controller.setNodeHighlights({first: Vector4.all(1)});
    controller.setNodeHighlights({first: null});

    expect(controller.document, same(doc));
    expect(writeFsceneWithExtensions(controller.serializeScene()!), before);
  });

  test(
    'the existing JSON encoder rejects non-finite components before send',
    () {
      final sink = _MutationSink(controller);
      controller.attachElement(sink);

      expect(
        () =>
            controller.setNodeHighlights({first: Vector4(double.nan, 0, 0, 1)}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(sink.mutations, isEmpty);
    },
  );

  test('dispose sends no clear to an attached view', () {
    controller.loadDocument(document());
    final sink = _MutationSink(controller);
    controller.attachElement(sink);
    controller.setNodeHighlights({first: Vector4.all(1)});
    final count = sink.mutations.length;
    controller.dispose();

    expect(sink.mutations, hasLength(count));
    expect(controller.isAttached, isFalse);
    expect(controller.document, isNull);
  });
}
