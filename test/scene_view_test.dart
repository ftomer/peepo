import 'package:peepo/game/scene_view.dart';
import 'package:peepo/models/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two props of the same size, one tucked behind scenery and one in the open,
/// so what the clip does to a find can be read off the pair. The art is the
/// cabin's, because a widget test still has to load real assets - and the
/// cabin is baked now, so what it has to lend is a picture and two chips.
///
/// The scene is 1600 x 1000 and so is the test window, which makes the cover
/// fit exact: one normalized unit down the scene is a thousand pixels.
const _sceneJson = '''
{
  "sceneId": "test_01",
  "name": "Test Scene",
  "background": "background.jpg",
  "size": { "w": 1600, "h": 1000 },
  "objects": [
    {
      "id": "parrot",
      "label": "Open",
      "sprite": "baked/1_parrot.png",
      "pos": [0.25, 0.5],
      "size": [0.1, 0.1],
      "rotation": 0,
      "place": "rests_on",
      "polygon": [[0.2, 0.45], [0.3, 0.45], [0.3, 0.53], [0.2, 0.53]],
      "hintCenter": [0.25, 0.5]
    },
    {
      "id": "gold_coin",
      "label": "Tucked",
      "sprite": "baked/1_gold_coin.png",
      "pos": [0.75, 0.5],
      "size": [0.1, 0.1],
      "rotation": 0,
      "place": "rests_on",
      "polygon": [[0.7, 0.45], [0.8, 0.45], [0.8, 0.53], [0.7, 0.53]],
      "hintCenter": [0.75, 0.48],
      "clip": [0.7, 0.45, 0.8, 0.5]
    }
  ]
}
''';

Finder _sprite(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName.endsWith('$name.png'),
);

/// What the sprite is being drawn at right now, read off the transition the
/// fade is running rather than off the target it is heading for.
double _opacityOf(WidgetTester tester, String name) {
  final fade = find
      .ancestor(of: _sprite(name), matching: find.byType(FadeTransition))
      .first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScene(
    WidgetTester tester,
    Set<String> found, {
    double opacity = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SceneView(
          scene: GameScene.fromJsonString(
            _sceneJson,
            dir: 'assets/levels/pirate_cabin',
          ),
          foundIds: found,
          onSceneTap: (_) {},
          spriteOpacity: opacity,
        ),
      ),
    );
  }

  testWidgets('a prop found behind scenery is celebrated like any other', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScene(tester, const {});
    expect(_opacityOf(tester, 'gold_coin'), 1.0);
    expect(_opacityOf(tester, 'parrot'), 1.0);

    // Finding a covered prop takes its clip off, which is what lets the
    // celebration grow past the scenery. Doing that by dropping the ClipRect
    // used to change the shape of the tree under it, so the fade and the
    // scale were built again from scratch and started at their finished
    // values: the hardest find in the room vanished without a flicker.
    await pumpScene(tester, const {'parrot', 'gold_coin'});
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      _opacityOf(tester, 'gold_coin'),
      greaterThan(0.0),
      reason: 'the covered prop popped out instead of fading',
    );
    expect(
      _opacityOf(tester, 'gold_coin'),
      closeTo(_opacityOf(tester, 'parrot'), 0.01),
      reason: 'both props are the same way through the same fade',
    );
  });

  testWidgets('the contact shadow sits on the prop, not on its box', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScene(tester, const {});

    // The open prop's art stops at 0.53 down the scene while its box runs to
    // 0.55, which is the empty air every silhouette leaves under it. The
    // shadow belongs on the art: it is where the placer stood the prop up.
    final shadow = find
        .ancestor(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter.runtimeType.toString().contains('ContactShadow'),
          ),
          matching: find.byType(Positioned),
        )
        .first;
    final box = tester.getRect(_sprite('parrot'));
    expect(
      tester.getRect(shadow).center.dy,
      closeTo(box.center.dy + 30, 1.0),
      reason: 'the shadow is drawn 0.03 of the scene below the prop centre',
    );
  });

  testWidgets('an older band is drawn the same room, more faintly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The one difficulty lever a picture with its finds painted into it has
    // left: the room shows faintly through the thing standing in it.
    await pumpScene(tester, const {}, opacity: 0.84);
    expect(_opacityOf(tester, 'parrot'), closeTo(0.84, 0.001));
    expect(_opacityOf(tester, 'gold_coin'), closeTo(0.84, 0.001));

    // And a find still leaves altogether, from wherever it was drawn: the
    // fade out is not scaled by the blend, or a Hunt player would tap a duck
    // and be left with a sixth of one.
    await pumpScene(tester, const {'parrot'}, opacity: 0.84);
    await tester.pump(const Duration(seconds: 1));
    expect(_opacityOf(tester, 'parrot'), 0.0);
  });

  testWidgets('a room too tall for the screen opens in the middle of itself', (
    tester,
  ) async {
    // A 4:3 room on a phone-shaped screen overflows it by about a third of its
    // height. Opening at the top left - which is what an InteractiveViewer does
    // if nobody tells it otherwise - starts the player on the cabin's ceiling
    // and the meadow's sky, with the floor they are supposed to be searching
    // off screen until they think to drag.
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpScene(tester, const {});
    // Centring is applied after the frame that measured the viewport.
    await tester.pump();
    await tester.pump();

    // The scene is 1600 x 1000 and the window 1600 x 600, so 400 pixels of
    // room overflow and half of that comes off the top. The open prop sits at
    // the middle of the scene, which is now the middle of the screen.
    expect(tester.getRect(_sprite('parrot')).center.dy, closeTo(300, 1.0));
  });
}
