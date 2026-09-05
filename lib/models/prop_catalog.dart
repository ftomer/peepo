import 'dart:convert';

/// What a level hides, and how each thing is allowed to sit in the room -
/// everything except where it actually ends up, which is decided per playthrough
/// by the placer.
///
/// This is `assets/levels/<id>/scene.json` in its catalog form. A level may
/// instead ship fixed `objects`, which is what a hand-placed scene looks like;
/// see [GameScene.fromJson].
///
/// Free of `dart:ui` on purpose, so `tools/layout.dart` can read it outside
/// Flutter.
class PropCatalog {
  const PropCatalog({
    required this.sceneId,
    required this.name,
    required this.background,
    required this.metaFile,
    required this.sceneWidth,
    required this.sceneHeight,
    required this.props,
    required this.objectCount,
    this.decoys = const [],
  });

  final String sceneId;
  final String name;

  /// Backdrop, relative to the level folder.
  final String background;

  /// The backdrop's description, relative to the level folder.
  final String metaFile;

  final double sceneWidth;
  final double sceneHeight;

  final List<PropDef> props;

  /// Things that go in the room and are never asked for.
  ///
  /// The older bands need more sprites on the backdrop than the level has
  /// finds, and at Hunt every prop is already on the list, so there is nothing
  /// spare to draw. These are that spare art: same schema, same placement
  /// rules, never findable. A level may ship none, and most do - the props the
  /// younger bands are not asked to find serve first.
  final List<PropDef> decoys;

  /// The most this catalog can hide: every prop at its copy ceiling. What the
  /// older age bands' appetite for more objects runs into.
  int get capacity => props.fold(0, (total, prop) => total + prop.maxCopies);

  /// How many objects a playthrough hides. More than [props] means some
  /// things are placed more than once; fewer means only some of them show up.
  final int objectCount;

  /// Scene width over height, the factor that turns a fraction of the width
  /// into the same distance as a fraction of the height.
  double get aspect => sceneWidth / sceneHeight;

  factory PropCatalog.fromJsonString(String source) =>
      PropCatalog.fromJson(jsonDecode(source) as Map<String, dynamic>);

  static bool isCatalog(Map<String, dynamic> json) => json['props'] is List;

  factory PropCatalog.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;
    final props = [
      for (final prop in (json['props'] as List))
        PropDef.fromJson(prop as Map<String, dynamic>),
    ];
    return PropCatalog(
      sceneId: json['sceneId'] as String,
      name: json['name'] as String,
      background: json['background'] as String,
      metaFile: json['meta'] as String? ?? 'meta.json',
      sceneWidth: (size['w'] as num).toDouble(),
      sceneHeight: (size['h'] as num).toDouble(),
      props: props,
      objectCount: (json['objectCount'] as num?)?.toInt() ?? props.length,
      decoys: [
        for (final decoy in (json['decoys'] as List? ?? []))
          PropDef.fromJson(decoy as Map<String, dynamic>),
      ],
    );
  }
}

/// One findable thing and the freedom the placer has with it.
class PropDef {
  const PropDef({
    required this.id,
    required this.label,
    required this.sprite,
    required this.aspect,
    required this.silhouette,
    required this.places,
    required this.widthRange,
    this.regions = const [],
    this.rotateRange = const [0, 0],
    this.copies = const [1, 1],
    this.tone = 'medium',
  });

  final String id;
  final String label;

  /// Sprite path relative to the level folder.
  final String sprite;

  /// Sprite height over width, so a width picked for a region also fixes the
  /// height and the art is never stretched.
  final double aspect;

  /// Convex hull of the sprite's opaque pixels in sprite-local units, where
  /// the sprite box runs from -0.5 to 0.5 on both axes. The placer moves this
  /// into the scene to make the tap polygon.
  final List<List<double>> silhouette;

  /// How this thing can meet a region: a bottle rests or leans, it does not
  /// hang. Only a region that supports one of these can hold it.
  final List<String> places;

  /// Regions it may go in, by id. Empty means any region that supports it and
  /// is sized for it.
  final List<String> regions;

  /// Sprite widths that look right for this thing, as fractions of scene
  /// width. Intersected with each region's own range, so the same prop is
  /// smaller in a far region than a near one.
  final List<double> widthRange;

  /// Rotation the placer may give it, in degrees clockwise on screen.
  final List<double> rotateRange;

  /// How many times this thing may appear: [min, max].
  final List<int> copies;

  /// How light or dark the art is: `light`, `medium` or `dark`, measured off
  /// the sprite's own opaque pixels by the build rather than authored, so it
  /// cannot drift from the picture. Matched against a region's `contrast` to
  /// decide whether putting the prop there hides it or shows it off.
  final String tone;

  double get minWidth => widthRange.first;
  double get maxWidth => widthRange.last;
  int get minCopies => copies.first;
  int get maxCopies => copies.last;

  factory PropDef.fromJson(Map<String, dynamic> json) {
    final width = json['width'] as List;
    final rotate = json['rotate'] as List? ?? const [0, 0];
    final copies = json['copies'] as List? ?? const [1, 1];
    return PropDef(
      id: json['id'] as String,
      label: json['label'] as String,
      sprite: json['sprite'] as String,
      aspect: (json['aspect'] as num).toDouble(),
      silhouette: [
        for (final point in (json['silhouette'] as List))
          [
            ((point as List)[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          ],
      ],
      places: [for (final place in (json['places'] as List)) place as String],
      regions: [
        for (final region in (json['regions'] as List? ?? [])) region as String,
      ],
      widthRange: [(width[0] as num).toDouble(), (width[1] as num).toDouble()],
      rotateRange: [
        (rotate[0] as num).toDouble(),
        (rotate[1] as num).toDouble(),
      ],
      copies: [(copies[0] as num).toInt(), (copies[1] as num).toInt()],
      tone: json['tone'] as String? ?? 'medium',
    );
  }
}
