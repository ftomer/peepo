import 'package:peepo/game/game_screen.dart';
import 'package:peepo/models/difficulty.dart';
import 'package:peepo/models/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scene_pump.dart';

/// End-to-end on the one thing an older band plays that a younger one does
/// not: a scene with decoys in it.
///
/// A decoy is placed, drawn and panned over like a find, but it is on no chip
/// and no tap can claim it. The level used to end when as many things had
/// been found as the scene held objects, decoys included - so from the Seek
/// band up, a player who found every last thing on the list was left standing
/// in a finished room with nothing to tap and no card.
const _seed = 20260822;

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

  testWidgets('a scene full of decoys still ends when the list is done', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final profile = DifficultyProfile.of(AgeBand.seek);
    final scene = await pirateLevel.loadScene(seed: _seed, profile: profile);

    // The premise of the test: this band really is given a room with more in
    // it than the list asks for.
    expect(
      scene.finds.length,
      lessThan(scene.objects.length),
      reason: 'the dense pirate cabin should hide decoys among the finds',
    );

    await pumpSceneReady(
      tester,
      MaterialApp(
        home: GameScreen(
          level: pirateLevel,
          seed: _seed,
          settings: AppSettings(band: AgeBand.seek, ageChosen: true),
        ),
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

    Future<void> tapAtScene(Offset normalized) async {
      for (var attempt = 0; attempt < 4; attempt++) {
        final point = onScreen(normalized);
        if (viewport.deflate(24).contains(point)) break;
        await tester.dragFrom(viewport.center, viewport.center - point);
        await tester.pumpAndSettle();
      }
      await tester.tapAt(onScreen(normalized));
      await tester.pumpAndSettle();
    }

    // Tapping a decoy is a miss like any other: it counts for nothing, so the
    // level cannot be finished by clearing the room instead of the list.
    for (final decoy in scene.objects.where((o) => !o.findable)) {
      await tapAtScene(decoy.pos);
    }
    expect(find.text('Level Complete!'), findsNothing);

    for (final object in scene.finds) {
      await tapAtScene(object.pos);
    }

    expect(find.text('Level Complete!'), findsOneWidget);
  });
}
