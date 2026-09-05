import 'dart:convert';
import 'dart:math' as math;

/// The description of a backdrop: what parts of the picture are what, and what
/// may be hidden where.
///
/// Written by the scene pipeline into `assets/levels/<id>/meta.json`
/// (schema in docs/scene-meta.md) and read at runtime, because placement
/// happens when the level is played, not when it is built. Everything here is
/// in normalized [0,1] scene coordinates.
///
/// Deliberately free of `dart:ui`, so the placer that reads it also runs
/// outside Flutter - see `tools/layout.dart`.
class SceneMeta {
  const SceneMeta({
    required this.sceneId,
    required this.regions,
    required this.noGo,
    required this.rules,
    this.theme,
  });

  final String sceneId;
  final String? theme;

  /// Every part of the room a prop could belong to.
  final List<SceneRegion> regions;

  /// Parts of the picture nothing may land on, whatever region covers them.
  final List<SceneRect> noGo;

  final PlacementRules rules;

  SceneRegion? region(String id) {
    for (final region in regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  factory SceneMeta.fromJsonString(String source) =>
      SceneMeta.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory SceneMeta.fromJson(Map<String, dynamic> json) => SceneMeta(
    sceneId: json['sceneId'] as String? ?? '',
    theme: json['theme'] as String?,
    regions: [
      for (final region in (json['regions'] as List? ?? []))
        SceneRegion.fromJson(region as Map<String, dynamic>),
    ],
    noGo: [
      for (final zone in (json['noGo'] as List? ?? []))
        SceneRect.fromJson((zone as Map<String, dynamic>)['rect'] as List),
    ],
    rules: PlacementRules.fromJson(
      json['placementRules'] as Map<String, dynamic>? ?? const {},
    ),
  );
}

/// An axis-aligned box in normalized scene coordinates.
class SceneRect {
  const SceneRect(this.x0, this.y0, this.x1, this.y1);

  final double x0, y0, x1, y1;

  double get width => x1 - x0;
  double get height => y1 - y0;
  double get area => width * height;

  bool contains(double x, double y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;

  bool overlaps(SceneRect other) =>
      x0 < other.x1 && other.x0 < x1 && y0 < other.y1 && other.y0 < y1;

  factory SceneRect.fromJson(List json) => SceneRect(
    (json[0] as num).toDouble(),
    (json[1] as num).toDouble(),
    (json[2] as num).toDouble(),
    (json[3] as num).toDouble(),
  );
}

/// One part of the room: a cupboard top, a stretch of wall, the floor.
class SceneRegion {
  const SceneRegion({
    required this.id,
    required this.rect,
    required this.supports,
    required this.sizeRange,
    this.polygon = const [],
    this.restLine = const [],
    this.restTolerance,
    this.freeSpans = const [],
    this.depth = 'mid',
    this.clutter = 'medium',
    this.contrast = 'medium',
    this.occludedBy = const [],
    this.kind = 'surface',
  });

  final String id;

  /// Bounding box of the region.
  final SceneRect rect;

  /// Outline inside [rect] for a region that is not box-shaped, as
  /// [x, y] pairs. Empty means the whole box counts.
  final List<List<double>> polygon;

  /// How a prop may meet this region: `rests_on`, `hangs_on`, `lies_flat`,
  /// `leans_against`, `pinned_to`, `tucked_in`, `inside`.
  final List<String> supports;

  /// Sprite widths this region can hold, as fractions of scene width. A
  /// region that holds nothing has `[0, 0]`.
  final List<double> sizeRange;

  /// The line props actually stand on inside [rect]: a single y, or a
  /// polyline of [x, y] points for a surface that runs uphill in perspective.
  /// Empty when the region has no supporting surface.
  final List<List<double>> restLine;

  /// How far off the rest line a prop may sit before it reads as floating.
  final double? restTolerance;

  /// The stretches of the rest line the backdrop has left empty, as
  /// [[x0, x1], ...] in scene coordinates.
  ///
  /// A lived-in room draws its own things on its own surfaces, and a find
  /// dropped on top of one of them is a sprite over a picture however well it
  /// is grounded. `tools/scene.sh fit --spans` reads the gaps between them off
  /// the art, and a prop placed in one arrives where the room had room.
  ///
  /// Empty means the reading found none to give - a shelf packed end to end,
  /// or a surface whose own drawn texture reads as clutter - and the region's
  /// whole width is used, as it was before any of this was measured.
  final List<List<double>> freeSpans;

  final String depth;
  final String clutter;

  /// Tone of the backdrop here: `light`, `medium` or `dark`. What decides
  /// whether a prop of a given tone pops off this region or sinks into it,
  /// which is how the older bands camouflage a find and the youngest band
  /// avoids doing so.
  final String contrast;

  /// Regions drawn in front of this one, so a prop placed here may be partly
  /// covered by them. The backdrop already holds that art, so covering a prop
  /// is a matter of not drawing the part of it that falls behind.
  final List<String> occludedBy;

  /// What this part of the room is: `surface`, `wall`, `container`, `prop`,
  /// `opening`, `structure`.
  final String kind;

  double get minWidth => sizeRange.isEmpty ? 0 : sizeRange.first;
  double get maxWidth => sizeRange.length < 2 ? 0 : sizeRange[1];

  bool get holdsSomething => maxWidth > 0 && placements.isNotEmpty;

  /// Something to stand on: a rest line, or a surface where how far back a
  /// prop sits is free, like a floor or a rug.
  bool get isGrounded => restLine.isNotEmpty || kind == 'surface';

  /// Solid everywhere the region claims to be. A plank wall is; the box drawn
  /// around a ship's wheel or a hanging net is mostly air, and only its
  /// outline says where the thing actually is.
  bool get isSolid => kind == 'wall' || polygon.isNotEmpty;

  /// The ways a prop may actually meet this region.
  ///
  /// The meta is written by eye and is generous - it will happily say a wall
  /// can be leaned on and a net can be tucked into. Both leave a prop hanging
  /// in mid-air unless the region says where its surface is, so what the meta
  /// offers is narrowed here to what can actually hold something:
  ///
  /// - resting, lying and leaning need ground: a rest line, or a surface.
  /// - hanging and pinning need something solid to hang off.
  /// - tucking in and going inside need one or the other.
  List<String> get placements => [
    for (final support in supports)
      if (footedPlacements.contains(support)
          ? isGrounded
          : hangingPlacements.contains(support)
          ? isSolid
          : isGrounded || isSolid)
        support,
  ];

  /// Height of the supporting surface at [x], or null when the region has
  /// none - a wall, or a floor where a prop may sit anywhere in depth.
  double? restY(double x) {
    if (restLine.isEmpty) return null;
    if (restLine.length == 1) return restLine.first.last;
    final points = [...restLine]..sort((a, b) => a.first.compareTo(b.first));
    if (x <= points.first.first) return points.first.last;
    if (x >= points.last.first) return points.last.last;
    for (var i = 0; i < points.length - 1; i++) {
      final (x0, y0) = (points[i].first, points[i].last);
      final (x1, y1) = (points[i + 1].first, points[i + 1].last);
      if (x0 <= x && x <= x1) {
        final span = x1 - x0;
        return span == 0 ? y0 : y0 + (x - x0) / span * (y1 - y0);
      }
    }
    return points.last.last;
  }

  /// True when ([x], [y]) is inside the region - its box, and its outline
  /// when it has one.
  bool contains(double x, double y) {
    if (!rect.contains(x, y)) return false;
    if (polygon.isEmpty) return true;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final intersects =
          (a.last > y) != (b.last > y) &&
          x < (b.first - a.first) * (y - a.last) / (b.last - a.last) + a.first;
      if (intersects) inside = !inside;
    }
    return inside;
  }

  factory SceneRegion.fromJson(Map<String, dynamic> json) {
    final rest = json['restLine'];
    return SceneRegion(
      id: json['id'] as String,
      rect: SceneRect.fromJson(json['rect'] as List),
      polygon: _points(json['polygon']),
      supports: [
        for (final support in (json['supports'] as List? ?? []))
          support as String,
      ],
      sizeRange: [
        for (final bound in (json['sizeRange'] as List? ?? const [0, 0]))
          (bound as num).toDouble(),
      ],
      restLine: rest is num
          ? [
              [0.0, rest.toDouble()],
            ]
          : _points(rest),
      restTolerance: (json['restTolerance'] as num?)?.toDouble(),
      freeSpans: _points(json['freeSpans']),
      depth: json['depth'] as String? ?? 'mid',
      clutter: json['clutter'] as String? ?? 'medium',
      contrast: _tone(json['contrast'] as String?),
      occludedBy: [
        for (final id in (json['occludedBy'] as List? ?? [])) id as String,
      ],
      kind: json['kind'] as String? ?? 'surface',
    );
  }

  /// Which of the three tones a region's `contrast` names.
  ///
  /// The build normalises this, so a shipped level always carries one of the
  /// three words. Repeated here because a meta file is data a person edits by
  /// hand between builds, and prose in it should weaken camouflage rather
  /// than silently switch it off.
  static String _tone(String? raw) {
    if (raw == null) return 'medium';
    final text = raw.toLowerCase();
    var best = 'medium';
    var at = text.length;
    for (final entry in const {
      'dark': 'dark',
      'shadow': 'dark',
      'black': 'dark',
      'navy': 'dark',
      'light': 'light',
      'bright': 'light',
      'pale': 'light',
      'white': 'light',
      'medium': 'medium',
    }.entries) {
      final index = text.indexOf(entry.key);
      if (index >= 0 && index < at) {
        at = index;
        best = entry.value;
      }
    }
    return best;
  }

  static List<List<double>> _points(dynamic json) => [
    for (final point in (json as List? ?? []))
      [((point as List)[0] as num).toDouble(), (point[1] as num).toDouble()],
  ];
}

/// Scene-wide rules every placement obeys.
class PlacementRules {
  const PlacementRules({
    this.minSeparation = 0.05,
    this.edgeMargin = 0.025,
    this.maxPerRegion,
  });

  /// Closest two finds may be, measured in scene-width units so the rule
  /// means the same horizontally and vertically.
  final double minSeparation;

  /// Border of the picture nothing may straddle.
  final double edgeMargin;

  /// Cap on finds in one region, so the eye has to travel.
  final int? maxPerRegion;

  /// The same rules, loosened by [factor] (0 = untouched, 1 = no spacing at
  /// all). The placer relaxes them rather than give up on a layout.
  PlacementRules relaxed(double factor) {
    final t = factor.clamp(0.0, 1.0);
    return PlacementRules(
      minSeparation: minSeparation * (1 - t),
      edgeMargin: edgeMargin * (1 - t * 0.5),
      maxPerRegion: maxPerRegion == null
          ? null
          : maxPerRegion! + (t * 2).round(),
    );
  }

  factory PlacementRules.fromJson(Map<String, dynamic> json) => PlacementRules(
    minSeparation: (json['minSeparation'] as num?)?.toDouble() ?? 0.05,
    edgeMargin: (json['edgeMargin'] as num?)?.toDouble() ?? 0.025,
    maxPerRegion: (json['maxPerRegion'] as num?)?.toInt(),
  );
}

/// How a prop meets a region: these three stand on the region's rest line.
const footedPlacements = {'rests_on', 'lies_flat', 'leans_against'};

/// ...and these two hold it off the ground entirely.
const hangingPlacements = {'hangs_on', 'pinned_to'};

/// Degrees to radians, for the placer and anything reading its output.
double radians(double degrees) => degrees * math.pi / 180;
