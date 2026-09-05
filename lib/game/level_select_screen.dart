import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/difficulty.dart';
import '../models/level.dart';
import '../models/level_progress.dart';
import '../models/settings.dart';
import '../theme.dart';
import 'audio.dart';
import 'game_screen.dart';
import 'parental_gate.dart';
import 'peepo.dart';
import 'settings_screen.dart';

/// Home screen: every level the app ships, in play order.
///
/// The list is the catalog manifest and nothing else - drop a level folder in
/// `assets/levels/`, list it in `levels.json`, and it shows up here.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({
    super.key,
    required this.progress,
    required this.settings,
    required this.audio,
  });

  final LevelProgress progress;

  /// The age band every level on this list is played at, and the grown-up
  /// switches behind the gate in the corner.
  final AppSettings settings;

  /// The music and the effects.
  final GameAudio audio;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> with RouteAware {
  late Future<LevelCatalog> _catalog = LevelCatalog.load();

  @override
  void initState() {
    super.initState();
    widget.audio.playMusic(GameAudio.menuTrack);
    // The list is where every session starts and where somebody is reading
    // rather than playing, so the cues are decoded here. By the time the first
    // level is tapped they are all in memory, and the first find in the game
    // sounds at the moment it happens.
    unawaited(widget.audio.warm());
    // First launch: nobody has said who is playing, and the game cannot guess.
    // Asked once, before a level has been opened, and never again.
    if (!widget.settings.ageChosen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askAge());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The home screen is where every session starts, so this is where Peepo
    // gets decoded - by the time a level is tapped he is already in memory.
    Peepo.precacheAll(context);
    // Asked for again on every dependency change because the route is the
    // subscription's key; subscribing twice to the same one is a no-op.
    final route = ModalRoute.of(context);
    if (route != null) musicRouteObserver.subscribe(this, route);
  }

  Future<void> _askAge() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FirstRunAgeCard(settings: widget.settings),
    );
  }

  /// Opens the grown-up settings, past the gate.
  Future<void> _openSettings() async {
    widget.audio.play(Sfx.tap);
    if (!await showParentalGate(context)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          progress: widget.progress,
          audio: widget.audio,
        ),
      ),
    );
  }

  /// Plays [level].
  ///
  /// The track is asked for here rather than inside the level, so it changes
  /// as the route does. Taking it back is [didPopNext]'s job and not this
  /// one's: a level that replaces itself with the next one completes this
  /// push synchronously, so handing the music back here would land on top of
  /// the track the next level has just asked for.
  Future<void> _openLevel(LevelCatalog catalog, Level level) async {
    widget.audio.play(Sfx.tap);
    widget.audio.playMusic(level.id);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          level: level,
          catalog: catalog,
          progress: widget.progress,
          settings: widget.settings,
          audio: widget.audio,
        ),
      ),
    );
  }

  @override
  void dispose() {
    musicRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// The level, or the settings, that was on top of the list has gone, so the
  /// list takes its own music back.
  @override
  void didPopNext() {
    widget.audio.playMusic(GameAudio.menuTrack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeepoColors.ground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: PeepoColors.cream,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Peepo(pose: PeepoPose.search, size: 34),
            SizedBox(width: 10),
            Text(
              'PEEPO',
              style: TextStyle(letterSpacing: 6, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          // The band the levels are being played at, doubling as the way in
          // to the settings that change it. A child tapping it lands on the
          // gate, not on the settings.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedBuilder(
              animation: widget.settings,
              builder: (context, _) =>
                  _BandButton(band: widget.settings.band, onTap: _openSettings),
            ),
          ),
        ],
      ),
      body: FutureBuilder<LevelCatalog>(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              text: 'Could not read the level list.\n${snapshot.error}',
              onRetry: () => setState(() => _catalog = LevelCatalog.load()),
            );
          }
          final catalog = snapshot.data;
          if (catalog == null) {
            return const Center(
              child: CircularProgressIndicator(color: PeepoColors.teal),
            );
          }
          if (catalog.isEmpty) {
            return const _Message(text: 'No levels installed yet.');
          }
          // Both matter to a card: progress puts the seal on it, and the age
          // band decides how many things it promises.
          return AnimatedBuilder(
            animation: Listenable.merge([widget.progress, widget.settings]),
            builder: (context, _) => _LevelGrid(
              catalog: catalog,
              progress: widget.progress,
              settings: widget.settings,
              onPlay: (level) => _openLevel(catalog, level),
            ),
          );
        },
      ),
    );
  }
}

class _LevelGrid extends StatelessWidget {
  const _LevelGrid({
    required this.catalog,
    required this.progress,
    required this.settings,
    required this.onPlay,
  });

  final LevelCatalog catalog;
  final LevelProgress progress;
  final AppSettings settings;

  /// Opens a level. Held by the screen rather than the grid because the music
  /// has to be handed back when the level closes.
  final void Function(Level level) onPlay;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shape = _GridShape.of(
            catalog.levels.length,
            constraints.biggest,
          );
          return Center(
            child: SizedBox(
              width: shape.gridWidth,
              child: GridView.builder(
                padding: const EdgeInsets.all(_GridShape.padding),
                // The grid takes only the room it needs and is centred in what
                // is left, so a short catalog does not sit along one edge with
                // the rest of the screen empty. It still scrolls if the levels
                // ever outgrow the screen - see [_GridShape.of].
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: shape.columns,
                  mainAxisSpacing: _GridShape.gap,
                  crossAxisSpacing: _GridShape.gap,
                  childAspectRatio: _GridShape.aspect,
                ),
                itemCount: catalog.levels.length,
                itemBuilder: (context, index) {
                  final level = catalog.levels[index];
                  return _LevelCard(
                    level: level,
                    // The card shows the room this age will actually be
                    // handed, which on a level that ships a denser backdrop
                    // for the older bands is not the one it was authored with.
                    thumbnail: level.thumbnailFor(settings.profile),
                    // What this level hides for the age it is being played at,
                    // not what its catalog holds: a card promising fourteen
                    // things in front of a level that hides six is a card that
                    // lies. Counted off the scene that band is handed, variant
                    // and all.
                    objectCount: level.objectCountFor(settings.profile),
                    complete: progress.isComplete(level.id),
                    onPlay: () => onPlay(level),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// How many columns the level cards are laid out in, and how wide a card is.
///
/// The home screen is the one screen a child has to be able to take in at a
/// glance, so the arrangement is chosen for the screen it is on rather than
/// fixed. A column count picked by card width alone gets both shapes of device
/// wrong: on a landscape phone four levels come out as three across and one
/// underneath, with the fourth card cut off below the fold, and on a tablet as
/// the same three and one with a hole beside it.
///
/// So every arrangement is tried and the one with the largest cards that still
/// shows every level at once wins. Four levels land as two by two on both,
/// which is also the arrangement that reads as deliberate.
class _GridShape {
  const _GridShape(this.columns, this.cardWidth);

  final int columns;
  final double cardWidth;

  static const gap = 16.0;
  static const padding = 16.0;
  static const aspect = 4 / 3;

  /// A card never grows past this, however few levels there are: a single
  /// enormous card on a desktop window is a poster, not a menu.
  static const maxCard = 700.0;

  /// ...and never shrinks below it, however many. Past this the arrangement
  /// stops being a grid of rooms and starts being a contact sheet, and the
  /// screen is allowed to scroll instead.
  static const minCard = 220.0;

  double get gridWidth =>
      cardWidth * columns + gap * (columns - 1) + padding * 2;

  /// The best arrangement of [count] cards for a [viewport].
  static _GridShape of(int count, Size viewport) {
    final width = math.max(1.0, viewport.width - padding * 2);
    final height = math.max(1.0, viewport.height - padding * 2);
    _GridShape? fits;
    _GridShape? tightest;
    for (var columns = 1; columns <= math.max(1, count); columns++) {
      final rows = (count / columns).ceil();
      final across = (width - gap * (columns - 1)) / columns;
      if (across < minCard && columns > 1) break; // narrower is no better
      tightest = _GridShape(columns, math.min(across, maxCard));
      // A card is as wide as its row allows and as tall as its column does,
      // whichever runs out first. Sizing by the row alone is what puts four
      // levels on a tablet as three and one: two by two only looks too big for
      // the screen until the cards are allowed to shrink into it.
      final down = (height - gap * (rows - 1)) / rows * aspect;
      final card = math.min(math.min(across, down), maxCard);
      if (card < minCard) continue;
      if (fits == null || card > fits.cardWidth) {
        fits = _GridShape(columns, card);
      }
    }
    // Nothing fits: the catalog has outgrown the screen, so take the most
    // columns the cards can stand and let the grid scroll.
    return fits ?? tightest ?? _GridShape(1, math.min(width, maxCard));
  }
}

/// One level: its backdrop as the thumbnail, its name on a scrim across the
/// bottom, and a gold seal once it has been finished.
class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.thumbnail,
    required this.objectCount,
    required this.complete,
    required this.onPlay,
  });

  final Level level;

  /// Backdrop to show, which is the one the chosen age band plays.
  final String thumbnail;

  /// How many things this level hides at the chosen age band. Spoken by the
  /// card rather than printed on it: the number tells a screen reader what
  /// the picture already tells everyone else.
  final int objectCount;

  final bool complete;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${level.name}, $objectCount objects'
          '${complete ? ', complete' : ''}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: PeepoColors.panel,
          child: InkWell(
            onTap: onPlay,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The backdrop is full scene resolution; decode it down to
                // roughly card size so a long level list stays cheap.
                Image.asset(
                  thumbnail,
                  fit: BoxFit.cover,
                  cacheWidth: 640,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stack) => const ColoredBox(
                    color: PeepoColors.panel,
                    child: Icon(
                      Icons.image_not_supported,
                      color: PeepoColors.faint,
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [PeepoColors.scrimClear, PeepoColors.scrim],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        level.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PeepoColors.cream,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (complete)
                  const Positioned(top: 10, right: 10, child: _CompleteSeal()),
                // Drawn over the picture, not around the card, so the stroke
                // is not eaten by the ClipRRect. Every sprite and backdrop in
                // the game carries a thick dark line; without one here the
                // card looks assembled rather than drawn.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: PeepoColors.stroke,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The age band in the corner of the home screen: what the levels are tuned
/// for right now, and the door to changing it.
class _BandButton extends StatelessWidget {
  const _BandButton({required this.band, required this.onTap});

  final AgeBand band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Grown-up settings. Ages ${band.ageLabel}',
      child: Material(
        color: PeepoColors.teal,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: PeepoColors.onAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  band.ageBadge,
                  style: const TextStyle(
                    color: PeepoColors.onAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompleteSeal extends StatelessWidget {
  const _CompleteSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: PeepoColors.sealGradient,
        ),
        border: Border.fromBorderSide(
          BorderSide(color: PeepoColors.outline, width: 2),
        ),
      ),
      child: const Icon(Icons.check, size: 17, color: PeepoColors.outline),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Peepo(pose: PeepoPose.wave, size: 132, semantic: true),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PeepoColors.dimSky),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
