// Proves the sound is real: that the app on a device actually opens the track
// under the screen it is on, and swaps it for the level's own when a level is
// tapped.
//
// A widget test cannot show this - there is no audio device behind one, so it
// runs against GameAudio.silent(). Here the plugin is live, and it leaves a
// trace: audioplayers copies each asset it is given out of the bundle and into
// the app's cache before playing it, so what is in that cache is exactly what
// has been played.
//
// Takes a few minutes: it builds the app and waits out a scene load. It is a
// hand-run check, not part of `flutter test`.
//
//   flutter test integration_test/audio_smoke_test.dart -d macos
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peepo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Every asset audioplayers has been asked to play, by bundle path.
  ///
  /// Read off the cache this run is using rather than off the disk. The cache
  /// folder is named with a fresh uuid per run and nothing deletes the last
  /// one, so a walk of the caches directory would find every track played on
  /// every previous run and pass whether or not this run made a sound.
  Set<String> played() {
    return {
      for (final loaded in AudioCache.instance.loadedFiles.entries)
        // The entry goes in once the bytes are on disk, and the file is what
        // the platform player is handed: if it is there, it was played.
        if (File.fromUri(loaded.value).existsSync()) loaded.key,
    };
  }

  /// Waits for [want] to turn up, or gives up loudly. Starting a track is
  /// several hops of platform channel, so it is never true on the next frame.
  Future<void> waitFor(WidgetTester tester, String want) async {
    for (var i = 0; i < 100; i++) {
      if (played().contains(want)) return;
      await tester.pump(const Duration(milliseconds: 100));
      sleep(const Duration(milliseconds: 100));
    }
    fail('$want never played. Played: ${played().toList()..sort()}');
  }

  testWidgets('the level list plays its track, and a level plays its own', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await waitFor(tester, 'audio/music/menu.mp3');
    // Warmed on the level list, so that the first find of the first level is
    // not the one find that arrives late.
    await waitFor(tester, 'audio/sfx/found.wav');

    await tester.tap(find.text("Captain's Cabin"));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await waitFor(tester, 'audio/music/pirate_cabin.mp3');
  });
}
