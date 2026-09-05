import 'dart:math' as math;

import '../models/difficulty.dart';
import '../models/prop_catalog.dart';
import '../models/scene_meta.dart';

/// Decides where every prop hides, freshly, each time a level is played.
///
/// The old pipeline baked one layout into the level file, so the cabin looked
/// identical on every launch and a player could learn it once. Placement is now
/// a runtime step: the level ships a catalog of props and the backdrop's
/// description (see [SceneMeta]), and this picks a region, a size, an angle and
/// a spot for each of them from a seeded random source.
///
/// The same seed always gives the same layout, which is what makes a level
/// shareable, reproducible in a test and previewable from `tools/layout.dart`.
///
/// Every placement obeys the room: it lands in a region that can hold that kind
/// of prop, at a size that region's depth allows, with its bottom edge on the
/// region's rest line so nothing floats, off the no-go zones, inside the frame,
/// and far enough from its neighbours to be worth hunting.
///
/// Pure Dart on purpose - no `dart:ui`, no Flutter - so it runs in the app and
/// in a plain `dart run` script alike.
class Placement {
  const Placement({
    required this.id,
    required this.prop,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rotation,
    required this.regionId,
    required this.place,
    required this.polygon,
    this.clip,
    this.findable = true,
  });

  /// Unique within a layout: the prop id, and `#2`, `#3`... for further copies.
  final String id;

  final PropDef prop;

  /// Centre of the sprite, normalized.
  final double x, y;

  /// Sprite box: [width] as a fraction of scene width, [height] as a fraction
  /// of scene height.
  final double width, height;

  /// Clockwise on screen, in degrees.
  final double rotation;

  final String regionId;

  /// How it meets its region, e.g. `rests_on`.
  final String place;

  /// Tap polygon in normalized scene coordinates.
  final List<List<double>> polygon;

  /// What the scenery in front of this prop's region leaves showing, in
  /// normalized scene coordinates, or null when all of it shows.
  final SceneRect? clip;

  /// False for a decoy: placed and drawn like anything else, on no list, and
  /// never the answer to a tap.
  final bool findable;
}

/// One playthrough's worth of placements.
class SceneLayout {
  const SceneLayout({
    required this.seed,
    required this.placements,
    required this.requested,
  });

  /// The seed that produced this layout; replaying it reproduces the scene.
  final int seed;

  final List<Placement> placements;

  /// How many objects the level asked for. More than `placements.length` means
  /// the room ran out of room - rare, and never fatal.
  final int requested;

  /// Everything that is actually on a list. Decoys ride along in
  /// [placements] but are not what the level promised.
  Iterable<Placement> get finds => placements.where((p) => p.findable);

  bool get isComplete => finds.length == requested;
}

/// Attempts at the whole layout before the best one so far is accepted. Each
/// attempt loosens the spacing rules a little, so a crowded room degrades into
/// a tighter scene instead of a scene missing objects.
const _layoutAttempts = 24;

/// Spots tried per object within one attempt.
const _spotAttempts = 220;

/// How much of a gap in the scenery a prop may fill and still look like it was
/// put there rather than wedged in. Below one it may overhang the gap a little,
/// which is what a thing leaning into its neighbours does.
const _spanFit = 0.8;

/// Sprites may not overlap at all, plus this much clear air between them.
const _spriteGap = 0.004;

/// How far a resting prop may sit off its region's box before the placement is
/// judged to have left the region. Mirrors FOOT_SLACK in `build_scene.py`.
const _footSlack = 0.03;

/// How much a region's clutter is worth when the draw picks where a prop goes.
///
/// A find looks pasted on when it is the only thing on its patch of picture:
/// the eye reads a lone object on bare floor as a sticker however well it is
/// drawn and however softly it is shadowed. So the draw leans hard towards the
/// parts of the room that already hold things - shelf tiers, cubbies, netting,
/// a console top - where the prop arrives as one more object among many.
///
/// It stays a lean, not a filter: an open region still comes up, just rarely.
const _clutterDraw = {'high': 1.0, 'medium': 0.5, 'low': 0.15};

/// One in this many placements may sit in an open, low-clutter region, and at
/// least one always may. Past that the open parts of the room are taken off
/// the draw, so a scene never ends up with a row of loose objects standing on
/// an empty floor.
const _openShare = 10;

/// How far up its size range a prop in an open region may be drawn. Something
/// standing alone in the middle of the floor also reads as pasted on when it
/// is drawn bigger than the scenery around it, so out in the open it is drawn
/// at the small end and left to the clutter to be a hero anywhere else.
const _openWidthCeiling = 0.5;

/// Places [catalog]'s props on [meta]'s backdrop for the given [seed], as the
/// player's age band ([profile]) plays them.
///
/// The level ships one catalog and one backdrop for every age: what the band
/// changes is how many props are hidden, how big they are drawn and how far
/// apart they must sit. The room itself - which regions can hold what, where
/// its rest lines run - is the meta's word and no band overrides it.
SceneLayout layoutScene({
  required PropCatalog catalog,
  required SceneMeta meta,
  required int seed,
  DifficultyProfile? profile,
}) {
  final band = profile ?? DifficultyProfile.fallback;
  final plan = _copyPlan(catalog, math.Random(seed), band);
  final banded = band.rules(meta.rules);
  var best = <Placement>[];
  for (var attempt = 0; attempt < _layoutAttempts; attempt++) {
    // Attempt 0 obeys the meta exactly; later ones give up spacing gradually
    // rather than give up an object.
    final relax = attempt / _layoutAttempts * 0.8;
    final rules = banded.relaxed(relax);
    final placements = _attempt(
      plan: plan,
      catalog: catalog,
      meta: meta,
      rules: rules,
      relax: relax,
      profile: band,
      random: math.Random(seed + attempt * 7919),
    );
    if (placements.length > best.length) best = placements;
    if (best.length == plan.length) break;
  }
  // Decoys go in after the finds and never instead of one: what is asked for
  // is settled first, and whatever room is left over is what the red herrings
  // get.
  best.addAll(
    _placeDecoys(
      placed: best,
      pool: _decoyPool(catalog, plan),
      count: (plan.length * band.decoyScale).round(),
      catalog: catalog,
      meta: meta,
      rules: banded,
      profile: band,
      random: math.Random(seed ^ 0x5EED),
    ),
  );
  // Back to front, so a near prop drawn over a far one looks right if they
  // ever do meet.
  best.sort((a, b) => a.y.compareTo(b.y));
  return SceneLayout(seed: seed, placements: best, requested: plan.length);
}

/// Art that may go in the room without being asked for, in the order it is
/// reached for.
///
/// The props this playthrough is not hiding come first - a level that shows a
/// young player half its catalog already owns the other half, and drawing it
/// costs nothing. A level that ships explicit [PropCatalog.decoys] comes
/// after, which is what the oldest band needs: it is already being asked for
/// every prop there is, so nothing is spare.
///
/// The two are kept apart rather than run together, because the order is the
/// whole point of the list and a shuffle over the lot would lose it.
///
/// A prop the player is hunting for is never a decoy. Two identical unicorns
/// with only one of them findable is not a hard level, it is a broken one.
List<List<PropDef>> _decoyPool(PropCatalog catalog, List<PropDef> plan) {
  final hidden = {for (final prop in plan) prop.id};
  return [
    [
      for (final prop in catalog.props)
        if (!hidden.contains(prop.id)) prop,
    ],
    catalog.decoys,
  ];
}

/// Fills what is left of the room with [count] things off [pool], obeying every
/// rule a find obeys.
///
/// One pass and no retries: a decoy that will not fit is a decoy the scene did
/// not need. Nothing here can dislodge a placement already made.
List<Placement> _placeDecoys({
  required List<Placement> placed,
  required List<List<PropDef>> pool,
  required int count,
  required PropCatalog catalog,
  required SceneMeta meta,
  required PlacementRules rules,
  required DifficultyProfile profile,
  required math.Random random,
}) {
  if (count <= 0 || pool.every((segment) => segment.isEmpty)) return const [];
  final decoys = <Placement>[];
  final all = [...placed];
  final usage = <String, int>{};
  for (final placement in placed) {
    usage[placement.regionId] = (usage[placement.regionId] ?? 0) + 1;
  }
  // The finds have already spent part of the scene's open-space budget, and a
  // decoy standing alone on bare floor reads as pasted on exactly like a find
  // does, so the two are counted against the one budget.
  final openBudget = math.max(
    1,
    ((placed.length + count) / _openShare).round(),
  );
  var open = 0;
  for (final placement in placed) {
    final region = meta.region(placement.regionId);
    if (region != null && _isOpen(region)) open++;
  }
  // Shuffled inside each band of the pool and never across them: which prop
  // of a kind turns up is chance, which kind is reached for first is not.
  final order = <PropDef>[];
  for (final segment in pool) {
    order.addAll([...segment]..shuffle(random));
  }
  for (var i = 0; i < count; i++) {
    final prop = order[i % order.length];
    final candidates = _candidateRegions(prop, meta);
    if (candidates.isEmpty) continue;
    Placement? found;
    for (var spot = 0; spot < _spotAttempts && found == null; spot++) {
      final region = _pickRegion(
        candidates,
        usage,
        random,
        prop: prop,
        profile: profile,
        // Half a prop's tries are spent looking for somewhere it belongs; if
        // the cluttered parts of the room have no room left, the open ones
        // come back rather than leave the prop out of the picture.
        openIsFull: open >= openBudget && spot < _spotAttempts ~/ 2,
      );
      if (rules.maxPerRegion != null &&
          (usage[region.id] ?? 0) >= rules.maxPerRegion!) {
        continue;
      }
      found = _trySpot(
        prop: prop,
        region: region,
        catalog: catalog,
        meta: meta,
        rules: rules,
        profile: profile,
        placed: all,
        random: random,
        copyIndex: 0,
        findable: false,
      );
    }
    if (found == null) continue;
    // Its own id space, so a decoy can never be mistaken for the copy of a
    // find that shares its prop.
    final decoy = Placement(
      id: 'decoy:${prop.id}:$i',
      prop: found.prop,
      x: found.x,
      y: found.y,
      width: found.width,
      height: found.height,
      rotation: found.rotation,
      regionId: found.regionId,
      place: found.place,
      polygon: found.polygon,
      clip: found.clip,
      findable: false,
    );
    decoys.add(decoy);
    all.add(decoy);
    usage[decoy.regionId] = (usage[decoy.regionId] ?? 0) + 1;
    final chosen = meta.region(decoy.regionId);
    if (chosen != null && _isOpen(chosen)) open++;
  }
  return decoys;
}

/// Which props appear, and how many times each, for one playthrough.
///
/// Every prop starts at its minimum, then copies are handed out at random to
/// whatever still has headroom until the level's object count is met - so a
/// scene that hides fourteen things out of twelve props shows two of them
/// twice, and which two changes with the seed.
///
/// How many the level wants is the band's call: the youngest hunt for half a
/// room, the oldest for a room and a half.
List<PropDef> _copyPlan(
  PropCatalog catalog,
  math.Random random,
  DifficultyProfile profile,
) {
  final counts = <String, int>{};
  final byId = <String, PropDef>{};
  for (final prop in catalog.props) {
    byId[prop.id] = prop;
    counts[prop.id] = math.max(0, prop.minCopies);
  }
  var total = counts.values.fold(0, (sum, count) => sum + count);
  final target = math.max(
    1,
    profile.objectCount(catalog.objectCount, capacity: catalog.capacity),
  );

  // Too many for the level: drop whole props, so what is left is still whole.
  while (total > target) {
    final droppable = [
      for (final entry in counts.entries)
        if (entry.value > 0) entry.key,
    ];
    if (droppable.isEmpty) break;
    final id = droppable[random.nextInt(droppable.length)];
    counts[id] = counts[id]! - 1;
    total--;
  }
  // Too few: hand out extra copies to props that allow them.
  while (total < target) {
    final growable = [
      for (final entry in counts.entries)
        if (entry.value < byId[entry.key]!.maxCopies) entry.key,
    ];
    if (growable.isEmpty) break;
    final id = growable[random.nextInt(growable.length)];
    counts[id] = counts[id]! + 1;
    total++;
  }

  final plan = <PropDef>[];
  for (final prop in catalog.props) {
    for (var i = 0; i < counts[prop.id]!; i++) {
      plan.add(prop);
    }
  }
  // Biggest first: a hat needs one of the few regions that can hold it, and
  // gets the pick of them before a coin fills one up.
  plan.sort((a, b) => b.maxWidth.compareTo(a.maxWidth));
  return plan;
}

List<Placement> _attempt({
  required List<PropDef> plan,
  required PropCatalog catalog,
  required SceneMeta meta,
  required PlacementRules rules,
  required DifficultyProfile profile,
  required math.Random random,
  double relax = 0,
}) {
  final placed = <Placement>[];
  final usage = <String, int>{};
  final copies = <String, int>{};
  // How many objects may stand out in the open before the open parts of the
  // room stop being drawn. Counted over the whole scene, decoys included, so
  // the budget means the same thing to a player as it does here.
  final openBudget = math.max(1, (plan.length / _openShare).round());
  var open = 0;

  for (final prop in plan) {
    final candidates = _candidateRegions(prop, meta);
    if (candidates.isEmpty) continue;

    Placement? found;
    for (var spot = 0; spot < _spotAttempts && found == null; spot++) {
      final region = _pickRegion(
        candidates,
        usage,
        random,
        prop: prop,
        profile: profile,
        // Half a prop's tries are spent looking for somewhere it belongs; if
        // the cluttered parts of the room have no room left, the open ones
        // come back rather than leave the prop out of the picture.
        openIsFull: open >= openBudget && spot < _spotAttempts ~/ 2,
      );
      if (rules.maxPerRegion != null &&
          (usage[region.id] ?? 0) >= rules.maxPerRegion!) {
        continue;
      }
      found = _trySpot(
        prop: prop,
        region: region,
        catalog: catalog,
        meta: meta,
        rules: rules,
        profile: profile,
        placed: placed,
        random: random,
        relax: relax,
        copyIndex: copies[prop.id] ?? 0,
      );
    }
    if (found == null) continue;
    placed.add(found);
    usage[found.regionId] = (usage[found.regionId] ?? 0) + 1;
    copies[prop.id] = (copies[prop.id] ?? 0) + 1;
    final chosen = meta.region(found.regionId);
    if (chosen != null && _isOpen(chosen)) open++;
  }
  return placed;
}

/// Regions that can hold [prop]: allowed by name if it names any, able to
/// support how it sits, and sized for it.
List<SceneRegion> _candidateRegions(PropDef prop, SceneMeta meta) => [
  for (final region in meta.regions)
    if (region.holdsSomething &&
        (prop.regions.isEmpty || prop.regions.contains(region.id)) &&
        region.placements.any(prop.places.contains) &&
        math.max(prop.minWidth, region.minWidth) <=
            math.min(prop.maxWidth, region.maxWidth))
      region,
];

/// How well a prop of [tone] disappears against a region of [contrast]:
/// 1 for a match, -1 for opposites, 0 when either is the middle tone or is
/// something the meta did not say.
double _blend(String tone, String contrast) {
  const order = {'light': 1, 'medium': 0, 'dark': -1};
  final a = order[tone];
  final b = order[contrast];
  if (a == null || b == null || a == 0 || b == 0) return 0;
  return a == b ? 1 : -1;
}

/// Picks a region at random, favouring big ones and ones nothing is in yet, so
/// finds spread over the picture instead of piling into the first legal spot.
///
/// The band leans that draw one way or the other: the youngest wants the prop
/// somewhere it shows against the backdrop, the oldest wants it somewhere it
/// does not. It stays a lean and never a filter - every legal region keeps a
/// real chance, or a level whose props all share one tone would run out of
/// places to put them.
SceneRegion _pickRegion(
  List<SceneRegion> candidates,
  Map<String, int> usage,
  math.Random random, {
  PropDef? prop,
  DifficultyProfile? profile,
  bool openIsFull = false,
}) {
  final camouflage = profile?.camouflage ?? 0;
  // Once the scene has had its share of loose objects in the open, the open
  // regions drop out of the draw - unless they are all this prop has, in which
  // case a prop in the open beats a prop missing from the picture.
  final cluttered = [
    for (final region in candidates)
      if (!_isOpen(region)) region,
  ];
  final drawn = openIsFull && cluttered.isNotEmpty ? cluttered : candidates;
  var total = 0.0;
  final weights = <double>[];
  for (final region in drawn) {
    var weight =
        math.sqrt(region.rect.area) / (1 + (usage[region.id] ?? 0) * 3);
    weight *= _clutterDraw[region.clutter] ?? 0.5;
    if (camouflage != 0 && prop != null) {
      // Halved at worst, one and a half times at best: enough to steer the
      // draw, never enough to close a region off.
      weight *= 1 + 0.5 * camouflage * _blend(prop.tone, region.contrast);
    }
    weights.add(weight);
    total += weight;
  }
  var pick = random.nextDouble() * total;
  for (var i = 0; i < drawn.length; i++) {
    pick -= weights[i];
    if (pick <= 0) return drawn[i];
  }
  return drawn.last;
}

/// True for a region with nothing much in it: bare floor, a clear wall panel,
/// an empty rug. A prop here has no neighbours to belong among.
bool _isOpen(SceneRegion region) => region.clutter == 'low';

/// A stretch of [region]'s surface the backdrop left empty, wide enough for a
/// prop of [width], or null where the art was never read for them.
///
/// Wider gaps come up more often, so a prop is likelier to land in the room's
/// biggest hole than to be squeezed into its smallest - which is what a person
/// tidying the shelf would do with it.
List<double>? _pickSpan(SceneRegion region, double width, math.Random random) {
  if (region.freeSpans.isEmpty) return null;
  final room = [
    for (final span in region.freeSpans)
      if (span.last - span.first >= width * _spanFit) span,
  ];
  if (room.isEmpty) return null;
  var total = 0.0;
  for (final span in room) {
    total += span.last - span.first;
  }
  var pick = random.nextDouble() * total;
  for (final span in room) {
    pick -= span.last - span.first;
    if (pick <= 0) return span;
  }
  return room.last;
}

/// One roll of the dice for one prop in one region: size, angle, spot, then
/// every rule the meta lays down. Null when this roll broke one of them.
Placement? _trySpot({
  required PropDef prop,
  required SceneRegion region,
  required PropCatalog catalog,
  required SceneMeta meta,
  required PlacementRules rules,
  required DifficultyProfile profile,
  required List<Placement> placed,
  required math.Random random,
  required int copyIndex,
  double relax = 0,
  bool findable = true,
}) {
  final places = [
    for (final place in prop.places)
      if (region.placements.contains(place)) place,
  ];
  if (places.isEmpty) return null;
  final place = places[random.nextInt(places.length)];

  // What the prop and the region between them will allow at all.
  final roomLow = math.max(prop.minWidth, region.minWidth);
  // The room's ceiling is the room's; how close to it a band may draw a prop
  // is the band's.
  var high = math.min(profile.maxWidth(prop.maxWidth), region.maxWidth);
  if (roomLow > high) return null;
  // Out in the open there is no clutter to give the prop a size to belong to,
  // so it is drawn small: a big object alone on bare floor is the reading the
  // eye calls pasted on, whatever else the placement gets right.
  if (_isOpen(region)) {
    final capped = roomLow + (high - roomLow) * _openWidthCeiling;
    // Never under the size the band can tap: belonging is a look, and a find
    // too small for the finger playing it is a broken level.
    high = math.max(capped, math.min(high, profile.minWidth));
  }
  // Then the band's say on the floor: the older bands go under the size the
  // art asked for, down to their own [DifficultyProfile.minWidth] and no
  // further. Without this a region whose range starts at 0.09 hands Hunt
  // exactly what it hands Look, whatever the band's width preferences say.
  //
  // Still capped at the ceiling, because a floor above it is not a reason to
  // refuse the prop the room - it is a reason to draw it as small as the room
  // permits.
  final low = math.min(high, profile.widthFloor(roomLow));
  // The range is still the room's and the prop's; the band only decides where
  // in it to aim, so a young player's duck is a big duck and an older one's is
  // a small one without either leaving the shelf it belongs on.
  final width = profile.width(low, high, random.nextDouble());
  final height = width * prop.aspect * catalog.aspect;

  final rotation =
      prop.rotateRange.first +
      random.nextDouble() * (prop.rotateRange.last - prop.rotateRange.first);
  final theta = radians(rotation);
  final cos = math.cos(theta).abs();
  final sin = math.sin(theta).abs();
  // Rotated art occupies a taller, wider box than the sprite: a dagger laid at
  // 45 degrees reaches further down than its upright height suggests.
  final halfWidth = width * (cos + prop.aspect * sin) / 2;
  final halfHeight = width * catalog.aspect * (sin + prop.aspect * cos) / 2;

  final rect = region.rect;
  // Where along the region this prop may stand: a gap the backdrop left, if
  // the art was read for them, and otherwise the region's whole width.
  final span = _pickSpan(region, width, random) ?? [rect.x0, rect.x1];
  // Keep the prop's middle over the region rather than hanging off its end,
  // but never demand more room than the region has.
  final inset = math.min(halfWidth * 0.6, (span.last - span.first) / 3);
  final x = _between(span.first + inset, span.last - inset, random);

  // Anything that is not hanging off the wall is standing on something, and
  // where a region says what that something is, the prop's bottom edge goes on
  // it: on the shelf board, on the bed, on the lip of the chest. Tucked in and
  // inside are no exception - a coin among the treasure still sits in the
  // chest, it does not hover over it.
  final surface = hangingPlacements.contains(place) ? null : region.restY(x);
  final y = surface != null
      ? surface - _foot(prop, catalog, width, height, theta)
      // A floor, a rug, a wall: nothing to stand on, so how far back or how
      // high the prop sits is free.
      : _between(rect.y0 + halfHeight, rect.y1 - halfHeight, random);

  // The centre has to be in the region. A prop standing on a rest line that
  // runs outside the region's box - a ledge is a line, the box around it is
  // guesswork - is still on that ledge, so it is judged at the box's edge
  // instead of being thrown out for missing it.
  if (surface == null) {
    if (!region.contains(x, y)) return null;
  } else {
    if (y < rect.y0 - _footSlack - halfHeight) return null;
    if (!region.contains(x, y.clamp(rect.y0, rect.y1))) return null;
  }

  final box = SceneRect(
    x - halfWidth,
    y - halfHeight,
    x + halfWidth,
    y + halfHeight,
  );

  final margin = rules.edgeMargin;
  if (box.x0 < margin ||
      box.y0 < margin ||
      box.x1 > 1 - margin ||
      box.y1 > 1 - margin) {
    return null;
  }
  for (final zone in meta.noGo) {
    if (box.overlaps(zone)) return null;
  }
  for (final other in placed) {
    // Spacing is measured in scene-width units, so the rule means the same
    // across the picture as it does up and down it.
    final dx = x - other.x;
    final dy = (y - other.y) / catalog.aspect;
    if (math.sqrt(dx * dx + dy * dy) < rules.minSeparation) return null;
    if (box.overlaps(_grow(_boxOf(other, catalog), _spriteGap))) return null;
  }

  // Anything drawn in front of this region may cover part of the prop. How
  // much of it a band is willing to lose decides whether this spot stands.
  final clip = _clipBehind(box, region, meta, profile, relax);
  if (clip == _tooHidden) return null;

  final id = copyIndex == 0 ? prop.id : '${prop.id}#${copyIndex + 1}';
  return Placement(
    id: id,
    prop: prop,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: rotation,
    regionId: region.id,
    place: place,
    polygon: _polygon(prop, catalog, x, y, width, height, theta),
    clip: clip,
    findable: findable,
  );
}

/// Sentinel for a spot where the scenery covers more of the prop than the band
/// allows. Distinct from null, which means nothing covers it at all.
const _tooHidden = SceneRect(0, 0, 0, 0);

/// The least of a sprite's height that may be left showing, as a fraction of
/// it. Below this what is left is a sliver rather than a thing, and a sliver
/// is not a find at any age.
const _minVisibleSide = 0.4;

/// The most of a prop a relaxed layout will accept as covered, whatever the
/// band asked for. Past this a find stops being hard and starts being absent.
const _coverCeiling = 0.6;

/// How far into the layout's retries occlusion stops being allowed to refuse a
/// spot. Nothing on a child's list may be missing from the picture, so cover
/// is the first rule to go.
const _giveUpOcclusionAt = 0.5;

/// Least of a prop that has to disappear before it counts as covered at all.
const _coverWorthHaving = 0.03;

/// How much of a prop's width an occluder has to reach across before the cut
/// is taken.
///
/// The cut is horizontal and full width - see [_behind] - so a hedge that only
/// grazes the left edge of a prop would take the prop's whole bottom away and
/// leave it sliced clean with nothing in front of the cut. Something that
/// narrow is beside the prop, not in front of it, and the placer treats it as
/// no occluder at all.
const _minCoveredWidth = 0.85;

/// What [box] has left showing once the regions drawn in front of [region]
/// have covered what they cover.
///
/// Null when nothing covers it, [_tooHidden] when more is covered than
/// [profile] allows, and otherwise the visible part in scene coordinates.
///
/// The visible part is taken as a rectangle - the largest of the four strips
/// the occluder leaves - because that is both what a clip can express and what
/// these occluders actually do: a hedge in front of a bed covers its foot and
/// leaves its head, it does not punch a hole in the middle of it.
SceneRect? _clipBehind(
  SceneRect box,
  SceneRegion region,
  SceneMeta meta,
  DifficultyProfile profile,
  double relax,
) {
  if (profile.occlusionMax <= 0 || region.occludedBy.isEmpty) return null;
  if (box.area <= 0) return null;
  // A room whose only shelf sits behind a rail would otherwise hand back an
  // empty scene: as the layout runs out of ideas it accepts more cover rather
  // than fewer objects. A band that never occludes at all is left alone, so
  // this can never introduce cover for the youngest.
  final allowance = math.max(
    profile.occlusionMax,
    math.min(_coverCeiling, relax),
  );

  // One occluder, the one that covers the most of this spot, and not the rest.
  //
  // A region's occludedBy is a list of everything drawn in front of any part
  // of it, and for a floor that is most of the room. Taking them one after
  // another whittles the visible part away to nothing and the placer ends up
  // refusing the floor altogether. What a prop is actually tucked behind is
  // one thing: the chair it is under, not the chair and the shelf and the
  // castle as well.
  SceneRect? front;
  var deepest = 0.0;
  for (final id in region.occludedBy) {
    final other = meta.region(id);
    if (other == null || !box.overlaps(other.rect)) continue;
    // Only something that reaches across the prop can take its bottom off.
    final covered =
        math.min(box.x1, other.rect.x1) - math.max(box.x0, other.rect.x0);
    if (covered < box.width * _minCoveredWidth) continue;
    final overlap = _overlapArea(box, other.rect);
    if (overlap > deepest) {
      deepest = overlap;
      front = other.rect;
    }
  }
  if (front == null) return null;

  // Past this the layout has stopped finding room and a covered prop is
  // drawn whole instead of being turned away. That is what the game did
  // before it could hide anything behind anything, so the worst case is the
  // old behaviour rather than a level with something missing off its list.
  final lastResort = relax >= _giveUpOcclusionAt;

  final visible = _behind(box, front);
  if (visible == null) return null;
  // The occluder reaches the box without really covering anything - an edge
  // grazing an edge. Recording that would cost a clip rect on every frame and
  // a hole in the tap polygon, both for a difference nobody can see.
  if (visible.area >= box.area * (1 - _coverWorthHaving)) return null;
  final tooMuch =
      visible.area <= 0 ||
      1 - visible.area / box.area > allowance ||
      visible.height < box.height * _minVisibleSide;
  if (tooMuch) return lastResort ? null : _tooHidden;
  return visible;
}

/// How much of [box] and [other] overlap, zero when they do not.
double _overlapArea(SceneRect box, SceneRect other) {
  final w = math.min(box.x1, other.x1) - math.max(box.x0, other.x0);
  final h = math.min(box.y1, other.y1) - math.max(box.y0, other.y0);
  return w <= 0 || h <= 0 ? 0 : w * h;
}

/// What [box] has showing over the top of [front], or null when the prop is
/// not behind it in the first place.
///
/// The cut is always horizontal, and always keeps the top. In a scene drawn
/// from eye level, going behind something means your feet disappear first: a
/// prop tucked behind a hedge is a prop whose bottom is gone and whose top is
/// still there. A vertical cut is what you get from slicing a sprite down the
/// middle, and it reads as broken art rather than as something half hidden -
/// which is exactly what a duck on the floorboards next to the rug looked
/// like when the widest strip was taken instead.
///
/// So the occluder has to be genuinely in front: its top edge below the prop's
/// top, and its bottom edge at or below the prop's, or it is something the
/// prop is standing on rather than something standing in front of the prop.
/// It also has to reach across the prop - see [_minCoveredWidth], which the
/// caller applies when it picks which occluder this is.
SceneRect? _behind(SceneRect box, SceneRect front) {
  if (front.y0 <= box.y0 || front.y1 < box.y1) return null;
  final visible = SceneRect(box.x0, box.y0, box.x1, front.y0);
  return visible.height <= 0 ? null : visible;
}

/// The sprite's convex hull moved into the scene: scaled to the placed size,
/// rotated the way the renderer rotates it, and centred on the placement.
///
/// Rotation happens in scene pixels, not in normalized units - a square sprite
/// is not a square fraction of a scene that is wider than it is tall - so the
/// height is carried into width units for the turn and back again after it.
/// This is the same transform `build_scene.py` used to bake polygons.
List<List<double>> _polygon(
  PropDef prop,
  PropCatalog catalog,
  double x,
  double y,
  double width,
  double height,
  double theta,
) {
  final cos = math.cos(theta);
  final sin = math.sin(theta);
  final aspect = catalog.aspect;
  return [
    for (final point in prop.silhouette)
      [
        // Local units run -0.5 to 0.5 across the sprite box.
        x + point[0] * width * cos - point[1] * (height / aspect) * sin,
        y + point[0] * (width * aspect) * sin + point[1] * height * cos,
      ],
  ];
}

/// How far the drawn art reaches below the placement's centre.
///
/// Not half the sprite's box: the box has corners and the art rarely does. A
/// fish turned thirty degrees has an empty triangle under its nose, and a prop
/// dropped by half its rotated box hangs that triangle's height above the
/// shelf - which is exactly the gap a child reads as floating. Measuring the
/// silhouette instead puts the lowest painted pixel on the rest line, whatever
/// the shape and whatever the angle.
double _foot(
  PropDef prop,
  PropCatalog catalog,
  double width,
  double height,
  double theta,
) {
  final cos = math.cos(theta);
  final sin = math.sin(theta);
  var drop = 0.0;
  for (final point in prop.silhouette) {
    // The same transform [_polygon] uses, kept to its downward half.
    final dy =
        point[0] * (width * catalog.aspect) * sin + point[1] * height * cos;
    if (dy > drop) drop = dy;
  }
  return drop;
}

SceneRect _boxOf(Placement placement, PropCatalog catalog) {
  final theta = radians(placement.rotation);
  final cos = math.cos(theta).abs();
  final sin = math.sin(theta).abs();
  final halfWidth = placement.width * (cos + placement.prop.aspect * sin) / 2;
  final halfHeight =
      placement.width *
      catalog.aspect *
      (sin + placement.prop.aspect * cos) /
      2;
  return SceneRect(
    placement.x - halfWidth,
    placement.y - halfHeight,
    placement.x + halfWidth,
    placement.y + halfHeight,
  );
}

SceneRect _grow(SceneRect rect, double by) =>
    SceneRect(rect.x0 - by, rect.y0 - by, rect.x1 + by, rect.y1 + by);

/// A point in [low, high], or the middle of a range too small to have one.
double _between(double low, double high, math.Random random) =>
    high <= low ? (low + high) / 2 : low + random.nextDouble() * (high - low);
