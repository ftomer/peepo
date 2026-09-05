import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/level.dart';
import 'package:peepo/models/scene.dart';

import 'scene_pump.dart';

/// What every shipped picture has to be true of, checked against the bundle
/// rather than against a fixture.
///
/// A baked level is an artefact of `tools/scene.sh bake`, and the ways it goes
/// wrong are quiet ones: a find that reads as sliced in half, a bar icon
/// carrying the corner of the crate it was cut beside, a picture that lost so
/// many finds to the reader that the level card promises more than the room
/// holds. None of those throws at runtime. They are simply the wrong game to
/// hand a child, so they are red here instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every picture the level ships, at every band, with no duplicates.
  Future<List<GameScene>> pictures(Level level) async {
    final seen = <String>{};
    final scenes = <GameScene>[];
    for (final band in AgeBand.values) {
      for (var seed = 0; seed < 16; seed++) {
        final asset = level.sceneAssetFor(band.profile, seed: seed);
        if (!seen.add(asset)) continue;
        scenes.add(
          GameScene.fromJsonString(
            await rootBundle.loadString(asset),
            dir: level.dir,
          ),
        );
      }
    }
    return scenes;
  }

  test('the bar shows one icon per kind, whichever picture is played', () async {
    // The icon is cut from the sprite sheet, not out of the picture: the bar
    // says what is being looked for, and this picture's copy of it is behind a
    // barrel with the barrel's shadow across it. So the same thing asked for
    // in two rooms - or twice in one - is asked for with the same picture.
    final catalog = await LevelCatalog.load();
    for (final level in catalog.levels) {
      final icons = <String, String>{};
      for (final scene in await pictures(level)) {
        for (final object in scene.objects) {
          expect(
            object.chip,
            '${level.dir}/baked/chip_${object.kind}.png',
            reason: '${level.id}: ${object.id} carries its own icon',
          );
          expect(
            icons.putIfAbsent(object.kind, () => object.chip),
            object.chip,
          );
        }
      }
      expect(icons, isNotEmpty, reason: level.id);
      for (final icon in icons.values) {
        expect(
          (await rootBundle.load(icon)).lengthInBytes,
          greaterThan(0),
          reason: '$icon is not in the bundle',
        );
      }
    }
  });

  test('every picture holds what the level card promises', () async {
    // The card is read before a picture is picked, so what it says has to be
    // true of the emptiest one in the pool. A bake that drops a find - drawn
    // off the edge of the frame, or so far behind the scenery there is nothing
    // left to see - moves this number, and a card left at the old one promises
    // a find the room cannot give.
    final catalog = await LevelCatalog.load();
    for (final level in catalog.levels) {
      for (final band in AgeBand.values) {
        final asked = level.objectCountFor(band.profile);
        for (var seed = 0; seed < 8; seed++) {
          final asset = level.sceneAssetFor(band.profile, seed: seed);
          final scene = GameScene.fromJsonString(
            await rootBundle.loadString(asset),
            dir: level.dir,
          );
          expect(
            scene.objects.length,
            greaterThanOrEqualTo(asked),
            reason:
                '$asset holds fewer finds than ${band.label} is asked '
                'for - re-run tools/scene.sh bake and check levels.json',
          );
        }
      }
    }
  });

  test('the level the widget tests play is the level the app ships', () async {
    // The fixture is a hand-written copy of one manifest entry, and every
    // widget test is played through it: left behind after a re-bake it hands
    // the tests a level with counts and a thumbnail the bundle does not have,
    // and they go on passing against a game nobody can open.
    final shipped = (await LevelCatalog.load()).byId(pirateLevel.id)!;
    expect(pirateLevel.name, shipped.name);
    expect(pirateLevel.objectCount, shipped.objectCount);
    expect(pirateLevel.maxObjects, shipped.maxObjects);
    expect(pirateLevel.scenes, shipped.scenes);
    expect(pirateLevel.thumbnail, shipped.thumbnail);
    for (final band in AgeBand.values) {
      expect(
        pirateLevel.sceneAssetFor(band.profile, seed: 3),
        shipped.sceneAssetFor(band.profile, seed: 3),
        reason: band.label,
      );
      expect(
        pirateLevel.objectCountFor(band.profile),
        shipped.objectCountFor(band.profile),
        reason: band.label,
      );
      expect(
        pirateLevel.thumbnailFor(band.profile),
        shipped.thumbnailFor(band.profile),
        reason: band.label,
      );
    }
  });
}
