import 'package:peepo/models/scene.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scene_pump.dart';

/// Level folder the fixture scenes pretend to live in.
const _dir = 'assets/levels/test';

const _sceneJson = '''
{
  "sceneId": "test_01",
  "name": "Test Scene",
  "background": "background.jpg",
  "size": { "w": 1600, "h": 1000 },
  "objects": [
    {
      "id": "teapot",
      "label": "Teapot",
      "sprite": "sprites/teapot.png",
      "pos": [0.2, 0.5],
      "size": [0.1, 0.12],
      "rotation": 0,
      "polygon": [[0.15, 0.44], [0.25, 0.44], [0.25, 0.56], [0.15, 0.56]],
      "hintCenter": [0.2, 0.5]
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameScene', () {
    final scene = GameScene.fromJsonString(_sceneJson, dir: _dir);

    test('parses scene metadata and objects', () {
      expect(scene.id, 'test_01');
      expect(scene.name, 'Test Scene');
      expect(scene.background, '$_dir/background.jpg');
      expect(scene.size, const Size(1600, 1000));
      expect(scene.objects, hasLength(1));
      final teapot = scene.objects.first;
      expect(teapot.sprite, '$_dir/sprites/teapot.png');
      expect(teapot.size, const Size(0.1, 0.12));
      expect(teapot.rotation, 0);
      expect(teapot.polygon, hasLength(4));
    });

    test('hitTest returns object for tap inside polygon', () {
      final hit = scene.hitTest(const Offset(0.2, 0.5), {});
      expect(hit?.id, 'teapot');
    });

    test('hitTest returns null for tap outside polygon', () {
      expect(scene.hitTest(const Offset(0.5, 0.5), {}), isNull);
      expect(scene.hitTest(const Offset(0.14, 0.5), {}), isNull);
    });

    test('hitTest ignores already-found objects', () {
      expect(scene.hitTest(const Offset(0.2, 0.5), {'teapot'}), isNull);
    });

    test('a tap tolerance counts a near miss, and only a near one', () {
      // The teapot's outline runs from 0.15 to 0.25 across. The scene is 1.6
      // times as wide as it is tall, so a margin measured across the picture
      // reaches further up and down it than it does sideways.
      const justOutside = Offset(0.26, 0.5);
      expect(
        scene.hitTest(justOutside, {}),
        isNull,
        reason: 'the oldest band is given no tolerance at all',
      );
      expect(scene.hitTest(justOutside, {}, padding: 0.02)?.id, 'teapot');
      // Across the room is still across the room.
      expect(scene.hitTest(const Offset(0.6, 0.5), {}, padding: 0.03), isNull);
    });

    test('the part of a prop the scenery covers cannot be tapped', () {
      // The teapot's outline runs 0.15 to 0.25 across; the hedge in front of
      // it leaves the left half showing. What a player cannot see, a player
      // cannot have meant, so the covered half is not the teapot any more -
      // and the tolerance around it goes with it.
      final covered = GameScene.fromJsonString(
        _sceneJson.replaceFirst(
          '"hintCenter": [0.2, 0.5]',
          '"hintCenter": [0.175, 0.5], "clip": [0.15, 0.44, 0.2, 0.56]',
        ),
        dir: _dir,
      );
      expect(
        covered.hitTest(const Offset(0.17, 0.5), {})?.id,
        'teapot',
        reason: 'the half still on show is still the teapot',
      );
      expect(
        covered.hitTest(const Offset(0.23, 0.5), {}),
        isNull,
        reason: 'the half behind the hedge is not',
      );
      expect(
        covered.hitTest(const Offset(0.23, 0.5), {}, padding: 0.02),
        isNull,
        reason: 'and tolerance does not reach into it either',
      );
    });

    test('a decoy is in the picture, on no list and never a find', () {
      final withDecoy = GameScene.fromJsonString(
        _sceneJson.replaceFirst(
          '"hintCenter": [0.2, 0.5]',
          '"hintCenter": [0.2, 0.5], "findable": false',
        ),
        dir: _dir,
      );
      // Drawn like anything else...
      expect(withDecoy.objects, hasLength(1));
      // ...and nowhere in the object list, so nothing asks for it.
      expect(withDecoy.groups, isEmpty);
      // A tap on it is a miss, which is what makes it worth putting there.
      expect(withDecoy.hitTest(const Offset(0.2, 0.5), {}), isNull);
      expect(
        withDecoy.hitTest(const Offset(0.2, 0.5), {}, padding: 0.05),
        isNull,
      );
    });

    test('tolerance never resurrects something already found', () {
      expect(
        scene.hitTest(const Offset(0.26, 0.5), {'teapot'}, padding: 0.05),
        isNull,
      );
    });

    test('distance is zero inside the outline and grows outside it', () {
      final teapot = scene.objects.first;
      const heightOverWidth = 1000 / 1600;
      expect(teapot.distanceTo(const Offset(0.2, 0.5), heightOverWidth), 0);
      expect(
        teapot.distanceTo(const Offset(0.27, 0.5), heightOverWidth),
        closeTo(0.02, 1e-9),
      );
      // Measured in scene-width units, so a step down the picture is the
      // shorter step: the same 0.02 of the way down is 0.0125 across.
      expect(
        teapot.distanceTo(const Offset(0.2, 0.58), heightOverWidth),
        closeTo(0.0125, 1e-9),
      );
    });

    test('hitTest prefers the object drawn last', () {
      const overlapping = '''
      {
        "sceneId": "overlap",
        "name": "Overlap",
        "background": "background.jpg",
        "size": { "w": 100, "h": 100 },
        "objects": [
          {
            "id": "under", "label": "Under",
            "sprite": "a.png", "pos": [0.5, 0.5], "size": [0.4, 0.4],
            "rotation": 0,
            "polygon": [[0.3, 0.3], [0.7, 0.3], [0.7, 0.7], [0.3, 0.7]],
            "hintCenter": [0.5, 0.5]
          },
          {
            "id": "over", "label": "Over",
            "sprite": "b.png", "pos": [0.5, 0.5], "size": [0.2, 0.2],
            "rotation": 0,
            "polygon": [[0.4, 0.4], [0.6, 0.4], [0.6, 0.6], [0.4, 0.6]],
            "hintCenter": [0.5, 0.5]
          }
        ]
      }
      ''';
      final scene = GameScene.fromJsonString(overlapping, dir: _dir);
      expect(scene.hitTest(const Offset(0.5, 0.5), {})?.id, 'over');
      expect(scene.hitTest(const Offset(0.35, 0.5), {})?.id, 'under');
    });

    test('polygon containment is stable near boundaries', () {
      expect(scene.objects.first.contains(const Offset(0.151, 0.45)), isTrue);
      expect(scene.objects.first.contains(const Offset(0.26, 0.5)), isFalse);
    });
  });

  group('the pirate_cabin level folder', () {
    late GameScene scene;

    setUpAll(() async {
      scene = await pirateLevel.loadScene();
    });

    test('loads every findable object', () {
      // The finds, not the room: a baked picture holds more than one game
      // asks for, and the rest ride along as decoys.
      expect(scene.finds, hasLength(pirateLevel.objectCount));
      expect(scene.background, startsWith('${pirateLevel.dir}/background'));
    });

    test('art resolves inside the level folder', () {
      for (final object in scene.objects) {
        expect(
          object.sprite,
          startsWith('${pirateLevel.dir}/'),
          reason: object.id,
        );
      }
    });

    test('every object polygon contains pos and hintCenter', () {
      for (final object in scene.objects) {
        expect(
          object.contains(object.pos),
          isTrue,
          reason: '${object.id} pos must be inside its polygon',
        );
        expect(
          object.contains(object.hintCenter),
          isTrue,
          reason: '${object.id} hintCenter must be inside its polygon',
        );
      }
    });

    test('every object stays inside the scene bounds', () {
      for (final object in scene.objects) {
        for (final point in object.polygon) {
          expect(point.dx, inInclusiveRange(0, 1), reason: object.id);
          expect(point.dy, inInclusiveRange(0, 1), reason: object.id);
        }
      }
    });

    test('object sprites are bundled assets', () async {
      for (final object in scene.objects) {
        final data = await rootBundle.load(object.sprite);
        expect(data.lengthInBytes, greaterThan(0), reason: object.sprite);
      }
    });

    test('no two objects overlap', () {
      for (final a in scene.objects) {
        for (final b in scene.objects) {
          if (identical(a, b)) continue;
          expect(
            b.contains(a.pos),
            isFalse,
            reason: '${a.id} centre falls inside ${b.id}',
          );
        }
      }
    });
  });
}
