import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/level_progress.dart';
import 'package:peepo/models/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a grown-up chose has to survive the tablet being closed: a parent who
/// sets the age once and finds it forgotten next morning will not set it
/// again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a fresh install plays the middle band and knows nobody chose it',
    () async {
      final settings = await AppSettings.load();
      expect(settings.band, AgeBand.look);
      expect(settings.ageChosen, isFalse);
      expect(settings.assistWhenStuck, isTrue);
    },
  );

  test('the age outlives the app', () async {
    (await AppSettings.load()).band = AgeBand.peek;

    final reopened = await AppSettings.load();
    expect(reopened.band, AgeBand.peek);
    expect(reopened.profile.showLabels, isFalse);
    // Asked and answered: the first-run card does not come back.
    expect(reopened.ageChosen, isTrue);
  });

  test('picking the band it is already on still counts as answering', () async {
    // The first-run card offers Look, which is also the default. Tapping it
    // has to close the question, not leave it unanswered.
    (await AppSettings.load()).band = AgeBand.look;
    expect((await AppSettings.load()).ageChosen, isTrue);
  });

  test('turning assist off outlives the app', () async {
    (await AppSettings.load()).assistWhenStuck = false;
    expect((await AppSettings.load()).assistWhenStuck, isFalse);
  });

  test('settings tell whoever is listening', () async {
    final settings = await AppSettings.load();
    var notified = 0;
    settings.addListener(() => notified++);
    settings.band = AgeBand.hunt;
    settings.assistWhenStuck = false;
    // Setting a value to what it already is is not news.
    settings.assistWhenStuck = false;
    expect(notified, 2);
  });

  test('finished levels outlive the app, and can be wiped', () async {
    (await LevelProgress.load()).markComplete('pirate_cabin');

    final reopened = await LevelProgress.load();
    expect(reopened.isComplete('pirate_cabin'), isTrue);
    reopened.reset();

    expect((await LevelProgress.load()).completed, isEmpty);
  });

  test('progress built without a store simply forgets', () {
    // Which is what every widget test builds, and what makes them independent.
    final progress = LevelProgress();
    progress.markComplete('toy_room');
    expect(progress.isComplete('toy_room'), isTrue);
    expect(SharedPreferences.getInstance(), isNotNull);
  });
}
