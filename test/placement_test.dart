import 'dart:math' as math;

import 'package:peepo/game/placement.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/prop_catalog.dart';
import 'package:peepo/models/scene_meta.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scene_pump.dart';

/// The placer is what makes a composited level different every time it is
/// played, so it is checked the way it is used: over many seeds, against a
/// real room - the cabin as it was built before it was baked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PropCatalog catalog;
  late SceneMeta meta;
  late List<SceneLayout> layouts;

  setUpAll(() async {
    catalog = PropCatalog.fromJsonString(await composited('scene'));
    meta = SceneMeta.fromJsonString(await composited('meta'));
    layouts = [
      for (var seed = 0; seed < 40; seed++)
        layoutScene(catalog: catalog, meta: meta, seed: seed),
    ];
  });

  String signature(SceneLayout layout) => [
    for (final placement in layout.placements)
      '${placement.id}@${placement.x.toStringAsFixed(4)},'
          '${placement.y.toStringAsFixed(4)}',
  ].join('|');

  test('the same seed always hides the level the same way', () {
    for (final seed in [0, 7, 99999]) {
      expect(
        signature(layoutScene(catalog: catalog, meta: meta, seed: seed)),
        signature(layoutScene(catalog: catalog, meta: meta, seed: seed)),
      );
    }
  });

  test('every seed hides the level somewhere else', () {
    final seen = layouts.map(signature).toSet();
    expect(seen, hasLength(layouts.length));
  });

  test('no prop keeps landing in the same spot', () {
    // The complaint that started this: the sprites were in the same place
    // every launch. Each prop should move around the room across seeds.
    final spots = <String, Set<String>>{};
    for (final layout in layouts) {
      for (final placement in layout.placements) {
        spots.putIfAbsent(placement.prop.id, () => {}).add(placement.regionId);
      }
    }
    for (final entry in spots.entries) {
      expect(
        entry.value.length,
        greaterThan(2),
        reason: '${entry.key} only ever lands in ${entry.value}',
      );
    }
  });

  test('every layout hides the number of objects the level promises', () {
    for (final layout in layouts) {
      expect(
        layout.placements,
        hasLength(catalog.objectCount),
        reason: 'seed ${layout.seed}',
      );
    }
  });

  test('some things are hidden more than once, each with its own id', () {
    var withCopies = 0;
    for (final layout in layouts) {
      final counts = <String, int>{};
      for (final placement in layout.placements) {
        counts[placement.prop.id] = (counts[placement.prop.id] ?? 0) + 1;
      }
      expect(
        layout.placements.map((p) => p.id).toSet(),
        hasLength(layout.placements.length),
        reason: 'seed ${layout.seed} repeats an object id',
      );
      for (final entry in counts.entries) {
        final prop = catalog.props.firstWhere((p) => p.id == entry.key);
        expect(
          entry.value,
          inInclusiveRange(0, prop.maxCopies),
          reason: '${entry.key} on seed ${layout.seed}',
        );
      }
      if (counts.values.any((count) => count > 1)) withCopies++;
    }
    expect(
      withCopies,
      layouts.length,
      reason:
          'a level that hides more objects than it has props must '
          'place some of them twice',
    );
  });

  test('nothing hangs in mid-air, off the picture or on a no-go zone', () {
    for (final layout in layouts) {
      for (final placement in layout.placements) {
        final where = '${placement.id} on seed ${layout.seed}';
        final region = meta.region(placement.regionId)!;
        expect(region.placements, contains(placement.place), reason: where);
        expect(placement.prop.places, contains(placement.place), reason: where);

        // Standing on the region's surface, to within a rounding of it.
        // What has to touch the surface is the drawn shape, not the sprite
        // box: a lantern's hook leaves transparent margin under its foot, and
        // the placer stands it on its silhouette.
        final surface = hangingPlacements.contains(placement.place)
            ? null
            : region.restY(placement.x);
        if (surface != null) {
          final foot = placement.polygon
              .map((point) => point[1])
              .reduce((a, b) => a > b ? a : b);
          expect((foot - surface).abs(), lessThan(0.001), reason: where);
        }

        for (final point in placement.polygon) {
          expect(point[0], inInclusiveRange(0, 1), reason: where);
          expect(point[1], inInclusiveRange(0, 1), reason: where);
        }
        for (final zone in meta.noGo) {
          expect(
            _box(placement, catalog).overlaps(zone),
            isFalse,
            reason: '$where lands on a no-go zone',
          );
        }
      }
    }
  });

  test('objects are spread out and never overlap', () {
    for (final layout in layouts) {
      for (var i = 0; i < layout.placements.length; i++) {
        for (var j = i + 1; j < layout.placements.length; j++) {
          final a = layout.placements[i];
          final b = layout.placements[j];
          expect(
            _box(a, catalog).overlaps(_box(b, catalog)),
            isFalse,
            reason: '${a.id} and ${b.id} overlap on seed ${layout.seed}',
          );
        }
      }
    }
  });
  group('the level is hidden for the age playing it', () {
    List<SceneLayout> forBand(AgeBand band) => [
      for (var seed = 0; seed < 12; seed++)
        layoutScene(
          catalog: catalog,
          meta: meta,
          seed: seed,
          profile: band.profile,
        ),
    ];

    double meanWidth(List<SceneLayout> layouts) {
      final widths = [
        for (final layout in layouts)
          for (final placement in layout.placements) placement.width,
      ];
      return widths.reduce((a, b) => a + b) / widths.length;
    }

    test('the youngest band hides fewer things, and bigger ones', () {
      final peek = forBand(AgeBand.peek);
      final hunt = forBand(AgeBand.hunt);
      for (var i = 0; i < peek.length; i++) {
        expect(
          peek[i].finds.length,
          lessThan(hunt[i].finds.length),
          reason: 'seed $i',
        );
      }
      expect(meanWidth(peek), greaterThan(meanWidth(hunt)));
    });

    test('every band still fills the room it was given', () {
      // A band that asks for more than the placer can fit would hand a child a
      // list with something on it that is not in the picture.
      for (final band in AgeBand.values) {
        for (final layout in forBand(band)) {
          expect(
            layout.isComplete,
            isTrue,
            reason:
                '${band.label} left '
                '${layout.requested - layout.finds.length} unplaced',
          );
        }
      }
    });

    test('no band drops a prop below the size it can be tapped at', () {
      // The band's own minWidth is the floor, not the prop's: the older bands
      // are meant to go under the size the artist drew a thing for, which is
      // the only size lever a level whose regions all start large has left.
      // What they may not go under is the width a thumb can still hit.
      //
      // The room outranks the floor in one direction only. A region whose
      // ceiling is below the band's floor gets the prop as big as it will go
      // rather than not at all, which is the older behaviour and predates
      // this.
      for (final band in AgeBand.values) {
        for (final layout in forBand(band)) {
          for (final placement in layout.placements) {
            final region = meta.region(placement.regionId)!;
            final ceiling = math.min(
              band.profile.maxWidth(placement.prop.maxWidth),
              region.maxWidth,
            );
            expect(
              placement.width,
              greaterThanOrEqualTo(
                math.min(band.profile.minWidth, ceiling) - 1e-9,
              ),
              reason: '${band.label}: ${placement.id}',
            );
          }
        }
      }
    });

    test('the older bands are drawn smaller than the art asked for', () {
      // Every region in the shipped levels floors at or above 0.045, so before
      // the band was allowed under that floor Hunt played at Look's sizes and
      // the whole size axis did nothing above the middle band.
      final byBand = {
        for (final band in AgeBand.values) band: meanWidth(forBand(band)),
      };
      expect(byBand[AgeBand.peek]!, greaterThan(byBand[AgeBand.look]!));
      expect(byBand[AgeBand.look]!, greaterThan(byBand[AgeBand.seek]!));
      expect(byBand[AgeBand.seek]!, greaterThan(byBand[AgeBand.hunt]!));
    });

    test('a decoy is never a thing the player was asked to find', () {
      for (final band in AgeBand.values) {
        for (final layout in forBand(band)) {
          final asked = {for (final find in layout.finds) find.prop.id};
          for (final placement in layout.placements) {
            if (placement.findable) continue;
            expect(
              asked,
              isNot(contains(placement.prop.id)),
              reason: '${band.label}: ${placement.id}',
            );
          }
        }
      }
    });

    test('no band loses more of a prop to the scenery than it allows', () {
      for (final band in AgeBand.values) {
        for (final layout in forBand(band)) {
          for (final placement in layout.placements) {
            final clip = placement.clip;
            if (clip == null) continue;
            // What is left showing has to still be a thing rather than a
            // sliver, on both axes. Measured against the sprite's own size,
            // which is no larger than the box the placer clipped - a rotated
            // prop occupies more than its own width and height.
            //
            // The relaxed passes accept more cover than the band asked for
            // rather than hand back a level with something missing on its
            // list, so what is checked here is that floor and not the band's
            // own occlusionMax.
            expect(
              clip.width,
              greaterThanOrEqualTo(placement.width * 0.4 - 1e-9),
              reason: '${band.label}: ${placement.id} width',
            );
            expect(
              clip.height,
              greaterThanOrEqualTo(placement.height * 0.4 - 1e-9),
              reason: '${band.label}: ${placement.id} height',
            );
            // And a clip is only recorded when it actually covers something.
            expect(
              clip.area,
              greaterThan(0),
              reason: '${band.label}: ${placement.id}',
            );
          }
        }
      }
    });

    test('a prop is only cut off by something that reaches across it', () {
      // The cut is horizontal and takes the prop's whole width - going behind
      // something means your feet disappear first - so the thing in front has
      // to actually reach across the prop. A crate grazing one edge that took
      // the bottom off anyway left the sprite sliced clean in the open, with
      // nothing drawn in front of the cut and no tap accepted below it.
      for (final band in AgeBand.values) {
        for (final layout in forBand(band)) {
          for (final placement in layout.placements) {
            final clip = placement.clip;
            if (clip == null) continue;
            // The clip keeps the box's full width, so the box is as wide as
            // it is - and the occluder has to cover most of that.
            final region = meta.region(placement.regionId)!;
            final reach = [
              for (final id in region.occludedBy)
                if (meta.region(id) case final other?)
                  math.min(clip.x1, other.rect.x1) -
                      math.max(clip.x0, other.rect.x0),
            ];
            expect(
              reach.fold<double>(0, math.max),
              greaterThanOrEqualTo(clip.width * 0.85 - 1e-9),
              reason:
                  '${band.label}: ${placement.id} is cut off by something '
                  'that only grazes it',
            );
          }
        }
      }
    });

    test('the same seed and band always hide the level the same way', () {
      for (final band in AgeBand.values) {
        expect(
          signature(
            layoutScene(
              catalog: catalog,
              meta: meta,
              seed: 5,
              profile: band.profile,
            ),
          ),
          signature(
            layoutScene(
              catalog: catalog,
              meta: meta,
              seed: 5,
              profile: band.profile,
            ),
          ),
        );
      }
    });
  });
}

double _halfHeight(Placement placement, PropCatalog catalog) {
  final theta = radians(placement.rotation);
  final aspect = placement.prop.aspect;
  return placement.width *
      catalog.aspect *
      (_abs(theta, sin: true) + aspect * _abs(theta, sin: false)) /
      2;
}

double _halfWidth(Placement placement) {
  final theta = radians(placement.rotation);
  final aspect = placement.prop.aspect;
  return placement.width *
      (_abs(theta, sin: false) + aspect * _abs(theta, sin: true)) /
      2;
}

double _abs(double theta, {required bool sin}) =>
    (sin ? math.sin(theta) : math.cos(theta)).abs();

SceneRect _box(Placement placement, PropCatalog catalog) {
  final halfWidth = _halfWidth(placement);
  final halfHeight = _halfHeight(placement, catalog);
  return SceneRect(
    placement.x - halfWidth,
    placement.y - halfHeight,
    placement.x + halfWidth,
    placement.y + halfHeight,
  );
}
