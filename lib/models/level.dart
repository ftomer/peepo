import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../game/placement.dart';
import 'difficulty.dart';
import 'prop_catalog.dart';
import 'scene.dart';
import 'scene_meta.dart';

/// What one scene hides: the number it was authored with, and the most it can
/// ever hold with every prop at its copy ceiling.
///
/// The older age bands ask for more than the authored count, and a scene whose
/// props each appear once has nothing more to give. Both numbers are written
/// by the scene pipeline so the level list knows them without opening a scene
/// file.
class SceneCounts {
  const SceneCounts({
    required this.objectCount,
    required this.maxObjects,
    this.scenes = 1,
    this.thumbnail,
  });

  final int objectCount;
  final int maxObjects;

  /// How many pictures this scene ships. More than one is a pool: a baked
  /// scene cannot move its finds, so it is drawn several times over and one of
  /// them is picked per playthrough. Numbered from 1 in the file names.
  final int scenes;

  /// The backdrop the level card shows, when it is not the plain one.
  final String? thumbnail;

  factory SceneCounts.fromJson(Map<String, dynamic> json, {int? fallback}) {
    final count = (json['objectCount'] as num?)?.toInt() ?? fallback ?? 0;
    return SceneCounts(
      objectCount: count,
      maxObjects: (json['maxObjects'] as num?)?.toInt() ?? count,
      scenes: (json['scenes'] as num?)?.toInt() ?? 1,
      thumbnail: json['thumbnail'] as String?,
    );
  }
}

/// One playable level: a folder under `assets/levels/` holding everything the
/// level needs.
///
///     assets/levels/pirate_cabin/
///       scene.json        the level, paths inside relative to this folder
///       meta.json         what the backdrop is made of, for the placer
///       background.jpg    the backdrop
///       sprites/*.png     one per findable object
///
/// Nothing outside the folder is level-specific, so a level can be added,
/// renamed or dropped by moving its folder (plus its two `pubspec.yaml` asset
/// lines, which `tools/scene.sh build` maintains).
class Level {
  const Level({
    required this.id,
    required this.name,
    required this.objectCount,
    required this.dir,
    this.theme,
    this.variants = const {},
    this.scenes = 1,
    this.thumbnailName,
    int? maxObjects,
  }) : maxObjects = maxObjects ?? objectCount;

  /// Folder name under `assets/levels/`, and the level's stable key.
  final String id;

  /// Player-facing name, e.g. "Captain's Cabin".
  final String name;

  /// How many objects the scene hides, so the level list can say so without
  /// parsing every scene file at startup.
  final int objectCount;

  /// The most this level can ever hide: every prop at its copy ceiling.
  ///
  /// The older age bands ask for more than the authored [objectCount], and
  /// this is where that stops. Written by the scene pipeline so the level list
  /// knows it without opening a scene file.
  final int maxObjects;

  /// How many pictures the authored scene ships; see [SceneCounts.scenes].
  final int scenes;

  /// The backdrop the level card shows, relative to the level folder.
  final String? thumbnailName;

  /// Art direction of the level, e.g. `pirate`. Informational.
  final String? theme;

  /// Folder this level lives in, without a trailing slash.
  final String dir;

  /// Extra backdrops this level ships beyond the authored one, by name, each
  /// with what that scene hides.
  ///
  /// A level is drawn for the middle bands, and the same picture cannot be
  /// both calm enough for a three year old and busy enough for an eleven year
  /// old. A variant is a second backdrop with its own room description over
  /// the same sprites and the same find list - see
  /// [DifficultyProfile.sceneVariant] for which band asks for which.
  ///
  /// The counts are the variant's own. A variant hides the same things as the
  /// scene it varies, but not always as many copies of them: its room is
  /// busier, so its regions hold a different number. The level card reads
  /// them, and a card promising the base scene's count in front of a variant
  /// is a card that lies.
  ///
  /// Empty is the normal case and always will be for some levels: a level with
  /// no variant is played by every band exactly as it was authored.
  final Map<String, SceneCounts> variants;

  /// What the authored scene hides.
  SceneCounts get counts => SceneCounts(
    objectCount: objectCount,
    maxObjects: maxObjects,
    scenes: scenes,
    thumbnail: thumbnailName,
  );

  /// The scene [band] plays: the variant it asks for if this level ships one,
  /// and the authored scene otherwise.
  ///
  /// A scene that ships a pool of pictures picks one by [seed], so a level
  /// whose finds are painted into the artwork still opens on a different room
  /// each time it is played.
  String sceneAssetFor(DifficultyProfile? band, {int? seed}) {
    final variant = band?.sceneVariant;
    final counts = variant == null || !variants.containsKey(variant)
        ? this.counts
        : variants[variant]!;
    final name = variant == null || !variants.containsKey(variant)
        ? 'scene'
        : 'scene.$variant';
    if (counts.scenes <= 1) return '$dir/$name.json';
    final pick = (seed ?? 0).abs() % counts.scenes + 1;
    return '$dir/$name.$pick.json';
  }

  /// What the scene [band] is handed hides, which on a level that ships a
  /// denser backdrop for the older bands is not what the authored one holds.
  SceneCounts countsFor(DifficultyProfile? band) {
    final variant = band?.sceneVariant;
    return variant == null ? counts : variants[variant] ?? counts;
  }

  /// How many things this level hides for [band], counted off the scene that
  /// band actually plays.
  int objectCountFor(DifficultyProfile? band) {
    final scene = countsFor(band);
    return (band ?? DifficultyProfile.fallback).objectCount(
      scene.objectCount,
      capacity: scene.maxObjects,
    );
  }

  String get sceneAsset => '$dir/scene.json';

  /// The backdrop doubles as the level-select thumbnail, and the card shows
  /// the room the player will actually be given.
  String thumbnailFor(DifficultyProfile? band) {
    final variant = band?.sceneVariant;
    if (variant == null || !variants.containsKey(variant)) return thumbnail;
    return '$dir/${variants[variant]!.thumbnail ?? 'background_$variant.jpg'}';
  }

  String get thumbnail => '$dir/${thumbnailName ?? 'background.jpg'}';

  factory Level.fromJson(
    Map<String, dynamic> json, {
    String levelsDir = LevelCatalog.levelsDir,
  }) {
    final id = json['id'] as String;
    return Level(
      id: id,
      name: json['name'] as String,
      objectCount: (json['objectCount'] as num?)?.toInt() ?? 0,
      maxObjects: (json['maxObjects'] as num?)?.toInt(),
      scenes: (json['scenes'] as num?)?.toInt() ?? 1,
      thumbnailName: json['thumbnail'] as String?,
      theme: json['theme'] as String?,
      variants: _variants(json),
      dir: '$levelsDir/$id',
    );
  }

  String get metaAsset => '$dir/meta.json';

  /// Reads the manifest's `variants`, which is a map of variant name to what
  /// that scene hides. A bare list of names is read too, for a manifest
  /// written before the counts were: such a variant is taken to hide what its
  /// level does, which is what the level list assumed back then anyway.
  static Map<String, SceneCounts> _variants(Map<String, dynamic> json) {
    final variants = json['variants'];
    final count = (json['objectCount'] as num?)?.toInt() ?? 0;
    final base = SceneCounts(
      objectCount: count,
      maxObjects: (json['maxObjects'] as num?)?.toInt() ?? count,
    );
    if (variants is List) {
      return {for (final name in variants) name as String: base};
    }
    if (variants is Map<String, dynamic>) {
      return {
        for (final entry in variants.entries)
          entry.key: SceneCounts.fromJson(
            entry.value as Map<String, dynamic>,
            fallback: base.objectCount,
          ),
      };
    }
    return const {};
  }

  /// Reads this level's scene, with its asset paths resolved against the level
  /// folder.
  ///
  /// A level file comes in two shapes. A catalog lists what the level hides
  /// and leaves where to [layoutScene], which picks a fresh layout per
  /// playthrough - pass a [seed] to replay one. A level that instead ships
  /// fixed `objects` is hand-placed and is loaded as written.
  /// [profile] is the age band the level is hidden for: it decides how many
  /// props are placed, how big and how far apart. Left out, a level is hidden
  /// the way it was authored.
  Future<GameScene> loadScene({
    AssetBundle? bundle,
    int? seed,
    DifficultyProfile? profile,
  }) async {
    final assets = bundle ?? rootBundle;
    // Written out rather than `1 << 32`, which truncates to 0 on web and makes
    // nextInt throw.
    final roll = seed ?? Random().nextInt(0xFFFFFFFF);
    final json =
        jsonDecode(await assets.loadString(sceneAssetFor(profile, seed: roll)))
            as Map<String, dynamic>;
    if (!PropCatalog.isCatalog(json)) {
      // A baked picture holds more finds than any one game asks for, so which
      // of them are on the list is this playthrough's own question: the rest
      // stay in the room as decoys. That is what keeps a level with painted-in
      // finds from being the same hunt twice, on top of the picture itself
      // being one of several.
      return GameScene.fromJson(
        json,
        dir: dir,
      ).asked(count: objectCountFor(profile), seed: roll);
    }
    final catalog = PropCatalog.fromJson(json);
    final meta = SceneMeta.fromJsonString(
      await assets.loadString('$dir/${catalog.metaFile}'),
    );
    return GameScene.fromLayout(
      catalog: catalog,
      layout: layoutScene(
        catalog: catalog,
        meta: meta,
        profile: profile,
        // A new room every time the level is opened, and the same room for
        // anyone replaying a given seed.
        // Written out rather than `1 << 32`, which truncates to 0 on web
        // and makes nextInt throw.
        seed: roll,
      ),
      dir: dir,
    );
  }
}

/// Every level the app ships, in play order.
///
/// The catalog is a small manifest listing the level folders; it is written by
/// the scene pipeline, so adding a level never means editing Dart.
class LevelCatalog {
  const LevelCatalog({required this.levels});

  static const levelsDir = 'assets/levels';
  static const manifestAsset = '$levelsDir/levels.json';

  final List<Level> levels;

  Level get first => levels.first;

  bool get isEmpty => levels.isEmpty;

  /// The level after [level] in play order, or null if it is the last one.
  Level? after(Level level) {
    final index = levels.indexWhere((l) => l.id == level.id);
    if (index < 0 || index + 1 >= levels.length) return null;
    return levels[index + 1];
  }

  Level? byId(String id) {
    for (final level in levels) {
      if (level.id == id) return level;
    }
    return null;
  }

  static Future<LevelCatalog> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(manifestAsset);
    return LevelCatalog.fromJsonString(source);
  }

  factory LevelCatalog.fromJsonString(String source, {String dir = levelsDir}) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return LevelCatalog(
      levels: [
        for (final level in json['levels'] as List)
          Level.fromJson(level as Map<String, dynamic>, levelsDir: dir),
      ],
    );
  }
}
