// Drives the real app through the states the store listing needs and holds each
// one still while an outside screen capture takes the frame.
//
// This is a capture rig rather than a test: it asserts only enough to fail
// loudly when a screen it expects is not there. `tools/store_shots.sh` runs it,
// answers the handshake below and writes the PNGs.
//
// Handshake: this side writes `<temp>/peepo_shots/request` holding a shot name
// and waits for `<temp>/peepo_shots/ack`. The macOS app is sandboxed, so that
// temp directory is the app container's, which is where the script looks.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peepo/main.dart' as app;

/// Content size in points. Doubled by the retina capture, these are the two
/// sizes App Store Connect asks for: 2688x1242 and 2752x2064.
const _sizes = {'iphone': Size(1344, 621), 'ipad': Size(1376, 1032)};

/// The file each room's shot is written as. Named for the level folder rather
/// than for the card, because that is what the listing orders them by.
const _shotName = {
  'Toy Room': 'toy_room',
  'Rainbow Meadow': 'rainbow_meadow',
  'Space Station': 'space_station',
  "Captain's Cabin": 'pirate_cabin',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const target = String.fromEnvironment('SHOT_TARGET', defaultValue: 'iphone');
  final handshake = Directory('${Directory.systemTemp.path}/peepo_shots');

  /// Pumps for a fixed stretch of frames.
  ///
  /// Not [WidgetTester.pumpAndSettle]: the game leaves animations running for
  /// as long as they are wanted - the hint ring pulses until the find is made,
  /// Peepo blinks on the finish card - and settling waits for a tree with none
  /// left. The rig met that as a ten minute hang in front of a room that was
  /// on screen and ready the whole time.
  Future<void> steady(
    WidgetTester tester, [
    Duration span = const Duration(milliseconds: 600),
  ]) async {
    final frames = (span.inMilliseconds / 40).ceil();
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  /// Holds the current frame until the capture script says it has the shot.
  Future<void> shot(WidgetTester tester, String name) async {
    await steady(tester, const Duration(milliseconds: 400));
    handshake.createSync(recursive: true);
    // Written aside and renamed in: a plain write truncates on open, so the
    // script can read the request file in the instant it holds no name yet.
    File('${handshake.path}/request.part')
      ..writeAsStringSync(name)
      ..renameSync('${handshake.path}/request');
    final ack = File('${handshake.path}/ack');
    for (var i = 0; i < 600; i++) {
      if (ack.existsSync()) {
        ack.deleteSync();
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
      sleep(const Duration(milliseconds: 100));
    }
    throw StateError(
      'nothing captured $name - is tools/store_shots.sh running?',
    );
  }

  /// Opens the level whose card carries [name] and waits out the smoke.
  Future<void> openLevel(WidgetTester tester, String name) async {
    // The level list is a grid and the catalog has outgrown one screen of it,
    // so the card being asked for is not always on screen.
    final card = find.text(name);
    await tester.scrollUntilVisible(
      card,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await steady(tester, const Duration(milliseconds: 400));
    await tester.tap(card);
    await steady(tester, const Duration(milliseconds: 400));
    // The scene decodes behind the smoke cloud, and nothing is worth capturing
    // until that has cleared.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await steady(tester, const Duration(milliseconds: 400));
  }

  /// Taps every cell of a grid over the scene, which finds everything on show
  /// without this rig needing to know where the placer put it.
  ///
  /// A 4:3 room on a 2.16:1 phone is cropped top and bottom, so the caller
  /// drags between passes to bring the rest of the room into view.
  Future<void> sweep(WidgetTester tester, {int steps = 22}) async {
    final rect = tester.getRect(find.byType(InteractiveViewer));
    for (var y = 0; y < steps; y++) {
      if (find.text('Level Complete!').evaluate().isNotEmpty) break;
      for (var x = 0; x < steps; x++) {
        // A deliberate press and release: the scene sits inside an
        // InteractiveViewer, and a tap with no time in it loses the gesture
        // arena to the pan recogniser.
        final gesture = await tester.startGesture(
          Offset(
            rect.left + rect.width * (x + 0.5) / steps,
            rect.top + rect.height * (y + 0.5) / steps,
          ),
        );
        await tester.pump(const Duration(milliseconds: 40));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 40));
      }
    }
    await steady(tester, const Duration(milliseconds: 400));
  }

  /// Sweeps the whole room: the middle of it, then what the crop hides above
  /// and below, dragging the scene between passes.
  Future<void> findEverything(WidgetTester tester) async {
    final rect = tester.getRect(find.byType(InteractiveViewer));
    for (final shift in [0.0, 0.5, -1.0]) {
      if (find.text('Level Complete!').evaluate().isNotEmpty) break;
      if (shift != 0) {
        await tester.dragFrom(rect.center, Offset(0, rect.height * shift));
        await steady(tester, const Duration(milliseconds: 400));
      }
      await sweep(tester);
    }
  }

  /// Opens the grown-up settings, answering the gate's sum on the way.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await steady(tester, const Duration(milliseconds: 600));
    final sum = tester.widget<Text>(
      find.textContaining(RegExp(r'^\d+ \+ \d+$')),
    );
    final parts = sum.data!.split(' + ').map(int.parse).toList();
    await shot(tester, 'parental_gate');
    await tester.tap(find.text('${parts[0] + parts[1]}'));
    await steady(tester, const Duration(milliseconds: 800));
  }

  testWidgets('store screenshots', (tester) async {
    app.main();
    await steady(tester, const Duration(seconds: 3));

    // Resize after the first frame, then give the window time to land: a shot
    // taken mid-resize is the wrong size and the store rejects it.
    final size = _sizes[target]!;
    await const MethodChannel('peepo/shots').invokeMethod<bool>('sizeWindow', {
      'width': size.width,
      'height': size.height,
    });
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await steady(tester, const Duration(milliseconds: 400));

    // Every shot below is taken at the band the scenes are authored for. It is
    // also the only band drawn at full paint - the older two see the room
    // faintly through what is hidden in it, which is difficulty rather than
    // something to show a shopper.
    await openSettings(tester);
    await tester.tap(find.text('Look'));
    await steady(tester, const Duration(milliseconds: 600));
    await shot(tester, 'ages');
    await tester.pageBack();
    await steady(tester, const Duration(milliseconds: 800));

    await shot(tester, 'levels');

    // The rooms first, and the finish card last.
    //
    // Everything up to here is a screen the rig walks straight to. The finish
    // card is not: it has to play a whole level out by tapping a grid over the
    // room, which takes minutes, ends with the level-complete fanfare, and is
    // where every failure this rig has ever had has happened. Taken last, a
    // bad run costs one shot instead of the set.
    for (final room in const [
      'Toy Room',
      'Rainbow Meadow',
      'Space Station',
      "Captain's Cabin",
    ]) {
      await openLevel(tester, room);
      await shot(tester, _shotName[room]!);
      await tester.pageBack();
      await steady(tester, const Duration(milliseconds: 800));
    }

    await openLevel(tester, 'Toy Room');
    await findEverything(tester);
    await shot(tester, 'complete');

    // Every shot is on disk. Said out loud, because what happens next is not
    // reliable: the app plays music the whole time it is up, and the position
    // updater audioplayers keeps on the frame callbacks is still ticking when
    // the binding tears the tree down. Some runs report that as an animation
    // outliving its widget, some as a closed sink, and both fail a run that
    // did its whole job. The script reads this file rather than the exit code.
    File('${handshake.path}/finished').writeAsStringSync('done');
  });
}
