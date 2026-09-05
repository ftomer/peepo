import 'package:peepo/game/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scene_pump.dart';

/// Pumps the game at [width] logical pixels wide and lets the reveal finish.
///
/// Not [pumpSceneReady]: a resized view keeps a looping animation alive, so
/// this drives the clock by hand instead of settling.
Future<void> pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(
      home: GameScreen(level: pirateLevel, seed: _seed),
    ),
  );
  // The screen precaches every scene image first, on the real event loop.
  for (var i = 0; i < 40 && find.text(_labels.last).evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump(const Duration(seconds: 2));
}

/// One seed, so every test in this file plays the same room and asks for the
/// same list. A baked level draws more finds than a game asks for and picks
/// which by seed, so the labels on screen are the seed's answer rather than
/// the level's whole cast.
const _seed = 7;

late final List<String> _labels;

/// The chip box behind [label] - the rounded rectangle a player sees.
Finder _chipBox(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(AnimatedContainer))
    .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Each test loads the scene fresh: a bundle future cached in an earlier
  // test's fake-async zone never completes in the next one.
  setUp(rootBundle.clear);
  setUpAll(() async {
    final scene = await pirateLevel.loadScene(seed: _seed);
    _labels = [for (final group in scene.groups) group.label];
  });

  for (final width in [320.0, 400.0, 900.0, 1400.0]) {
    testWidgets('every object chip is the same size at ${width}px', (
      tester,
    ) async {
      await pumpAtWidth(tester, width);

      final first = tester.getSize(_chipBox(_labels.first));
      for (final label in _labels) {
        expect(tester.getSize(_chipBox(label)), first, reason: label);
      }
    });

    testWidgets('no label breaks mid-word at ${width}px', (tester) async {
      await pumpAtWidth(tester, width);

      for (final label in _labels) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        expect(find.text(label), findsOneWidget, reason: label);
        // A word split across lines shows up as more lines than words. The
        // text only shrinks so far, so skip labels already at the floor.
        final style = paragraph.text.style!;
        if (style.fontSize == 7.0) continue; // at the smallest size allowed
        final lineHeight = style.fontSize! * style.height!;
        final lines = (paragraph.size.height / lineHeight).round();
        final words = label.split(' ').length;
        expect(lines, lessThanOrEqualTo(words), reason: label);
      }
    });
  }
}
