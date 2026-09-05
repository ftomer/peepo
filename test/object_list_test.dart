import 'package:peepo/game/game_screen.dart';
import 'package:peepo/models/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scene_pump.dart';

/// Level folder the fixture scenes pretend to live in.
const _dir = 'assets/levels/test';

/// Two doubloons and one hook: the doubloons are one list entry, found
/// separately.
const _duplicateScene = '''
{
  "sceneId": "dupes_01",
  "name": "Dupes",
  "background": "background.jpg",
  "size": { "w": 100, "h": 100 },
  "objects": [
    {
      "id": "coin_a", "label": "Gold Doubloon", "sprite": "coin.png",
      "pos": [0.2, 0.2], "size": [0.1, 0.1], "rotation": 0,
      "polygon": [[0.15,0.15],[0.25,0.15],[0.25,0.25],[0.15,0.25]],
      "hintCenter": [0.2, 0.2]
    },
    {
      "id": "hook", "label": "Pirate Hook", "sprite": "hook.png",
      "pos": [0.5, 0.5], "size": [0.1, 0.1], "rotation": 0,
      "polygon": [[0.45,0.45],[0.55,0.45],[0.55,0.55],[0.45,0.55]],
      "hintCenter": [0.5, 0.5]
    },
    {
      "id": "coin_b", "label": "Gold Doubloon", "sprite": "coin.png",
      "pos": [0.8, 0.8], "size": [0.1, 0.1], "rotation": 0,
      "polygon": [[0.75,0.75],[0.85,0.75],[0.85,0.85],[0.75,0.85]],
      "hintCenter": [0.8, 0.8]
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('object grouping', () {
    final scene = GameScene.fromJsonString(_duplicateScene, dir: _dir);

    test('copies of one thing collapse into a single list entry', () {
      expect(scene.objects, hasLength(3));
      expect(scene.groups, hasLength(2));
      expect(scene.groups.map((g) => g.label), [
        'Gold Doubloon',
        'Pirate Hook',
      ]);
      expect(scene.groups.first.total, 2);
      expect(scene.groups.last.total, 1);
    });

    test('a group is complete only once every copy is found', () {
      final coins = scene.groups.first;
      expect(coins.foundCount({'coin_a'}), 1);
      expect(coins.isComplete({'coin_a'}), isFalse);
      expect(coins.isComplete({'coin_a', 'coin_b'}), isTrue);
    });

    test('each copy is hit-tested on its own', () {
      expect(scene.hitTest(const Offset(0.2, 0.2), {})?.id, 'coin_a');
      expect(scene.hitTest(const Offset(0.8, 0.8), {'coin_a'})?.id, 'coin_b');
      expect(scene.hitTest(const Offset(0.2, 0.2), {'coin_a'}), isNull);
    });

    test('an explicit kind groups things that carry different labels', () {
      const json = '''
      {
        "sceneId": "kinds", "name": "Kinds",
        "background": "b.jpg", "size": { "w": 100, "h": 100 },
        "objects": [
          {
            "id": "c1", "kind": "coin", "label": "Coin (left)",
            "sprite": "c.png", "pos": [0.2,0.2], "size": [0.1,0.1],
            "rotation": 0,
            "polygon": [[0.15,0.15],[0.25,0.15],[0.25,0.25],[0.15,0.25]],
            "hintCenter": [0.2,0.2]
          },
          {
            "id": "c2", "kind": "coin", "label": "Coin (right)",
            "sprite": "c.png", "pos": [0.8,0.8], "size": [0.1,0.1],
            "rotation": 0,
            "polygon": [[0.75,0.75],[0.85,0.75],[0.85,0.85],[0.75,0.85]],
            "hintCenter": [0.8,0.8]
          }
        ]
      }
      ''';
      final scene = GameScene.fromJsonString(json, dir: _dir);
      expect(scene.groups, hasLength(1));
      expect(scene.groups.single.total, 2);
    });
  });

  testWidgets('the object list fits the screen width without scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Whatever this game asks for: a baked level draws more finds than it
    // hands out and picks by seed, so the list is read off the scene rather
    // than named here. Loaded on the real event loop with everything else -
    // a bundle future started inside fake async never completes.
    late final List<String> labels;
    // Sprite decoding needs real async time before the scene appears.
    await tester.runAsync(() async {
      labels = [
        for (final group in (await pirateLevel.loadScene(seed: 7)).groups)
          group.label,
      ];
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(level: pirateLevel, seed: 7)),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
    });
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(SingleChildScrollView), findsNothing);
    for (final label in labels) {
      final box = tester.getRect(find.text(label));
      expect(box.left, greaterThanOrEqualTo(0.0), reason: label);
      expect(box.right, lessThanOrEqualTo(400.0), reason: label);
    }
    expect(tester.takeException(), isNull);
  });
}
