import 'dart:math' as math;

import 'scene_meta.dart';

/// How old the player is, in the four bands the game is tuned for.
///
/// The bands are developmental rather than arithmetic: they sit on the jumps
/// that change what a child can do with a hidden object scene - not reading
/// yet, reading short words, reading fluently, and reading well enough that
/// the words stop being the difficulty at all.
enum AgeBand {
  /// Pre-reading. Few things to find, all of them large, tapping is forgiving
  /// and a hint arrives before frustration does.
  peek('Peek', 3, 4),

  /// Early reading. The band the scene art and the meta files are drawn for,
  /// so a level plays closest to how it was authored here.
  look('Look', 5, 7),

  /// Fluent reading. More to find, smaller, closer together, less help.
  seek('Seek', 8, 10),

  /// Hunting. Full clutter, no automatic help, and a rating at the end.
  hunt('Hunt', 11, 12);

  const AgeBand(this.label, this.minAge, this.maxAge);

  /// Player-facing name of the band. Deliberately a word about looking rather
  /// than a word about difficulty: nobody is put in the "easy" one.
  final String label;

  final int minAge;
  final int maxAge;

  /// e.g. "3-4". For a badge that carries no other context, use [ageBadge]:
  /// two numbers and a dash do not say what they count.
  String get ageLabel => '$minAge-$maxAge';

  /// e.g. "3-4 yrs". What the badges on the home screen and the band cards
  /// show, because a parent scanning them reads "5-7" as anything from a
  /// difficulty number to a level range.
  String get ageBadge => '$ageLabel yrs';

  /// Stable key for storage. The enum name, kept explicit so renaming the
  /// band in Dart does not silently reset every installed app.
  String get id => switch (this) {
    AgeBand.peek => 'peek',
    AgeBand.look => 'look',
    AgeBand.seek => 'seek',
    AgeBand.hunt => 'hunt',
  };

  static AgeBand? byId(String? id) {
    for (final band in AgeBand.values) {
      if (band.id == id) return band;
    }
    return null;
  }

  /// The band a child of [age] belongs in, clamped at both ends so an age
  /// outside 3-12 still gets a playable game.
  static AgeBand forAge(int age) {
    for (final band in AgeBand.values) {
      if (age <= band.maxAge) return band;
    }
    return AgeBand.hunt;
  }

  /// What this band changes about a level.
  DifficultyProfile get profile => DifficultyProfile.of(this);
}

/// How a level is rated when it ends.
enum Scoring {
  /// Finishing is the reward. No stars, no time, nothing that can be lost -
  /// which is the only thing that works below about eight.
  none,

  /// Three stars, spent by taking a long time and by taking hints.
  stars,
}

/// Everything an [AgeBand] changes, in one immutable bundle.
///
/// Difficulty in a hidden object game is not one slider. It is six things that
/// move independently, and only the first two are about the picture:
///
/// 1. Visual search load - how many things are hidden, how big they are, how
///    far apart they sit ([objectScale], [widthBias], [minWidth],
///    [separationScale], [regionCrowdDelta]).
/// 2. Motor precision - how near a tap has to land ([tapPadding]).
/// 3. Ask abstraction - a picture, a word, a count, a category. Only the
///    picture/word step lives here so far ([showLabels]); the rest arrives
///    with the alternative asks.
/// 4. Working memory - how much of the list is held at once. Not yet varied.
/// 5. Scaffolding - how soon and how much the game helps ([autoHintAfter],
///    [hintHold], [manualHints]).
/// 6. Pressure - whether the ending judges the playthrough ([scoring]).
///
/// Shrinking sprites is the cheapest of these and the worst on its own: it
/// buys difficulty out of eyesight and thumb size rather than out of
/// searching, which reads as unfair at every age. [minWidth] is the floor that
/// keeps the oldest band honest.
class DifficultyProfile {
  const DifficultyProfile({
    required this.band,
    required this.objectScale,
    required this.objectFloor,
    required this.widthBias,
    required this.minWidth,
    required this.maxWidthBoost,
    required this.widthFloorScale,
    required this.decoyScale,
    required this.occlusionMax,
    required this.camouflage,
    required this.separationScale,
    required this.regionCrowdDelta,
    required this.tapPadding,
    required this.autoHintAfter,
    required this.hintHold,
    required this.manualHints,
    required this.parPerObject,
    required this.blendOpacity,
    required this.showLabels,
    required this.scoring,
    this.assisted = false,
  });

  final AgeBand band;

  /// Multiplies the level's own object count. A level ships one catalog and
  /// every band plays it: the youngest see a third of the room's props, the
  /// oldest see every one of them plus extra copies.
  final double objectScale;

  /// Never fewer than this many things to find, however small the level.
  final int objectFloor;

  /// Where in a prop's legal width range the placer aims: 0.5 picks evenly,
  /// above that leans large, below that leans small. The range itself still
  /// comes from the scene meta, so no band can put a wardrobe on a shelf.
  final double widthBias;

  /// How far past the size an artist drew a prop for this band may stretch it,
  /// so long as the room still has space for it.
  ///
  /// Only the youngest band uses it, and only because the earlier levels were
  /// drawn for older eyes: the cabin's coin is a third of the width its own
  /// shelf would allow, and at 3 that is not a hidden object, it is a speck.
  /// The region's ceiling is never crossed - a coin can be a big coin, it
  /// cannot be one that overhangs the shelf it sits on.
  final double maxWidthBoost;

  /// Smallest sprite width, as a fraction of scene width, that this band is
  /// allowed to be handed - subject to the prop actually fitting that big.
  ///
  /// On a phone about 400 logical pixels wide, 0.09 is a 36 pixel target and
  /// 0.055 is 22: past that a find stops being hard and starts being a
  /// pixel hunt.
  final double minWidth;

  /// Scales the floor the room itself sets before [minWidth] is applied, so
  /// the oldest bands can go under the size the art was drawn at.
  ///
  /// This is the one place a band is allowed to argue with the meta file, and
  /// it only ever argues downwards. Without it the older bands have no size
  /// lever at all: a region whose `sizeRange` starts at 0.09 hands Hunt the
  /// same sprite it hands Look, and [minWidth] - the floor that is supposed to
  /// keep the oldest band honest - never comes into it. [minWidth] is still
  /// the hard stop underneath, so this cannot shrink a find into a pixel hunt.
  final double widthFloorScale;

  /// How many decoys to place, as a fraction of the things actually hidden.
  ///
  /// A decoy is a sprite on the backdrop that is not on the list and cannot be
  /// found. It is the honest way to make a scene harder: the player has to
  /// look at a thing and decide it is not the thing, which is searching, not
  /// eyesight. Zero for the youngest band, where every sprite on screen should
  /// be something to be proud of finding.
  final double decoyScale;

  /// The most of a sprite that may sit behind the scenery in front of its
  /// region, as a fraction of its area. Zero places nothing behind anything.
  ///
  /// What is left showing is still what can be tapped, so this never hands a
  /// player a target they cannot see.
  final double occlusionMax;

  /// Whether this band's props are put where they show or where they hide.
  ///
  /// -1 prefers a region whose tone the prop contrasts, +1 prefers one it
  /// disappears into, 0 does not care. It is a weight on the region draw and
  /// never a filter: no band may make a region unreachable, or a level whose
  /// props all share a tone would have nowhere left to put them.
  final double camouflage;

  /// Scales the scene's own minimum spacing. Spread out is easier to scan;
  /// crowded together is what makes an older player work.
  final double separationScale;

  /// Added to the scene's cap on finds per region. Negative keeps the
  /// youngest band's objects spread over the whole picture.
  final int regionCrowdDelta;

  /// How far outside an object's outline a tap still counts, in scene-width
  /// units. This is the fairness knob: a three year old's tap lands near the
  /// duck rather than on it.
  final double tapPadding;

  /// Idle time before the game points something out by itself. Null leaves
  /// hinting entirely to the player.
  ///
  /// A child this young does not ask for help - they put the tablet down - so
  /// below [AgeBand.hunt] the game has to notice instead.
  final Duration? autoHintAfter;

  /// How long a hint stays up once it is shown.
  final Duration hintHold;

  /// Hints the player may ask for, or null for as many as they like.
  final int? manualHints;

  /// The pace a full-star playthrough keeps, per thing hidden. Unused where
  /// [scoring] is [Scoring.none], which is every band young enough for a
  /// clock to be a threat.
  final Duration parPerObject;

  /// How solid a find is drawn, from 1 for the paint the illustrator laid down
  /// to 0 for not drawn at all.
  ///
  /// Under 1 the room shows faintly through the thing standing in it, so a
  /// find stops announcing itself and has to be picked out of what is behind
  /// it. It is the one lever a baked picture has left: the finds are painted
  /// in, so the older bands cannot be handed a smaller duck or a busier shelf,
  /// only a quieter one.
  ///
  /// It never goes far. A find a child cannot see is not a hard find, it is a
  /// broken one, and the floor here is well above the point where the outline
  /// stops reading against the room.
  final double blendOpacity;

  /// Whether the object chips carry their name under the picture. Off for the
  /// pre-reading band, where a word is noise.
  final bool showLabels;

  final Scoring scoring;

  /// Which backdrop this band plays, where the level ships more than one.
  ///
  /// A level is authored for the middle bands and a scene drawn calm enough
  /// for a three year old is a scene an eleven year old clears at a glance,
  /// whatever the placer does with it. Where a level ships a denser second
  /// backdrop, the older two bands get it; where it does not, they play the
  /// only one there is. Null means the level's own scene, which is what every
  /// level shipped before variants existed.
  String? get sceneVariant => switch (band) {
    AgeBand.peek || AgeBand.look => null,
    AgeBand.seek || AgeBand.hunt => 'dense',
  };

  /// True once the game has quietly stepped in for a player who is stuck.
  /// Assist only ever adds help; nothing in it can make a level harder.
  final bool assisted;

  static const _peek = DifficultyProfile(
    band: AgeBand.peek,
    objectScale: 0.5,
    objectFloor: 4,
    widthBias: 0.88,
    minWidth: 0.09,
    maxWidthBoost: 1.35,
    widthFloorScale: 1.0,
    decoyScale: 0.0,
    occlusionMax: 0.0,
    camouflage: -1.0,
    separationScale: 1.35,
    regionCrowdDelta: -1,
    tapPadding: 0.030,
    autoHintAfter: Duration(seconds: 12),
    hintHold: Duration(milliseconds: 3500),
    manualHints: null,
    parPerObject: Duration(seconds: 25),
    blendOpacity: 1.0,
    showLabels: false,
    scoring: Scoring.none,
  );

  static const _look = DifficultyProfile(
    band: AgeBand.look,
    objectScale: 1.0,
    objectFloor: 6,
    widthBias: 0.5,
    minWidth: 0.06,
    maxWidthBoost: 1.0,
    widthFloorScale: 1.0,
    decoyScale: 0.25,
    occlusionMax: 0.15,
    camouflage: 0.0,
    separationScale: 1.0,
    regionCrowdDelta: 0,
    tapPadding: 0.018,
    autoHintAfter: Duration(seconds: 25),
    hintHold: Duration(milliseconds: 2500),
    manualHints: null,
    parPerObject: Duration(seconds: 18),
    blendOpacity: 1.0,
    showLabels: true,
    scoring: Scoring.none,
  );

  static const _seek = DifficultyProfile(
    band: AgeBand.seek,
    objectScale: 1.15,
    objectFloor: 8,
    widthBias: 0.38,
    minWidth: 0.05,
    maxWidthBoost: 1.0,
    widthFloorScale: 0.80,
    decoyScale: 0.6,
    occlusionMax: 0.35,
    camouflage: 0.6,
    separationScale: 0.85,
    regionCrowdDelta: 1,
    tapPadding: 0.008,
    autoHintAfter: Duration(seconds: 45),
    hintHold: Duration(milliseconds: 2000),
    manualHints: 5,
    parPerObject: Duration(seconds: 12),
    blendOpacity: 0.92,
    showLabels: true,
    scoring: Scoring.stars,
  );

  static const _hunt = DifficultyProfile(
    band: AgeBand.hunt,
    objectScale: 1.4,
    objectFloor: 10,
    widthBias: 0.2,
    minWidth: 0.04,
    maxWidthBoost: 1.0,
    widthFloorScale: 0.62,
    decoyScale: 1.0,
    occlusionMax: 0.50,
    camouflage: 1.0,
    separationScale: 0.7,
    regionCrowdDelta: 2,
    tapPadding: 0.0,
    autoHintAfter: null,
    hintHold: Duration(milliseconds: 1300),
    manualHints: 3,
    parPerObject: Duration(seconds: 9),
    blendOpacity: 0.84,
    showLabels: true,
    scoring: Scoring.stars,
  );

  static DifficultyProfile of(AgeBand band) => switch (band) {
    AgeBand.peek => _peek,
    AgeBand.look => _look,
    AgeBand.seek => _seek,
    AgeBand.hunt => _hunt,
  };

  /// The profile a level plays at when nothing has been chosen yet.
  static const DifficultyProfile fallback = _look;

  /// How many things this band hides in a level whose catalog asks for
  /// [catalogCount] and can hold at most [capacity].
  ///
  /// The ceiling matters: the older bands ask for more than the level was
  /// authored with, and a level whose props each appear once has nothing more
  /// to give. Answering honestly here is what keeps the level card's promise
  /// and the room the player is handed the same number.
  int objectCount(int catalogCount, {int? capacity}) {
    if (catalogCount <= 0) return 0;
    final ceiling = math.max(catalogCount, capacity ?? catalogCount);
    final scaled = (catalogCount * objectScale).round();
    return scaled.clamp(math.min(objectFloor, catalogCount), ceiling);
  }

  /// The scene's placement rules as this band plays them.
  PlacementRules rules(PlacementRules base) => PlacementRules(
    minSeparation: base.minSeparation * separationScale,
    edgeMargin: base.edgeMargin,
    maxPerRegion: base.maxPerRegion == null
        ? null
        : math.max(1, base.maxPerRegion! + regionCrowdDelta),
  );

  /// The largest this band may draw a prop an artist sized at [propMax].
  /// Still subject to the region's own ceiling, which the caller applies.
  double maxWidth(double propMax) => propMax * maxWidthBoost;

  /// The smallest this band may draw a prop the room floors at [roomLow].
  ///
  /// The floor moves both ways: [widthFloorScale] takes the older bands under
  /// the size the art asked for, and [minWidth] pulls the youngest band above
  /// it. Whichever is larger wins, so [minWidth] is always the hard stop.
  double widthFloor(double roomLow) =>
      math.max(roomLow * widthFloorScale, minWidth);

  /// Picks a sprite width out of the range `[low, high]` a prop and its region
  /// agree on, given a uniform [sample] in [0, 1).
  ///
  /// The floor is applied first and only as far as the range allows: a prop
  /// that cannot be drawn at [minWidth] in this region stays as big as it can
  /// be rather than being thrown out of the room.
  double width(double low, double high, double sample) {
    if (high <= low) return low;
    final floored = math.min(high, math.max(low, minWidth));
    final t = _shape(sample.clamp(0.0, 1.0), widthBias);
    return floored + t * (high - floored);
  }

  /// Bends a uniform sample towards one end of its range. 0.5 leaves it
  /// alone, 1 pins it to the top, 0 pins it to the bottom.
  static double _shape(double sample, double bias) {
    if (bias >= 0.999) return 1;
    if (bias <= 0.001) return 0;
    final exponent = (1 - bias) / bias;
    return math.pow(sample, exponent).toDouble();
  }

  /// The same band, helping harder, for a player the game can see is stuck.
  ///
  /// Only scaffolding and tap tolerance move, and only upwards: the room stays
  /// exactly as it was placed. A child never has a level taken away from them
  /// halfway through, and nothing here can be felt as a demotion.
  DifficultyProfile withAssist() {
    if (assisted) return this;
    final sooner = autoHintAfter ?? const Duration(seconds: 40);
    return DifficultyProfile(
      band: band,
      objectScale: objectScale,
      objectFloor: objectFloor,
      widthBias: widthBias,
      minWidth: minWidth,
      maxWidthBoost: maxWidthBoost,
      // The room stays exactly the size, the clutter, the cover and the paint
      // it was placed with. None of these five is help, so assist does not
      // touch them: a child who is stuck gets more hints, not a different
      // level - and a find that solidified halfway through a game would be the
      // picture itself changing under them.
      widthFloorScale: widthFloorScale,
      decoyScale: decoyScale,
      occlusionMax: occlusionMax,
      camouflage: camouflage,
      blendOpacity: blendOpacity,
      separationScale: separationScale,
      regionCrowdDelta: regionCrowdDelta,
      tapPadding: math.max(tapPadding, 0.012),
      autoHintAfter: Duration(milliseconds: sooner.inMilliseconds ~/ 2),
      hintHold: hintHold * 1.4,
      manualHints: null,
      parPerObject: parPerObject,
      showLabels: showLabels,
      scoring: scoring,
      assisted: true,
    );
  }
}
