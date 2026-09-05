import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/game/audio.dart';
import 'package:peepo/game/settings_screen.dart';
import 'package:peepo/models/level.dart';
import 'package:peepo/models/level_progress.dart';
import 'package:peepo/models/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sound is a build artefact of `tools/audio.sh`, and the one way it goes
/// wrong is by not being built: a level ships, its track does not, and the
/// level plays in silence with nothing to say so. So the files are checked
/// against the level catalog here, where a missing one is a red test rather
/// than something a grown-up notices in a waiting room.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<int> bundled(String asset) async =>
      (await rootBundle.load(asset)).lengthInBytes;

  group('the files are all there', () {
    test('every level in the catalog has a track of its own', () async {
      final catalog = await LevelCatalog.load();
      expect(catalog.levels, isNotEmpty);
      for (final level in catalog.levels) {
        expect(
          await bundled('assets/audio/music/${level.id}.mp3'),
          greaterThan(0),
          reason:
              'no music for ${level.id} - run tools/audio.sh music '
              '${level.id}',
        );
      }
    });

    test('the level list has one too', () async {
      expect(
        await bundled('assets/audio/music/${GameAudio.menuTrack}.mp3'),
        greaterThan(0),
      );
    });

    test('every cue the game can play is in the bundle', () async {
      for (final cue in Sfx.values) {
        expect(
          await bundled('assets/${cue.source}'),
          greaterThan(0),
          reason: 'no ${cue.file} - run tools/audio.sh sfx',
        );
      }
    });
  });

  group('Sfx', () {
    test('the stars ring in order, and a fourth one cannot be asked for', () {
      expect(Sfx.star(1), Sfx.star1);
      expect(Sfx.star(2), Sfx.star2);
      expect(Sfx.star(3), Sfx.star3);
      // The rating never leaves one to three, but a cue that threw would take
      // the level-complete card down with it if it ever did.
      expect(Sfx.star(0), Sfx.star1);
      expect(Sfx.star(9), Sfx.star3);
    });

    test(
      'paths are relative to the asset folder, the way audioplayers wants',
      () {
        expect(Sfx.found.source, 'audio/sfx/found.wav');
      },
    );
  });

  group('GameAudio.silent', () {
    test('takes every instruction and touches no plugin', () async {
      // There is no audio device behind a test, so anything reaching the
      // plugin throws MissingPluginException. Nothing here may.
      final audio = GameAudio.silent();
      audio.playMusic('pirate_cabin');
      audio.play(Sfx.found);
      audio.stopMusic();
      await audio.warm();
      await audio.dispose();
      // Disposing twice happens when a test tears down an app it also popped.
      await audio.dispose();
    });
  });

  group('the sound switches', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a fresh install has both on', () async {
      final settings = await AppSettings.load();
      expect(settings.music, isTrue);
      expect(settings.soundEffects, isTrue);
    });

    test(
      'turning either off outlives the app, and they are independent',
      () async {
        (await AppSettings.load()).music = false;

        final reopened = await AppSettings.load();
        expect(reopened.music, isFalse);
        expect(reopened.soundEffects, isTrue);
      },
    );

    testWidgets('are both on the grown-up screen, and work', (tester) async {
      final settings = AppSettings(ageChosen: true);
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            settings: settings,
            progress: LevelProgress(),
            audio: GameAudio.silent(),
          ),
        ),
      );

      // The screen is a list and a landscape phone is short, so the sound
      // section is under the fold: scroll to each switch the way a grown-up
      // would have to.
      Future<void> flip(String label) async {
        await tester.scrollUntilVisible(find.text(label), 80);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await flip('Music');
      expect(settings.music, isFalse);
      expect(settings.soundEffects, isTrue);

      await flip('Sound effects');
      expect(settings.soundEffects, isFalse);
    });

    test('the switches tell whoever is listening', () async {
      final settings = await AppSettings.load();
      var told = 0;
      settings.addListener(() => told++);

      settings.music = false;
      settings.soundEffects = false;
      expect(told, 2);

      // Setting a switch to what it already is changes nothing and says
      // nothing, so the audio does not restart a track over a rebuild.
      settings.music = false;
      expect(told, 2);
    });
  });
}
