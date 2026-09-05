import 'dart:io';

import 'package:peepo/game/audio.dart';
import 'package:peepo/game/scene_view.dart';
import 'package:peepo/game/smoke.dart';
import 'package:peepo/main.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/level.dart';
import 'package:peepo/models/level_progress.dart';
import 'package:peepo/models/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole app, at a chosen age band, with nothing stored.
///
/// [AppSettings] built by hand keeps nothing between runs, which is what a
/// test wants, and `ageChosen` is set so the first-run age card - which only
/// ever appears before anybody has answered it - stays out of the way.
PeepoApp testApp({AgeBand band = AgeBand.look, GameAudio? audio}) => PeepoApp(
  settings: AppSettings(band: band, ageChosen: true),
  progress: LevelProgress(),
  // There is no audio device behind a widget test, so every call into the
  // plugin would throw. Silent audio never makes one, and still records
  // which track each screen asked for.
  audio: audio ?? GameAudio.silent(),
);

/// The level widget tests play. Kept equal to the level's own manifest entry
/// by a test in baked_scenes_test.dart, so this cannot drift unnoticed.
///
/// A baked level: four pictures for the younger bands and four denser ones for
/// the older, each with its finds drawn into the artwork. Which picture and
/// which of its finds a game gets is the seed's business, so a test that needs
/// a particular object on the list has to pass a seed and read the list back
/// rather than name it.
const pirateLevel = Level(
  id: 'pirate_cabin',
  name: "Captain's Cabin",
  objectCount: 12,
  maxObjects: 12,
  scenes: 4,
  thumbnailName: 'background.jpg',
  theme: 'pirate',
  variants: {
    'dense': SceneCounts(
      objectCount: 14,
      maxObjects: 14,
      scenes: 4,
      thumbnail: 'background_dense.jpg',
    ),
  },
  dir: '${LevelCatalog.levelsDir}/pirate_cabin',
);

/// The composited level the placer is tested against.
///
/// Every level the game ships is baked now - its finds are drawn into the
/// artwork - so there is no catalog left in the bundle to place. The placer is
/// still the code path any future composited level takes, so its tests run
/// against a copy of the last one the game shipped, kept here rather than in
/// `assets/` so it is never mistaken for something a player can open.
Future<String> composited(String name) =>
    File('test/fixtures/composited_$name.json').readAsString();

/// Pumps [app], if given, and waits until the scene is loaded and the smoke
/// reveal is over, so tests act on a fully drawn level. Pass nothing to wait
/// out a level that is already on screen, e.g. one just navigated to.
///
/// The screen precaches every scene image before showing anything, and real
/// image decoding only runs on the real event loop - hence [runAsync]. The
/// clock is driven by hand rather than settled: the loading state animates
/// forever, so pumpAndSettle would time out before the scene ever arrives.
Future<void> pumpSceneReady(WidgetTester tester, [Widget? app]) async {
  if (app != null) await tester.pumpWidget(app);
  bool ready() =>
      find.byType(SceneView).evaluate().isNotEmpty &&
      find.byType(SmokeCloud).evaluate().isEmpty;
  for (var attempt = 0; attempt < 60 && !ready(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(seconds: 1));
}
