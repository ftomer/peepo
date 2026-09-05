import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/game/peepo.dart';

import 'scene_pump.dart';

Finder peepo(PeepoPose pose) => find.byWidgetPredicate(
  (widget) => widget is Peepo && widget.pose == pose,
  description: 'Peepo ${pose.name}',
);

void main() {
  testWidgets('every pose is a real asset', (tester) async {
    for (final pose in PeepoPose.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: Peepo(pose: pose, size: 64)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: pose.name);
      expect(
        tester.widget<Image>(find.byType(Image)).width,
        64,
        reason: pose.name,
      );
    }
  });

  testWidgets('Peepo fronts the level list and the loading smoke', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(peepo(PeepoPose.search), findsOneWidget);

    await tester.tap(find.text("Captain's Cabin"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // He is what the smoke shows while the level hides itself.
    expect(find.text('PEEPO IS HIDING'), findsOneWidget);
    expect(peepo(PeepoPose.search), findsWidgets);
  });
}
