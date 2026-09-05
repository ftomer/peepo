import 'dart:convert';

import 'package:peepo/game/placement.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/level.dart';
import 'package:peepo/models/prop_catalog.dart';
import 'package:peepo/models/scene.dart';
import 'package:peepo/models/scene_meta.dart';
import 'package:peepo/models/level_progress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _manifest = '''
{
  "levels": [
    { "id": "one", "name": "One", "theme": "pirate", "objectCount": 12,
      "maxObjects": 18,
      "variants": { "dense": { "objectCount": 12, "maxObjects": 12 } } },
    { "id": "two", "name": "Two", "objectCount": 8 }
  ]
}
''';

/// A manifest from before variants carried their own counts, which is a bare
/// list of names. Such a variant is read as hiding what its level does.
const _oldManifest = '''
{
  "levels": [
    { "id": "one", "name": "One", "objectCount": 12, "maxObjects": 18,
      "variants": ["dense"] }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LevelCatalog', () {
    final catalog = LevelCatalog.fromJsonString(_manifest);

    test('reads the levels in play order', () {
      expect(catalog.levels.map((l) => l.id), ['one', 'two']);
      expect(catalog.first.name, 'One');
      expect(catalog.first.theme, 'pirate');
      expect(catalog.levels.last.theme, isNull);
    });

    test('derives every path from the level folder', () {
      final level = catalog.first;
      expect(level.dir, 'assets/levels/one');
      expect(level.sceneAsset, 'assets/levels/one/scene.json');
      expect(level.thumbnail, 'assets/levels/one/background.jpg');
    });

    test('the older bands play the denser backdrop where there is one', () {
      // A scene calm enough for a three year old is one an eleven year old
      // clears at a glance, however small the placer draws it, so a level may
      // ship a second backdrop for the older two bands.
      final withVariant = catalog.first;
      for (final band in [AgeBand.peek, AgeBand.look]) {
        expect(
          withVariant.sceneAssetFor(band.profile),
          'assets/levels/one/scene.json',
          reason: band.label,
        );
        expect(
          withVariant.thumbnailFor(band.profile),
          'assets/levels/one/background.jpg',
          reason: band.label,
        );
      }
      for (final band in [AgeBand.seek, AgeBand.hunt]) {
        expect(
          withVariant.sceneAssetFor(band.profile),
          'assets/levels/one/scene.dense.json',
          reason: band.label,
        );
        expect(
          withVariant.thumbnailFor(band.profile),
          'assets/levels/one/background_dense.jpg',
          reason: band.label,
        );
      }
    });

    test(
      'a variant is counted by what it hides, not by what its level does',
      () {
        // The variant is a busier room over the same find list, and its regions
        // hold a different number of copies of it. A card promising the base
        // scene's eighteen in front of a variant that can only hold twelve is
        // the same lie as a card promising fourteen at Peek.
        final level = catalog.first;
        expect(level.countsFor(AgeBand.look.profile).maxObjects, 18);
        expect(level.countsFor(AgeBand.hunt.profile).maxObjects, 12);
        expect(level.objectCountFor(AgeBand.hunt.profile), 12);
        expect(
          level.objectCountFor(AgeBand.hunt.profile),
          lessThan(
            AgeBand.hunt.profile.objectCount(
              level.objectCount,
              capacity: level.maxObjects,
            ),
          ),
          reason: 'the base scene would have promised more',
        );
      },
    );

    test('a manifest that lists variants by name alone still reads', () {
      final level = LevelCatalog.fromJsonString(_oldManifest).first;
      expect(
        level.sceneAssetFor(AgeBand.hunt.profile),
        'assets/levels/one/scene.dense.json',
      );
      expect(level.countsFor(AgeBand.hunt.profile).maxObjects, 18);
    });

    test('a level with no variant is played as authored by every band', () {
      // Which is what all four shipped levels do today, and what some always
      // will: a missing variant is not an error, it is the normal case.
      final plain = catalog.levels.last;
      for (final band in AgeBand.values) {
        expect(
          plain.sceneAssetFor(band.profile),
          'assets/levels/two/scene.json',
          reason: band.label,
        );
        expect(
          plain.thumbnailFor(band.profile),
          'assets/levels/two/background.jpg',
          reason: band.label,
        );
      }
      expect(plain.sceneAssetFor(null), 'assets/levels/two/scene.json');
    });

    test('after() walks the list and stops at the end', () {
      expect(catalog.after(catalog.first)?.id, 'two');
      expect(catalog.after(catalog.levels.last), isNull);
    });

    test('byId finds a level, or nothing', () {
      expect(catalog.byId('two')?.name, 'Two');
      expect(catalog.byId('nope'), isNull);
    });
  });

  group('the shipped catalog', () {
    late LevelCatalog catalog;

    setUpAll(() async {
      catalog = await LevelCatalog.load();
    });

    test('lists at least one level', () {
      expect(catalog.isEmpty, isFalse);
    });

    test('every level folder holds the assets the manifest promises', () async {
      for (final level in catalog.levels) {
        final scene = await level.loadScene();
        expect(scene.name, level.name, reason: level.id);
        // What the card promises is what the level asks for. A baked scene
        // holds more than that - the rest are decoys drawn into the same
        // picture - so it is the find list that is counted, not the room.
        expect(
          scene.finds,
          hasLength(level.objectCount),
          reason: '${level.id}: manifest objectCount is out of date',
        );
        final thumbnail = await rootBundle.load(level.thumbnail);
        expect(thumbnail.lengthInBytes, greaterThan(0), reason: level.id);
      }
    });

    // The gaps a surface has left are measured off the backdrop by
    // `tools/scene.sh fit --spans`, and the placer puts a prop's middle inside
    // one of them. A span outside its own region, or too narrow for anything
    // to stand in, is a span that sends the prop somewhere the reading never
    // looked - which is exactly the mid-air find the measuring is there to
    // stop.
    test('every gap a surface offers is inside the surface', () async {
      for (final level in catalog.levels) {
        // The metas a level actually ships are the ones its scenes name: a
        // baked variant names none, because a picture that already holds its
        // finds has nowhere left to place anything.
        final assets = <String>{};
        for (final band in [null, ...AgeBand.values]) {
          final scene = level.sceneAssetFor(band?.profile);
          final json =
              jsonDecode(await rootBundle.loadString(scene))
                  as Map<String, dynamic>;
          if (!PropCatalog.isCatalog(json)) continue;
          assets.add('${level.dir}/${PropCatalog.fromJson(json).metaFile}');
        }
        for (final asset in assets) {
          final meta = SceneMeta.fromJsonString(
            await rootBundle.loadString(asset),
          );
          for (final region in meta.regions) {
            for (final span in region.freeSpans) {
              final where = '$asset ${region.id}';
              expect(span, hasLength(2), reason: where);
              expect(
                span.last - span.first,
                greaterThan(0.01),
                reason: '$where offers a gap nothing fits in',
              );
              expect(
                span.first,
                greaterThanOrEqualTo(region.rect.x0 - 0.001),
                reason: '$where offers a gap outside its own box',
              );
              expect(
                span.last,
                lessThanOrEqualTo(region.rect.x1 + 0.001),
                reason: '$where offers a gap outside its own box',
              );
            }
            if (region.freeSpans.isNotEmpty) {
              expect(
                region.restLine,
                isNotEmpty,
                reason:
                    '$asset ${region.id} has gaps but nothing to '
                    'stand on',
              );
            }
          }
        }
      }
    });

    // A prop with nowhere legal to go costs the player an object, and it shows
    // up on one seed in a dozen rather than on the one the author looked at.
    test('a level that ships a variant ships all of it, and hides the same '
        'things', () async {
      // The older bands play a second backdrop where a level has one. It is a
      // different room over the same sprites and the same find list: a variant
      // that quietly hid something else would make the level card, the music
      // and the object count belong to a level nobody is playing.
      for (final level in catalog.levels) {
        for (final entry in level.variants.entries) {
          final variant = entry.key;
          // What the level hides, read off whatever shape its own scenes
          // take: a catalog lists its props, a baked pool draws them.
          final base = <String>{};
          for (var take = 1; take <= level.scenes; take++) {
            final asset = level.scenes == 1
                ? level.sceneAsset
                : '${level.dir}/scene.$take.json';
            final json =
                jsonDecode(await rootBundle.loadString(asset))
                    as Map<String, dynamic>;
            base.addAll(
              PropCatalog.isCatalog(json)
                  ? PropCatalog.fromJson(json).props.map((p) => p.id)
                  : GameScene.fromJson(
                      json,
                      dir: level.dir,
                    ).finds.map((o) => o.kind),
            );
          }
          // The first of the variant's pictures, which is the only one a
          // variant that ships one picture has.
          final scene = entry.value.scenes == 1
              ? '${level.dir}/scene.$variant.json'
              : '${level.dir}/scene.$variant.1.json';
          final source = await rootBundle.loadString(scene);
          final where = '${level.id}/$variant';

          // A baked variant is a picture with the finds drawn into it, so it
          // ships objects where a composited one ships props to place - and
          // several pictures where it ships a pool, one per playthrough. Each
          // of them still has to hide the level's own things, and only those.
          if (!PropCatalog.isCatalog(
            jsonDecode(source) as Map<String, dynamic>,
          )) {
            final kinds = base;
            for (var take = 1; take <= entry.value.scenes; take++) {
              final asset = entry.value.scenes == 1
                  ? scene
                  : '${level.dir}/scene.$variant.$take.json';
              final baked = GameScene.fromJsonString(
                await rootBundle.loadString(asset),
                dir: level.dir,
              );
              final where = asset;
              // Every find in the picture is one of the level's own, and the
              // picture is free to hold several of some and none of another:
              // what a playthrough asks for is a subset of what is drawn, and
              // the level card promises a count rather than a cast list.
              expect(
                baked.finds.map((o) => o.kind).toSet(),
                everyElement(isIn(kinds)),
                reason: '$where hides something the level does not',
              );
              expect(baked.name, level.name, reason: where);
              // The card promises a count before it knows which picture the
              // player will be handed, so every picture in the pool has to be
              // able to keep that promise.
              expect(
                baked.finds.length,
                greaterThanOrEqualTo(entry.value.maxObjects),
                reason:
                    '$where holds fewer finds than the level list '
                    'promises',
              );
              await rootBundle.load(baked.background);
              for (final object in baked.objects) {
                expect(
                  object.polygon.length,
                  greaterThan(2),
                  reason: '$where ${object.id} has no tap target',
                );
                // The stamp that puts this find back on the plate, and the
                // small copy of it the object list shows.
                await rootBundle.load(object.sprite);
                await rootBundle.load(object.chip);
                expect(
                  object.chip,
                  isNot(object.sprite),
                  reason: '$where ${object.id} loads its artwork twice',
                );
              }
            }
            await rootBundle.load(level.thumbnailFor(AgeBand.seek.profile));
            continue;
          }

          final props = PropCatalog.fromJsonString(source);

          expect(
            props.props.map((p) => p.id).toSet(),
            base,
            reason: '$where hides different things from the level it varies',
          );
          expect(
            props.objectCount,
            level.objectCount,
            reason: '$where promises a different number from its level',
          );
          expect(props.metaFile, isNot('meta.json'), reason: where);

          // The card reads these off the manifest before any scene is opened,
          // and the room the player is handed is this one.
          expect(
            entry.value.objectCount,
            props.objectCount,
            reason: '$where: manifest objectCount is out of date',
          );
          expect(
            entry.value.maxObjects,
            props.capacity,
            reason: '$where: manifest maxObjects is out of date',
          );

          // A variant is the same level under a different backdrop, and the
          // level card is what the player tapped to get here.
          expect(
            props.name,
            level.name,
            reason: '$where is titled differently from its own level',
          );

          // Its backdrop and room description have to be in the bundle, or the
          // level loads for the younger bands and fails for the older ones.
          await rootBundle.load('${level.dir}/${props.background}');
          await rootBundle.loadString('${level.dir}/${props.metaFile}');

          // A decoy that shares a find's id is a second unicorn on a backdrop
          // that asks for one unicorn.
          final asked = {for (final prop in props.props) prop.id};
          for (final decoy in props.decoys) {
            expect(asked, isNot(contains(decoy.id)), reason: where);
            await rootBundle.load('${level.dir}/${decoy.sprite}');
          }
        }
      }
    });

    test('every level hides all of its objects, whatever the seed', () async {
      for (final level in catalog.levels) {
        for (final band in AgeBand.values) {
          final source = await rootBundle.loadString(
            level.sceneAssetFor(band.profile, seed: 0),
          );
          // A baked scene places nothing: the picture already holds every
          // find, and what changes per playthrough is which picture and which
          // of its finds are asked for. Both are checked against the count the
          // level list promises.
          if (!PropCatalog.isCatalog(
            jsonDecode(source) as Map<String, dynamic>,
          )) {
            final want = level.objectCountFor(band.profile);
            for (var seed = 0; seed < 20; seed++) {
              final scene = await level.loadScene(
                seed: seed,
                profile: band.profile,
              );
              expect(
                scene.finds,
                hasLength(want),
                reason:
                    '${level.id} at ${band.label}: seed $seed asked for '
                    '${scene.finds.length} of $want',
              );
            }
            continue;
          }
          final props = PropCatalog.fromJsonString(source);
          final meta = SceneMeta.fromJsonString(
            await rootBundle.loadString('${level.dir}/${props.metaFile}'),
          );
          final want = band.profile.objectCount(
            props.objectCount,
            capacity: props.capacity,
          );
          for (var seed = 0; seed < 20; seed++) {
            final layout = layoutScene(
              catalog: props,
              meta: meta,
              seed: seed,
              profile: band.profile,
            );
            expect(
              layout.finds,
              hasLength(want),
              reason:
                  '${level.id} at ${band.label}: seed $seed placed '
                  '${layout.finds.length} of $want',
            );
          }
        }
      }
    });

    test('the authored scene is what the younger bands play', () async {
      for (final level in catalog.levels) {
        final authored = await rootBundle.loadString(
          level.sceneAssetFor(null, seed: 0),
        );
        // A baked level has no catalog to place: its younger bands are given
        // a picture, checked with the rest of the pool above.
        if (!PropCatalog.isCatalog(
          jsonDecode(authored) as Map<String, dynamic>,
        )) {
          continue;
        }
        final props = PropCatalog.fromJsonString(authored);
        final meta = SceneMeta.fromJsonString(
          await rootBundle.loadString(level.metaAsset),
        );
        for (var seed = 0; seed < 40; seed++) {
          final layout = layoutScene(catalog: props, meta: meta, seed: seed);
          // Finds, not placements: decoys ride along in the same list and
          // are not what the level card promised.
          expect(
            layout.finds,
            hasLength(level.objectCount),
            reason:
                '${level.id}: seed $seed placed '
                '${layout.finds.length} of ${level.objectCount}',
          );
        }
      }
    });
  });

  group('LevelProgress', () {
    test('remembers finished levels and notifies once each', () {
      final progress = LevelProgress();
      var notifications = 0;
      progress.addListener(() => notifications++);

      expect(progress.isComplete('one'), isFalse);
      progress.markComplete('one');
      progress.markComplete('one');

      expect(progress.isComplete('one'), isTrue);
      expect(progress.completed, {'one'});
      expect(notifications, 1);
    });
  });
}
