import 'package:peepo/game/game_screen.dart';
import 'package:peepo/game/peepo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scene_pump.dart';

/// End-to-end: pan the scene to each object, tap where it is drawn and
/// expect it found. The scene is cover-fitted, so part of it starts off
/// screen and has to be dragged into view first - exactly what a player does.
Matrix4 _matrixOf(WidgetTester tester, Finder viewer) {
  final controller = tester
      .widget<InteractiveViewer>(viewer)
      .transformationController;
  if (controller != null) return controller.value;
  // No controller passed in: read the transform the viewer applies.
  final transform = tester.widget<Transform>(
    find.descendant(of: viewer, matching: find.byType(Transform)).first,
  );
  return transform.transform;
}

/// Any fixed value will do; it only has to be the same one the widget plays,
/// since the level is hidden differently for every seed.
const _seed = 20260822;

/// How far a miss tap has to stay from every object.
///
/// The game grows the tap target well past the sprite for the younger bands,
/// so a point merely outside a polygon is not necessarily a miss.
const _missMargin = 0.06;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays the pirate scene through to level complete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
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

    // Same cover fit the widget computes: fill both axes, keep aspect.
    final aspect = scene.size.aspectRatio;
    var sceneSize = Size(viewportSize.width, viewportSize.width / aspect);
    if (sceneSize.height < viewportSize.height) {
      sceneSize = Size(viewportSize.height * aspect, viewportSize.height);
    }

    /// Where a normalized scene point currently sits on screen, following
    /// the viewer's live pan/zoom matrix.
    Offset onScreen(Offset normalized) {
      final matrix = _matrixOf(tester, viewer);
      final local = MatrixUtils.transformPoint(
        matrix,
        Offset(
          normalized.dx * sceneSize.width,
          normalized.dy * sceneSize.height,
        ),
      );
      return viewportTopLeft + local;
    }

    /// Drags until [normalized] is comfortably inside the viewport.
    Future<void> bringIntoView(Offset normalized) async {
      for (var attempt = 0; attempt < 4; attempt++) {
        final point = onScreen(normalized);
        final inset = viewport.deflate(24);
        if (inset.contains(point)) return;
        await tester.dragFrom(viewport.center, viewport.center - point);
        await tester.pumpAndSettle();
      }
    }

    // A tap on empty scenery finds nothing, so every chip stays in the bar.
    // The empty spot is searched for rather than assumed: the level is hidden
    // afresh every time the art changes, and a point that was bare scenery in
    // one layout is an object in the next.
    Offset? bare;
    for (var y = 1; y < 10 && bare == null; y++) {
      for (var x = 1; x < 10 && bare == null; x++) {
        final point = Offset(x / 10, y / 10);
        final hit = scene.objects.any(
          (object) =>
              object.distanceTo(point, scene.heightOverWidth) <= _missMargin,
        );
        if (!hit) bare = point;
      }
    }
    expect(bare, isNotNull, reason: 'the scene has no empty spot to miss on');
    await bringIntoView(bare!);
    await tester.tapAt(onScreen(bare));
    await tester.pumpAndSettle();
    for (final group in scene.groups) {
      expect(
        find.text(group.label),
        findsOneWidget,
        reason: 'a miss should not clear the ${group.kind} chip',
      );
    }

    // Where every chip sits before anything is found. Chips hold these slots
    // for the whole level, so the ones still to find never move.
    final slots = {
      for (final group in scene.groups)
        group.kind: tester.getRect(find.byKey(ValueKey(group.kind))),
    };

    final found = <String>{};
    for (var i = 0; i < scene.finds.length; i++) {
      final object = scene.finds[i];
      await bringIntoView(object.pos);
      await tester.tapAt(onScreen(object.pos));
      await tester.pump();
      found.add(object.id);

      await tester.pumpAndSettle();
      for (final group in scene.groups) {
        expect(
          tester.getRect(find.byKey(ValueKey(group.kind))),
          slots[group.kind],
          reason: 'chip for ${group.kind} moved after finding ${object.id}',
        );
        // A fully found thing fades out of its slot; one with copies still
        // out there stays on show.
        final fade = tester.widget<Opacity>(
          find
              .descendant(
                of: find.byKey(ValueKey(group.kind)),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(
          fade.opacity,
          group.isComplete(found) ? 0 : 1,
          reason: 'chip for ${group.kind} after finding ${object.id}',
        );
      }
      expect(
        find.text('Level Complete!'),
        i == scene.finds.length - 1 ? findsOneWidget : findsNothing,
        reason: 'level completes only once the last object is found',
      );
    }

    await tester.pumpAndSettle();
    expect(find.text('Level Complete!'), findsOneWidget);
    // Peepo does the celebrating, from the seal the confetti bursts out of.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Peepo && widget.pose == PeepoPose.cheer,
      ),
      findsOneWidget,
    );
  });
}
