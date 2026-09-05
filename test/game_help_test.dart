import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/game/game_screen.dart';
import 'package:peepo/game/scene_view.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/settings.dart';

import 'scene_pump.dart';

/// A child who is stuck does not ask for help - they put the tablet down. What
/// is checked here is that the game notices instead, at the pace the age band
/// sets, and that the oldest band is left alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(rootBundle.clear);

  Future<void> openLevel(WidgetTester tester, AgeBand band) async {
    await pumpSceneReady(
      tester,
      MaterialApp(
        home: GameScreen(
          level: pirateLevel,
          settings: AppSettings(band: band, ageChosen: true),
          seed: 7,
        ),
      ),
    );
  }

  bool hinting(WidgetTester tester) =>
      tester.widget<SceneView>(find.byType(SceneView)).hintTarget != null;

  /// Idles for [limit], a second at a time, and answers whether a hint turned
  /// up in that time. Stepped rather than jumped: a hint holds for a couple of
  /// seconds and then clears itself, so one long pump would step straight over
  /// it and report nothing had happened.
  Future<bool> hintsWithin(WidgetTester tester, Duration limit) async {
    for (var i = 0; i < limit.inSeconds; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (hinting(tester)) return true;
    }
    return false;
  }

  testWidgets('the youngest band is shown something within seconds', (
    tester,
  ) async {
    await openLevel(tester, AgeBand.peek);
    expect(hinting(tester), isFalse, reason: 'not before it is given a chance');

    await tester.pump(
      AgeBand.peek.profile.autoHintAfter! + const Duration(seconds: 1),
    );
    expect(hinting(tester), isTrue);

    // And the hint goes away again on its own, so the room is the child's.
    await tester.pump(
      AgeBand.peek.profile.hintHold + const Duration(seconds: 1),
    );
    expect(hinting(tester), isFalse);
  });

  testWidgets('an older band waits longer before stepping in', (tester) async {
    await openLevel(tester, AgeBand.seek);
    expect(
      await hintsWithin(tester, AgeBand.peek.profile.autoHintAfter!),
      isFalse,
      reason: 'soon enough for Peek is not soon enough for Seek',
    );
    expect(
      await hintsWithin(tester, AgeBand.seek.profile.autoHintAfter!),
      isTrue,
    );
  });

  testWidgets('a stuck player is helped sooner, without being told so', (
    tester,
  ) async {
    const peek = AgeBand.peek;
    final assisted = peek.profile.withAssist();
    await openLevel(tester, peek);

    // Two hints come and go with nothing found: that is what being stuck
    // looks like from outside, and it is what turns assist on.
    expect(await hintsWithin(tester, peek.profile.autoHintAfter! * 2), isTrue);
    expect(await hintsWithin(tester, peek.profile.autoHintAfter! * 2), isTrue);

    // Wait out the hint now on screen, then the next one has to arrive inside
    // the assisted wait, which is half the band's own.
    await tester.pump(assisted.hintHold + const Duration(seconds: 1));
    expect(hinting(tester), isFalse);
    expect(
      await hintsWithin(
        tester,
        assisted.autoHintAfter! + const Duration(seconds: 1),
      ),
      isTrue,
      reason: 'help did not come any sooner for a player who is stuck',
    );
  });

  testWidgets('the oldest band is left alone until it asks', (tester) async {
    await openLevel(tester, AgeBand.hunt);
    expect(await hintsWithin(tester, const Duration(minutes: 5)), isFalse);

    // The lantern still works, three times, and says how many are left.
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Hint')));
    await tester.pump();
    expect(hinting(tester), isTrue);
    expect(find.text('2'), findsOneWidget);
  });
}
