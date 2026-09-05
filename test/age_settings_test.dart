import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/game/audio.dart';
import 'package:peepo/game/level_select_screen.dart';
import 'package:peepo/game/settings_screen.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/level_progress.dart';
import 'package:peepo/models/settings.dart';

import 'scene_pump.dart';

/// Pumps until the screen has stopped moving.
///
/// Not `pumpAndSettle`: the level list spins a loading indicator until the
/// catalog is read off the real bundle, which only advances on the real event
/// loop, and a spinner never settles.
/// Pass [until] to keep pumping until something is on screen - reading the
/// level catalog off the bundle takes as long as it takes.
Future<void> settle(WidgetTester tester, [Finder? until]) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    if (until != null && until.evaluate().isNotEmpty) break;
    if (until == null && i >= 5) break;
  }
}

/// The age is the one setting the whole game hangs off, so the ways in to it
/// are checked here: asked once on the first launch, and behind a gate a child
/// cannot pass after that.
void main() {
  // Each test loads the level catalog off the bundle for itself. The bundle
  // caches the futures it hands out, and a future created inside a test that
  // has since ended never completes in the next one - so the cache goes.
  setUp(rootBundle.clear);

  Widget home(AppSettings settings, [LevelProgress? progress]) => MaterialApp(
    home: LevelSelectScreen(
      settings: settings,
      progress: progress ?? LevelProgress(),
      audio: GameAudio.silent(),
    ),
  );

  testWidgets('the first launch asks who is playing', (tester) async {
    final settings = AppSettings();
    await tester.pumpWidget(home(settings));
    await settle(tester, find.text('Who is playing?'));

    expect(find.text('Who is playing?'), findsOneWidget);
    for (final band in AgeBand.values) {
      // The badge stacks the age over "yrs", so the age alone is the text.
      expect(find.text(band.ageLabel), findsWidgets);
    }

    await tester.tap(find.text('Peek'));
    await settle(tester);

    expect(settings.band, AgeBand.peek);
    expect(settings.ageChosen, isTrue);
    expect(find.text('Who is playing?'), findsNothing);
  });

  testWidgets('all four bands fit on a landscape phone', (tester) async {
    // An iPhone held the way the game locks it: 852 x 393 logical pixels is
    // the least height the card ever gets, and it used to crop the first and
    // last band off the top and bottom.
    tester.view.physicalSize = const Size(852 * 3, 393 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(home(AppSettings()));
    await settle(tester, find.text('Who is playing?'));

    final screen = tester.getRect(find.byType(MaterialApp));
    final card = find.byType(InkWell);
    Rect boxOf(AgeBand band) => tester.getRect(
      find.ancestor(of: find.text(band.label), matching: card),
    );

    // The top of the card is the greeting, and it may not eat the screen: the
    // first pair of bands has to be whole and readable before a finger moves.
    for (final band in [AgeBand.peek, AgeBand.look]) {
      final box = boxOf(band);
      expect(
        screen.contains(box.topLeft) && screen.contains(box.bottomRight),
        isTrue,
        reason: '${band.label} is cut off at $box on $screen',
      );
    }

    // The rest are a scroll away rather than lost off the edge. The test font
    // is squarer than the real one, so the later pair may or may not need the
    // scroll on a device - either way they are reachable and whole.
    for (final band in [AgeBand.seek, AgeBand.hunt]) {
      await tester.scrollUntilVisible(
        find.text(band.label),
        60,
        scrollable: find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      final box = boxOf(band);
      expect(
        screen.contains(box.topLeft) && screen.contains(box.bottomRight),
        isTrue,
        reason: '${band.label} stays cut off at $box on $screen',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('and never asks again', (tester) async {
    await tester.pumpWidget(
      home(AppSettings(band: AgeBand.seek, ageChosen: true)),
    );
    await settle(tester, find.text('8-10 yrs'));
    expect(find.text('Who is playing?'), findsNothing);
    // The band is on show instead, as the way back in to change it, and it
    // says what the numbers count.
    expect(find.text('8-10 yrs'), findsOneWidget);
  });

  testWidgets('the settings are behind a sum a child cannot do', (
    tester,
  ) async {
    final settings = AppSettings(ageChosen: true);
    await tester.pumpWidget(home(settings));
    await settle(tester, find.text('5-7 yrs'));

    await tester.tap(find.text('5-7 yrs'));
    await settle(tester);

    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('Grown-ups'), findsNothing, reason: 'settings are shut');

    // A wrong answer says so and leaves the gate standing - but the sum it is
    // standing on is a different one, so guessing at four buttons never pays.
    final asked = _question(tester);
    await _tapAnswer(tester, correct: false);
    expect(find.text('Not quite - here is another one.'), findsOneWidget);
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(_question(tester), isNot(asked), reason: 'no second try at one sum');

    await _tapAnswer(tester, correct: true);
    await settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('changing the age changes what the levels promise', (
    tester,
  ) async {
    final settings = AppSettings(band: AgeBand.look, ageChosen: true);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(settings: settings, progress: LevelProgress()),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Peek'));
    await settle(tester);
    expect(settings.band, AgeBand.peek);

    await tester.pumpWidget(home(settings));
    // The cabin hides twelve things at Look and six at Peek, and the card says
    // which it is rather than what the picture holds. It says it out loud: the
    // count is on the card's semantics, not printed on the picture.
    final promise = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == "Captain's Cabin, 6 objects",
    );
    await settle(tester, promise);
    expect(promise, findsOneWidget);
  });

  testWidgets('starting over is asked twice before anything is lost', (
    tester,
  ) async {
    final progress = LevelProgress(completed: {'pirate_cabin'});
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: AppSettings(ageChosen: true),
          progress: progress,
        ),
      ),
    );
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Start the levels over'), 120);
    await tester.tap(find.text('Start the levels over'));
    await settle(tester);
    await tester.tap(find.text('Keep it'));
    await settle(tester);
    expect(progress.isComplete('pirate_cabin'), isTrue);

    await tester.tap(find.text('Start the levels over'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Start over'));
    await settle(tester);
    expect(progress.completed, isEmpty);
  });

  testWidgets('the pre-reading band plays with pictures and no words', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(band: AgeBand.peek));
    await settle(tester, find.text("Captain's Cabin"));

    await tester.tap(find.text("Captain's Cabin"));
    await pumpSceneReady(tester, null);

    // Chips are still there - the sprites are in the bar - but a player who
    // cannot read is not asked to.
    expect(find.text('Gold Coin'), findsNothing);
    expect(find.text('Pirate Hat'), findsNothing);
  });

  testWidgets('an older band gets the words, and a hint allowance', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(band: AgeBand.hunt));
    await settle(tester, find.text("Captain's Cabin"));

    await tester.tap(find.text("Captain's Cabin"));
    await pumpSceneReady(tester, null);

    // Which of the cabin's things this game asks for is the seed's business -
    // a baked picture holds more than any one game wants - so what is checked
    // is that the chips carry words at all.
    expect(
      const [
        'Parrot',
        'Gold Coin',
        'Treasure Map',
        'Pirate Hat',
        'Telescope',
        'Anchor',
        'Starfish',
        'Shell',
        'Lantern',
        'Little Boat',
        'Octopus',
        'Fish',
      ].any((label) => find.text(label).evaluate().isNotEmpty),
      isTrue,
      reason: 'the older bands read the object list',
    );
    // Three hints, counted on the lantern.
    expect(find.text('3'), findsOneWidget);
  });
}

/// The sum the gate is currently asking, e.g. `"27 + 31"`.
String _question(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(' + '),
      ),
    )
    .data!;

/// Answers the gate's sum, right or wrong, by reading the question off it.
Future<void> _tapAnswer(WidgetTester tester, {required bool correct}) async {
  final parts = _question(tester).split(' + ');
  final answer = int.parse(parts[0]) + int.parse(parts[1]);
  final options = find.descendant(
    of: find.byType(OutlinedButton),
    matching: find.byType(Text),
  );
  for (final element in options.evaluate()) {
    final text = (element.widget as Text).data!;
    if ((int.parse(text) == answer) == correct) {
      await tester.tap(find.byWidget(element.widget));
      await tester.pump();
      return;
    }
  }
  fail('no ${correct ? 'correct' : 'wrong'} answer on the gate');
}
