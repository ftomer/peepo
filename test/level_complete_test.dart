import 'package:peepo/game/game_screen.dart';
import 'package:peepo/game/scene_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scene_pump.dart';

/// End-to-end: finish the level and check the card it puts up is all there, on
/// both shapes of screen the game runs on. The game is locked to landscape, so
/// the two are a phone and a tablet: 852 x 393 logical pixels is an iPhone,
/// short enough to get the two-column card, and 1180 x 820 is an iPad, which
/// gets the stacked one. The stacked card used to run its last button off the
/// bottom.
///
/// One playthrough covers both: the card is resized under the finished level
/// rather than played for twice. Two playthroughs in one file deadlock - each
/// waits out real image decoding through [pumpSceneReady], and the second one
/// never gets going.
const _seed = 20260822;

const _phone = Size(852, 393);
const _tablet = Size(1180, 820);

/// Every line the finished card must show, whichever way it lays itself out.
///
/// Getting out is not among them: the card sits in the screen's body and the
/// AppBar's back arrow already lands on the level list, so it does not spend a
/// button saying so again.
const _labels = ['Level Complete!', 'Play Again', 'New hiding places'];

Matrix4 _matrixOf(WidgetTester tester, Finder viewer) {
  final controller = tester
      .widget<InteractiveViewer>(viewer)
      .transformationController;
  if (controller != null) return controller.value;
  final transform = tester.widget<Transform>(
    find.descendant(of: viewer, matching: find.byType(Transform)).first,
  );
  return transform.transform;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the finished level offers the way on and the room again', (
    tester,
  ) async {
    tester.view.physicalSize = _phone * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final scene = await pirateLevel.loadScene(seed: _seed);

    await pumpSceneReady(
      tester,
      const MaterialApp(
        home: GameScreen(level: pirateLevel, seed: _seed),
      ),
    );

    final viewer = find.byType(InteractiveViewer);
    final viewportTopLeft = tester.getTopLeft(viewer);
    final viewportSize = tester.getSize(viewer);
    final viewport = viewportTopLeft & viewportSize;

    final aspect = scene.size.aspectRatio;
    var sceneSize = Size(viewportSize.width, viewportSize.width / aspect);
    if (sceneSize.height < viewportSize.height) {
      sceneSize = Size(viewportSize.height * aspect, viewportSize.height);
    }

    Offset onScreen(Offset normalized) {
      final local = MatrixUtils.transformPoint(
        _matrixOf(tester, viewer),
        Offset(
          normalized.dx * sceneSize.width,
          normalized.dy * sceneSize.height,
        ),
      );
      return viewportTopLeft + local;
    }

    Future<void> bringIntoView(Offset normalized) async {
      for (var attempt = 0; attempt < 4; attempt++) {
        final point = onScreen(normalized);
        if (viewport.deflate(24).contains(point)) return;
        await tester.dragFrom(viewport.center, viewport.center - point);
        await tester.pumpAndSettle();
      }
    }

    for (final object in scene.finds) {
      await bringIntoView(object.pos);
      await tester.tapAt(onScreen(object.pos));
      await tester.pumpAndSettle();
    }

    void expectCardFits() {
      final screen = tester.getRect(find.byType(MaterialApp));
      for (final label in _labels) {
        final box = tester.getRect(find.text(label));
        expect(
          screen.contains(box.topLeft) && screen.contains(box.bottomRight),
          isTrue,
          reason: '"$label" is cut off at $box on $screen',
        );
      }
    }

    expect(find.text('Level Complete!'), findsOneWidget);
    expectCardFits();

    // The same card on a tablet, where it stacks instead of splitting in two.
    tester.view.physicalSize = _tablet * 3;
    await tester.pumpAndSettle();
    expectCardFits();

    tester.view.physicalSize = _phone * 3;
    await tester.pumpAndSettle();

    // Play again puts the room back up to be found over: the card is gone and
    // a playable level is back, so this reloaded rather than merely
    // un-checking what was found. That the reload hides everything somewhere
    // else is placement's business - see placement_test.dart, "every seed
    // hides the level somewhere else".
    await tester.tap(find.text('Play Again'));
    await pumpSceneReady(tester);

    expect(find.text('Level Complete!'), findsNothing);
    expect(find.byType(SceneView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
