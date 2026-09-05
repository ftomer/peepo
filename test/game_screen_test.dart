import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peepo/game/audio.dart';
import 'package:peepo/models/scene.dart';

import 'scene_pump.dart';

/// The card that says [label] out loud. The level list prints a level's name
/// on the picture and leaves the object count to the screen reader, so what a
/// card promises is read off its semantics.
Finder spoken(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

void main() {
  testWidgets('the app opens on the level list and plays the level tapped', (
    tester,
  ) async {
    final audio = GameAudio.silent();
    await tester.pumpWidget(testApp(audio: audio));
    await tester.pumpAndSettle();

    expect(audio.track, GameAudio.menuTrack);

    expect(find.text('PEEPO'), findsOneWidget);
    expect(find.text("Captain's Cabin"), findsOneWidget);
    // The card counts what the level hides at the age band being played, which
    // at Look is the level exactly as it was authored. The count is spoken
    // rather than printed - the picture already tells everyone else - so it is
    // the card's semantics that carry it.
    expect(spoken("Captain's Cabin, 12 objects"), findsOneWidget);

    await tester.tap(find.text("Captain's Cabin"));
    await pumpSceneReady(tester, null);

    // Which of the room's finds a game asks for is the seed's business - the
    // picture holds more than any one game wants, and `GameScene.asked` picks
    // between them - and the list is opened here with no seed at all. So what
    // is checked is that the bar came up carrying this level's own things,
    // rather than three named ones, which was a test that failed about one run
    // in fifteen.
    final cast = <String>{};
    for (var picture = 1; picture <= pirateLevel.scenes; picture++) {
      final scene = GameScene.fromJsonString(
        await rootBundle.loadString('${pirateLevel.dir}/scene.$picture.json'),
        dir: pirateLevel.dir,
      );
      cast.addAll(scene.objects.map((object) => object.label));
    }
    final onScreen = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .where(cast.contains)
        .toSet();
    expect(
      onScreen,
      hasLength(greaterThanOrEqualTo(8)),
      reason: 'the object bar came up all but empty: $onScreen',
    );
    // The level's own track came up with the level.
    expect(audio.track, pirateLevel.id);

    // A finished level moves on to the next by replacing itself, which
    // completes the level list's own push. The list must not read that as the
    // player coming back and hand the menu track back over the top of the
    // track the next level has just asked for.
    audio.playMusic('toy_room');
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Toy Room')),
            ),
          ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toy Room'), findsOneWidget);
    expect(audio.track, 'toy_room');

    // The list does take its track back when the level is left for good.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    expect(find.text("Captain's Cabin"), findsOneWidget);
    expect(audio.track, GameAudio.menuTrack);
  });

  test('a level knows where its own assets live', () {
    // A pool of baked pictures: which one a game opens is the seed's. The card
    // shows the plate they are all stamped onto, which gives nothing away.
    expect(
      pirateLevel.sceneAssetFor(null, seed: 0),
      'assets/levels/pirate_cabin/scene.1.json',
    );
    expect(
      pirateLevel.sceneAssetFor(null, seed: 6),
      'assets/levels/pirate_cabin/scene.3.json',
    );
    expect(pirateLevel.thumbnail, 'assets/levels/pirate_cabin/background.jpg');
  });
}
