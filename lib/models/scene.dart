import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../game/placement.dart';
import 'prop_catalog.dart';

/// A findable object in a scene. Coordinates are normalized [0,1]
/// relative to the scene's logical size, so the same JSON works at
/// any render resolution.
class SceneObject {
  const SceneObject({
    required this.id,
    required this.label,
    required this.sprite,
    required this.pos,
    required this.size,
    required this.rotation,
    required this.polygon,
    required this.hintCenter,
    this.clip,
    this.findable = true,
    String? chip,
    this.place,
    String? kind,
  }) : kind = kind ?? label,
       chip = chip ?? sprite;

  final String id;
  final String label;

  /// Groups copies of the same thing placed several times in one scene.
  /// Defaults to the label, so identical labels collapse into one list entry.
  final String kind;

  /// Asset path of the art drawn for this object in the scene.
  ///
  /// On a baked level this is a *stamp*: the find as the illustrator drew it,
  /// cut out of the picture with its shadow feathered, put back at the place
  /// it was drawn. The level ships the empty room once and the stamps that go
  /// on it, rather than a finished picture per layout.
  final String sprite;

  /// Asset path of the icon the object list shows. Defaults to [sprite].
  ///
  /// On a baked level it is not this copy of the thing but the prop as the
  /// illustrator drew it on the sheet: whole, upright and on nothing. The bar
  /// says what is being looked for, and this picture's copy of it is half
  /// behind a barrel - which is the puzzle, not the answer key.
  final String chip;

  /// Normalized centre of the sprite.
  final Offset pos;

  /// Normalized sprite size: width as a fraction of scene width, height as a
  /// fraction of scene height.
  final Size size;

  /// Clockwise on-screen rotation, in degrees.
  final double rotation;

  final List<Offset> polygon;
  final Offset hintCenter;

  /// The part of this object the scenery in front of it leaves showing, in
  /// normalized scene coordinates, or null when all of it shows.
  ///
  /// The backdrop already holds the thing doing the covering, so hiding part
  /// of a prop is a matter of not drawing that part. What is hidden cannot be
  /// tapped either - a target a player cannot see is not a target.
  final Rect? clip;

  /// False for a decoy: drawn like everything else, on no list, and never the
  /// answer to a tap.
  final bool findable;

  /// How this object sits in the scene - `rests_on`, `hangs_on`, and so on -
  /// or null when the scene predates placement kinds. The renderer grounds
  /// resting props with a soft contact shadow; a hanging prop gets none.
  final String? place;

  /// Whether this object stands on a surface, as opposed to hanging from or
  /// being pinned to one. Unknown placements count as hanging: no shadow is
  /// always safer than a shadow under a thing on a wall.
  bool get grounded => const {
    'rests_on',
    'lies_flat',
    'leans_against',
    'tucked_in',
    'inside',
  }.contains(place);

  /// How far the drawn art reaches below the placement's centre, in
  /// normalized scene-height units.
  ///
  /// Not half the sprite box: the box has corners and the art rarely does, and
  /// a rotated prop leaves an empty triangle under it. The placer grounds a
  /// prop by this same measure - see `_foot` in placement.dart - so it is also
  /// where the contact shadow belongs. Read off the polygon, which is the
  /// silhouette already turned and placed.
  ///
  /// A scene with no polygon to read falls back to the middle of the bottom
  /// fifth of the box, which is where the shadow sat before it was measured.
  double get foot {
    var drop = 0.0;
    for (final point in polygon) {
      final dy = point.dy - pos.dy;
      if (dy > drop) drop = dy;
    }
    final half = size.height / 2;
    return drop <= 0 ? half * 0.92 : math.min(drop, half);
  }

  /// [dir] is the level folder the scene was loaded from; sprite paths are
  /// stored relative to it so a level folder can be moved or renamed whole.
  factory SceneObject.fromJson(Map<String, dynamic> json, String dir) {
    final size = json['size'] as List;
    return SceneObject(
      id: json['id'] as String,
      label: json['label'] as String,
      sprite: _asset(dir, json['sprite'] as String),
      pos: _offset(json['pos']),
      size: Size((size[0] as num).toDouble(), (size[1] as num).toDouble()),
      rotation: ((json['rotation'] as num?) ?? 0).toDouble(),
      polygon: (json['polygon'] as List).map(_offset).toList(),
      hintCenter: _offset(json['hintCenter']),
      clip: json['clip'] == null ? null : _rect(json['clip'] as List),
      findable: json['findable'] as bool? ?? true,
      chip: json['chip'] == null ? null : _asset(dir, json['chip'] as String),
      place: json['place'] as String?,
      kind: json['kind'] as String?,
    );
  }

  /// The same object, in the room but on no list.
  SceneObject asDecoy() => SceneObject(
    id: id,
    label: label,
    kind: kind,
    sprite: sprite,
    pos: pos,
    size: size,
    rotation: rotation,
    polygon: polygon,
    hintCenter: hintCenter,
    clip: clip,
    findable: false,
    chip: chip,
    place: place,
  );

  /// Ray-casting point-in-polygon test in normalized scene coordinates.
  ///
  /// A point over the part of the object the scenery covers is not on it: what
  /// the player cannot see, the player cannot have meant.
  bool contains(Offset p) {
    if (clip != null && !clip!.contains(p)) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final intersects =
          (a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx;
      if (intersects) inside = !inside;
    }
    return inside;
  }

  /// How far [p] is from this object, in scene-width units, and zero inside
  /// it. [heightOverWidth] is the scene's shape, so a margin measured across
  /// the picture is just as generous up and down it.
  ///
  /// This is what the younger age bands' tap tolerance is measured with: a
  /// three year old aims at the duck and lands beside it.
  double distanceTo(Offset p, double heightOverWidth) {
    if (contains(p)) return 0;
    var best = double.infinity;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      best = math.min(
        best,
        _toSegment(p, polygon[j], polygon[i], heightOverWidth),
      );
    }
    // Tolerance is measured from what is on show. Without this, a partly
    // covered prop keeps a generous margin around the half of it nobody can
    // see, and the youngest bands get finds out of thin air.
    if (clip != null) {
      best = math.max(best, _toRect(p, clip!, heightOverWidth));
    }
    return best;
  }

  /// How far [p] lies outside [rect], zero inside it, in scene-width units.
  static double _toRect(Offset p, Rect rect, double heightOverWidth) {
    final dx = math.max(0.0, math.max(rect.left - p.dx, p.dx - rect.right));
    final dy =
        math.max(0.0, math.max(rect.top - p.dy, p.dy - rect.bottom)) *
        heightOverWidth;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _toSegment(
    Offset p,
    Offset a,
    Offset b,
    double heightOverWidth,
  ) {
    // Measured with y carried into width units: a normalized step down a tall
    // scene is a shorter step than the same number across it.
    double dx(Offset from, Offset to) => to.dx - from.dx;
    double dy(Offset from, Offset to) => (to.dy - from.dy) * heightOverWidth;

    final abx = dx(a, b), aby = dy(a, b);
    final apx = dx(a, p), apy = dy(a, p);
    final lengthSquared = abx * abx + aby * aby;
    final t = lengthSquared == 0
        ? 0.0
        : ((apx * abx + apy * aby) / lengthSquared).clamp(0.0, 1.0);
    final ex = apx - t * abx, ey = apy - t * aby;
    return math.sqrt(ex * ex + ey * ey);
  }
}

/// All copies of one findable thing, shown as a single object-list entry.
class ObjectGroup {
  const ObjectGroup({required this.objects});

  /// Every placement of this thing in the scene, in scene order.
  final List<SceneObject> objects;

  String get kind => objects.first.kind;
  String get label => objects.first.label;
  String get sprite => objects.first.chip;
  int get total => objects.length;

  int foundCount(Set<String> foundIds) =>
      objects.where((o) => foundIds.contains(o.id)).length;

  bool isComplete(Set<String> foundIds) => foundCount(foundIds) == total;
}

class GameScene {
  GameScene({
    required this.id,
    required this.name,
    required this.background,
    required this.size,
    required this.objects,
  });

  final String id;
  final String name;

  /// Asset path of the scene backdrop.
  final String background;

  final Size size;
  final List<SceneObject> objects;

  /// The objects that are actually on the list.
  ///
  /// Decoys are placed, drawn and hit-tested against like anything else, so
  /// [objects] is the room and this is the game: everything that counts
  /// towards finishing a level is measured against this, never the room.
  late final List<SceneObject> finds = objects
      .where((o) => o.findable)
      .toList(growable: false);

  /// Objects collapsed by kind, so a thing placed several times takes one
  /// slot in the object list. Scene order of first appearance is kept.
  late final List<ObjectGroup> groups = _buildGroups();

  List<ObjectGroup> _buildGroups() {
    final byKind = <String, List<SceneObject>>{};
    for (final object in finds) {
      byKind.putIfAbsent(object.kind, () => []).add(object);
    }
    return [for (final copies in byKind.values) ObjectGroup(objects: copies)];
  }

  factory GameScene.fromJsonString(String source, {required String dir}) =>
      GameScene.fromJson(jsonDecode(source) as Map<String, dynamic>, dir: dir);

  /// Parses a scene whose asset paths are relative to the level folder [dir],
  /// e.g. `background.jpg` and `sprites/hook.png` under
  /// `assets/levels/pirate_cabin`.
  factory GameScene.fromJson(Map<String, dynamic> json, {required String dir}) {
    final size = json['size'] as Map<String, dynamic>;
    return GameScene(
      id: json['sceneId'] as String,
      name: json['name'] as String,
      background: _asset(dir, json['background'] as String),
      size: Size((size['w'] as num).toDouble(), (size['h'] as num).toDouble()),
      objects: (json['objects'] as List)
          .map((o) => SceneObject.fromJson(o as Map<String, dynamic>, dir))
          .toList(),
    );
  }

  /// The same scene with [count] of its objects on the list and the rest left
  /// in the room as decoys, chosen by [seed].
  ///
  /// Only a baked scene needs this. Its picture is drawn once and holds every
  /// find it will ever hold, so the way a game differs from the last one is
  /// which of them it asks for - and a thing that is not asked for is not
  /// missing from the picture, it is scenery, which is exactly what a decoy is.
  ///
  /// Asking for at least as many as are drawn gives the scene back unchanged.
  GameScene asked({required int count, required int seed}) {
    final pool = [
      for (final object in objects)
        if (object.findable) object,
    ];
    if (count >= pool.length) return this;
    final order = [...pool]..shuffle(math.Random(seed));
    final wanted = {for (final object in order.take(count)) object.id};
    return GameScene(
      id: id,
      name: name,
      background: background,
      size: size,
      objects: [
        for (final object in objects)
          object.findable && !wanted.contains(object.id)
              ? object.asDecoy()
              : object,
      ],
    );
  }

  /// Builds a scene from one playthrough's [layout] of [catalog]'s props.
  ///
  /// This is the path a randomly placed level takes: the level file lists what
  /// is hidden, the placer decides where, and the result becomes an ordinary
  /// scene the renderer and the hit test know nothing special about.
  factory GameScene.fromLayout({
    required PropCatalog catalog,
    required SceneLayout layout,
    required String dir,
  }) {
    return GameScene(
      id: catalog.sceneId,
      name: catalog.name,
      background: _asset(dir, catalog.background),
      size: Size(catalog.sceneWidth, catalog.sceneHeight),
      objects: [
        for (final placement in layout.placements)
          SceneObject(
            id: placement.id,
            label: placement.prop.label,
            sprite: _asset(dir, placement.prop.sprite),
            pos: Offset(placement.x, placement.y),
            size: Size(placement.width, placement.height),
            rotation: placement.rotation,
            polygon: [
              for (final point in placement.polygon) Offset(point[0], point[1]),
            ],
            // A hint points at what is on show. On a prop tucked behind
            // the scenery that is the middle of the part still visible, not
            // the middle of the sprite, half of which is under a hedge.
            hintCenter: placement.clip == null
                ? Offset(placement.x, placement.y)
                : Offset(
                    (placement.clip!.x0 + placement.clip!.x1) / 2,
                    (placement.clip!.y0 + placement.clip!.y1) / 2,
                  ),
            clip: placement.clip == null
                ? null
                : Rect.fromLTRB(
                    placement.clip!.x0,
                    placement.clip!.y0,
                    placement.clip!.x1,
                    placement.clip!.y1,
                  ),
            findable: placement.findable,
            place: placement.place,
            // Copies of one prop share a kind, so the object list shows them
            // as a single entry with a found-of-total count.
            kind: placement.prop.id,
          ),
      ],
    );
  }

  /// How tall the scene is relative to how wide, so a margin measured across
  /// the picture means the same up and down it.
  double get heightOverWidth => size.width == 0 ? 1 : size.height / size.width;

  /// Topmost unfound object containing the normalized tap point, or null.
  ///
  /// [padding] is the age band's tap tolerance in scene-width units: a tap
  /// that misses everything still counts if it landed that close to an
  /// object. A tap that hit something exactly is settled first and front to
  /// back, so tolerance can never take a find away from the object actually
  /// under the finger.
  SceneObject? hitTest(
    Offset normalized,
    Set<String> foundIds, {
    double padding = 0,
  }) {
    for (final object in objects.reversed) {
      if (!object.findable) continue;
      if (!foundIds.contains(object.id) && object.contains(normalized)) {
        return object;
      }
    }
    if (padding <= 0) return null;
    SceneObject? nearest;
    var best = padding;
    for (final object in objects.reversed) {
      if (!object.findable) continue;
      if (foundIds.contains(object.id)) continue;
      final distance = object.distanceTo(normalized, heightOverWidth);
      if (distance <= best) {
        best = distance;
        nearest = object;
      }
    }
    return nearest;
  }
}

/// Full asset key for a scene-relative [path] inside the level folder [dir].
String _asset(String dir, String path) {
  final base = dir.endsWith('/') ? dir.substring(0, dir.length - 1) : dir;
  return base.isEmpty ? path : '$base/$path';
}

Offset _offset(dynamic json) {
  final list = json as List;
  return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
}

Rect _rect(List json) => Rect.fromLTRB(
  (json[0] as num).toDouble(),
  (json[1] as num).toDouble(),
  (json[2] as num).toDouble(),
  (json[3] as num).toDouble(),
);
