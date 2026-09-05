import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/audio.dart';
import 'game/level_select_screen.dart';
import 'models/level_progress.dart';
import 'models/settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every scene is 4:3 landscape artwork and SceneView fits it cover-style, so
  // a portrait phone would show a narrow vertical slice and turn the game into
  // a panning exercise. Landscape only, on phone and tablet alike.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Both are read off the device before the first frame: a level opened at the
  // wrong age band is hidden wrong, and a flash of the default settings before
  // the real ones arrive is worse than waiting a frame for them.
  final settings = await AppSettings.load();
  final progress = await LevelProgress.load();
  // Says how the game's sound sits beside the rest of the device before any of
  // it is played. Not fatal: a device that will not take the configuration
  // still plays, it just plays on the platform's own terms.
  unawaited(GameAudio.configure());
  runApp(
    PeepoApp(
      settings: settings,
      progress: progress,
      audio: GameAudio(settings: settings),
    ),
  );
}

class PeepoApp extends StatefulWidget {
  const PeepoApp({
    super.key,
    required this.settings,
    required this.progress,
    required this.audio,
  });

  /// The grown-up's choices, above all which age band levels are hidden for.
  final AppSettings settings;

  /// Which levels are done. Lives above the navigator so it survives moving
  /// between the level list and a level.
  final LevelProgress progress;

  /// The music and the effects. Lives above the navigator so a track carries
  /// on across a screen change instead of being torn down with the screen
  /// that started it.
  final GameAudio audio;

  @override
  State<PeepoApp> createState() => _PeepoAppState();
}

class _PeepoAppState extends State<PeepoApp> {
  @override
  void dispose() {
    unawaited(widget.audio.dispose());
    widget.progress.dispose();
    widget.settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peepo',
      debugShowCheckedModeBanner: false,
      theme: peepoTheme(),
      // How the level list learns that the level above it has gone, which is
      // the moment it takes its music back. See [musicRouteObserver].
      navigatorObservers: [musicRouteObserver],
      home: LevelSelectScreen(
        progress: widget.progress,
        settings: widget.settings,
        audio: widget.audio,
      ),
    );
  }
}
