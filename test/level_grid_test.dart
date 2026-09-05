import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/models/level.dart';

import 'scene_pump.dart';

/// The home screen has to hold the whole catalog at a glance, on a landscape
/// phone and on a tablet alike - two very different shapes. The grid picks its
/// columns for the screen it is on rather than from a fixed card width, and
/// what follows is the promise that rule makes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Each case loads the manifest and four backdrops afresh: a bundle future
  // held from an earlier test's zone never completes in the next one.
  setUp(rootBundle.clear);

  for (final device in const {
    'a landscape phone': Size(1344, 621),
    'a tablet': Size(1376, 1032),
    'a tall window': Size(700, 1100),
  }.entries) {
    testWidgets('every level card is on screen on ${device.key}', (
      tester,
    ) async {
      // The home screen is the one screen a child has to take in at a glance,
      // and a level whose card is below the fold is a level they do not know
      // is there. The grid picks its columns for the screen it is on - see
      // _GridShape - so this is the promise that rule is making.
      await tester.binding.setSurfaceSize(device.value);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final catalog = await LevelCatalog.load();
      await tester.pumpWidget(testApp());
      // The list reads the manifest off the bundle, which only resolves on the
      // real event loop; settling instead would wait on the spinner it shows
      // in the meantime, which turns forever.
      for (
        var i = 0;
        i < 40 && find.text(catalog.levels.last.name).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 400));

      final screen = Offset.zero & device.value;
      for (final level in catalog.levels) {
        final card = find.text(level.name);
        expect(card, findsOneWidget, reason: level.name);
        final box = tester.getRect(card);
        expect(
          screen.contains(box.topLeft),
          isTrue,
          reason: '${level.name} starts off screen at $box',
        );
        expect(
          screen.contains(box.bottomRight),
          isTrue,
          reason: '${level.name} runs off screen at $box',
        );
      }
    });
  }

  testWidgets('four levels are laid out two by two on a tablet', (
    tester,
  ) async {
    // Not three and one with a hole beside it, which is what sizing the cards
    // by the row alone gives: two by two only looks too big for the screen
    // until the cards are allowed to shrink into it.
    await tester.binding.setSurfaceSize(const Size(1376, 1032));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final catalog = await LevelCatalog.load();
    await tester.pumpWidget(testApp());
    for (
      var i = 0;
      i < 40 && find.text(catalog.levels.last.name).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));

    final tops = {
      for (final level in catalog.levels)
        level.name: tester.getRect(find.text(level.name)).top.round(),
    };
    expect(
      tops.values.toSet(),
      hasLength(2),
      reason: 'four levels should sit in two rows, not $tops',
    );
  });
}
