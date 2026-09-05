import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/scene_meta.dart';

/// The age bands are numbers a child's experience of the game rests on, so
/// what is checked here is the promises those numbers make: that a band is
/// monotonic in difficulty, that no band is allowed to be unfair, and that
/// assist only ever helps.
void main() {
  const bands = AgeBand.values;

  test('an age lands in the band that was drawn for it', () {
    expect(AgeBand.forAge(3), AgeBand.peek);
    expect(AgeBand.forAge(4), AgeBand.peek);
    expect(AgeBand.forAge(5), AgeBand.look);
    expect(AgeBand.forAge(7), AgeBand.look);
    expect(AgeBand.forAge(8), AgeBand.seek);
    expect(AgeBand.forAge(11), AgeBand.hunt);
    // Outside 3-12 the game still has to be playable.
    expect(AgeBand.forAge(1), AgeBand.peek);
    expect(AgeBand.forAge(40), AgeBand.hunt);
  });

  test('the bands cover 3 to 12 without a gap or an overlap', () {
    for (var i = 1; i < bands.length; i++) {
      expect(bands[i].minAge, bands[i - 1].maxAge + 1);
    }
    expect(bands.first.minAge, 3);
    expect(bands.last.maxAge, 12);
  });

  test('a band survives being stored and read back', () {
    for (final band in bands) {
      expect(AgeBand.byId(band.id), band);
    }
    // An id from an older version, or a corrupted one, is not a crash.
    expect(AgeBand.byId('grown-up'), isNull);
    expect(AgeBand.byId(null), isNull);
  });

  test('the older bands play a picture the room shows through', () {
    // The finds on a baked level are painted in, so the placer's levers - a
    // smaller duck, a busier shelf, more cover - are not available. What is
    // left is how solidly a find is drawn.
    for (var i = 1; i < bands.length; i++) {
      expect(
        bands[i].profile.blendOpacity,
        lessThanOrEqualTo(bands[i - 1].profile.blendOpacity),
        reason: '${bands[i].label} is no more solid than the band below it',
      );
    }
    expect(AgeBand.peek.profile.blendOpacity, 1.0);
    expect(
      AgeBand.look.profile.blendOpacity,
      1.0,
      reason: 'the band the art is drawn for plays it as drawn',
    );
    expect(AgeBand.hunt.profile.blendOpacity, lessThan(1.0));
    // The floor: a find has to stay a find. Below about three quarters the
    // outline stops reading against a busy room, and the search becomes an
    // eyesight test rather than a hunt.
    for (final band in bands) {
      expect(
        band.profile.blendOpacity,
        greaterThanOrEqualTo(0.75),
        reason: '${band.label} would be looking for a ghost',
      );
    }
  });

  group('search load rises with the band', () {
    test('each band hides at least as much as the one below it', () {
      var previous = 0;
      for (final band in bands) {
        final count = band.profile.objectCount(12, capacity: 20);
        expect(
          count,
          greaterThanOrEqualTo(previous),
          reason: '${band.label} hides fewer things than the band below',
        );
        previous = count;
      }
    });

    test('Look plays a level exactly as it was authored', () {
      // The art and the meta files are drawn for 5-7, so this band is the one
      // that must not move: it is the reference every other band bends from.
      final look = AgeBand.look.profile;
      expect(look.objectCount(14, capacity: 18), 14);
      expect(
        look.rules(const PlacementRules()).minSeparation,
        const PlacementRules().minSeparation,
      );
    });

    test('no band asks for more than the level can hide', () {
      // The toy room's props each appear once: twelve is all there is.
      for (final band in bands) {
        expect(
          band.profile.objectCount(12, capacity: 12),
          lessThanOrEqualTo(12),
        );
      }
      expect(AgeBand.hunt.profile.objectCount(12, capacity: 12), 12);
    });

    test('the youngest band hides fewer things but never none', () {
      expect(AgeBand.peek.profile.objectCount(12, capacity: 12), 6);
      // A tiny level cannot be halved into nothing.
      expect(
        AgeBand.peek.profile.objectCount(2, capacity: 2),
        greaterThanOrEqualTo(1),
      );
    });

    test('spacing tightens and regions crowd as the band rises', () {
      const base = PlacementRules(minSeparation: 0.08, maxPerRegion: 2);
      expect(
        AgeBand.peek.profile.rules(base).minSeparation,
        greaterThan(base.minSeparation),
      );
      expect(
        AgeBand.hunt.profile.rules(base).minSeparation,
        lessThan(base.minSeparation),
      );
      expect(AgeBand.peek.profile.rules(base).maxPerRegion, 1);
      expect(AgeBand.hunt.profile.rules(base).maxPerRegion, 4);
      // Crowding a region can never mean no props in it at all.
      expect(
        AgeBand.peek.profile
            .rules(const PlacementRules(maxPerRegion: 1))
            .maxPerRegion,
        1,
      );
    });
  });

  group('sprite size', () {
    test('stays inside the range the prop and the room agreed on', () {
      for (final band in bands) {
        for (final sample in [0.0, 0.25, 0.5, 0.75, 0.999]) {
          final width = band.profile.width(0.05, 0.13, sample);
          expect(
            width,
            inInclusiveRange(0.05, 0.13),
            reason: '${band.label} at $sample',
          );
        }
      }
    });

    test('leans large for the young and small for the old', () {
      const sample = 0.5;
      expect(
        AgeBand.peek.profile.width(0.05, 0.13, sample),
        greaterThan(AgeBand.look.profile.width(0.05, 0.13, sample)),
      );
      expect(
        AgeBand.hunt.profile.width(0.05, 0.13, sample),
        lessThan(AgeBand.look.profile.width(0.05, 0.13, sample)),
      );
    });

    test('never goes under the band floor while the room allows it', () {
      // The floor is what keeps difficulty out of eyesight: at every band, the
      // smallest sprite it can be handed is one a thumb can still hit.
      for (final band in bands) {
        final profile = band.profile;
        expect(
          profile.width(0.01, 0.2, 0),
          greaterThanOrEqualTo(profile.minWidth),
        );
      }
    });

    test('only the youngest band is drawn bigger than the art asks', () {
      // The early levels were drawn for older eyes, and a 3 year old cannot
      // hunt a speck. Every other band takes the artist's word for it.
      expect(AgeBand.peek.profile.maxWidth(0.04), greaterThan(0.04));
      for (final band in [AgeBand.look, AgeBand.seek, AgeBand.hunt]) {
        expect(band.profile.maxWidth(0.04), 0.04, reason: band.label);
      }
    });

    test('a prop too small for the floor stays as big as it can be', () {
      // A coin whose region tops out below the floor is not thrown out of the
      // room; it is drawn at the largest size that region allows.
      final peek = AgeBand.peek.profile;
      expect(peek.minWidth, greaterThan(0.03));
      expect(peek.width(0.02, 0.03, 0), 0.03);
      expect(peek.width(0.02, 0.03, 1), 0.03);
    });
  });

  group('help', () {
    test('the younger the band the sooner and longer the help', () {
      expect(
        AgeBand.peek.profile.autoHintAfter!,
        lessThan(AgeBand.look.profile.autoHintAfter!),
      );
      expect(
        AgeBand.look.profile.autoHintAfter!,
        lessThan(AgeBand.seek.profile.autoHintAfter!),
      );
      // The oldest band is left alone until it asks.
      expect(AgeBand.hunt.profile.autoHintAfter, isNull);
      expect(
        AgeBand.peek.profile.hintHold,
        greaterThan(AgeBand.hunt.profile.hintHold),
      );
    });

    test('no band young enough to mind is rated or counted at', () {
      for (final band in [AgeBand.peek, AgeBand.look]) {
        expect(band.profile.scoring, Scoring.none);
        expect(
          band.profile.manualHints,
          isNull,
          reason: 'a hint allowance is a number that runs out',
        );
      }
      expect(AgeBand.seek.profile.scoring, Scoring.stars);
      expect(AgeBand.hunt.profile.manualHints, 3);
    });

    test('only the pre-reading band drops the words', () {
      expect(AgeBand.peek.profile.showLabels, isFalse);
      for (final band in [AgeBand.look, AgeBand.seek, AgeBand.hunt]) {
        expect(band.profile.showLabels, isTrue);
      }
    });

    test('a forgiving tap is the young bands, and it shrinks with age', () {
      var previous = double.infinity;
      for (final band in bands) {
        expect(band.profile.tapPadding, lessThanOrEqualTo(previous));
        previous = band.profile.tapPadding;
      }
      expect(AgeBand.hunt.profile.tapPadding, 0);
    });
  });

  group('the room a band is given', () {
    test('the older bands may be drawn under the size the art asked for', () {
      // Every region in the shipped levels floors at 0.045 or above, so a band
      // that cannot go under the room's own floor has no size lever at all.
      // This is the one rule the meta file does not get the last word on, and
      // it only ever bends downwards.
      expect(AgeBand.peek.profile.widthFloorScale, 1.0);
      expect(AgeBand.look.profile.widthFloorScale, 1.0);
      expect(AgeBand.seek.profile.widthFloorScale, lessThan(1.0));
      expect(
        AgeBand.hunt.profile.widthFloorScale,
        lessThan(AgeBand.seek.profile.widthFloorScale),
      );
    });

    test('the floor is the band\'s own minWidth, whatever the room says', () {
      for (final band in bands) {
        final profile = band.profile;
        for (final roomLow in [0.02, 0.045, 0.06, 0.09, 0.13]) {
          expect(
            profile.widthFloor(roomLow),
            greaterThanOrEqualTo(profile.minWidth),
            reason: '${band.label} at $roomLow',
          );
        }
      }
    });

    test('the youngest band is never handed a harder room', () {
      // Peek is the band the art is already right for. Nothing added for the
      // older bands may reach it: no cover, no decoys, and props put where
      // they show rather than where they hide.
      final peek = AgeBand.peek.profile;
      expect(peek.occlusionMax, 0.0);
      expect(peek.decoyScale, 0.0);
      expect(peek.camouflage, lessThan(0));
      expect(peek.widthFloorScale, 1.0);
    });

    test('cover, clutter and camouflage all rise with the band', () {
      double occl(AgeBand b) => b.profile.occlusionMax;
      double decoy(AgeBand b) => b.profile.decoyScale;
      double camo(AgeBand b) => b.profile.camouflage;
      for (var i = 1; i < bands.length; i++) {
        final lower = bands[i - 1], higher = bands[i];
        expect(occl(higher), greaterThan(occl(lower)), reason: higher.label);
        expect(decoy(higher), greaterThan(decoy(lower)), reason: higher.label);
        expect(camo(higher), greaterThan(camo(lower)), reason: higher.label);
      }
    });

    test('only the older bands ask for a denser backdrop', () {
      expect(AgeBand.peek.profile.sceneVariant, isNull);
      expect(AgeBand.look.profile.sceneVariant, isNull);
      expect(AgeBand.seek.profile.sceneVariant, 'dense');
      expect(AgeBand.hunt.profile.sceneVariant, 'dense');
    });
  });

  group('assist', () {
    test('only ever adds help, and never touches the room', () {
      for (final band in bands) {
        final before = band.profile;
        final after = before.withAssist();
        expect(after.assisted, isTrue);
        // Help.
        expect(after.tapPadding, greaterThanOrEqualTo(before.tapPadding));
        expect(after.hintHold, greaterThanOrEqualTo(before.hintHold));
        expect(after.manualHints, isNull);
        expect(after.autoHintAfter, isNotNull);
        if (before.autoHintAfter != null) {
          expect(after.autoHintAfter!, lessThan(before.autoHintAfter!));
        }
        // The level itself, untouched: assist happens mid-play, and a room
        // that rearranged itself under a stuck child would be worse than the
        // problem it solved.
        expect(after.objectScale, before.objectScale);
        expect(after.widthBias, before.widthBias);
        expect(after.separationScale, before.separationScale);
        // Size, cover, clutter and camouflage are the room, not help. A child
        // the game has quietly stepped in for keeps the level they were
        // given.
        expect(after.widthFloorScale, before.widthFloorScale);
        expect(after.occlusionMax, before.occlusionMax);
        expect(after.decoyScale, before.decoyScale);
        expect(after.camouflage, before.camouflage);
        expect(after.blendOpacity, before.blendOpacity);
        expect(after.band, before.band);
      }
    });

    test('cannot pile up on itself', () {
      final once = AgeBand.seek.profile.withAssist();
      expect(identical(once.withAssist(), once), isTrue);
    });
  });
}
