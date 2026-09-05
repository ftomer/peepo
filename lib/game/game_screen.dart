import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/difficulty.dart';
import '../models/level.dart';
import '../models/level_progress.dart';
import '../models/scene.dart';
import '../models/settings.dart';
import '../theme.dart';
import 'audio.dart';
import 'peepo.dart';
import 'scene_view.dart';
import 'smoke.dart';

/// Plays one level. Which level is the caller's choice - the screen knows how
/// to load any of them, and where the next one is once this one is done.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.level,
    this.catalog,
    this.progress,
    this.settings,
    this.audio,
    this.seed,
  });

  final Level level;

  /// The grown-up's choices, above all the age band the level is hidden and
  /// helped at. Left out, the level plays at [DifficultyProfile.fallback].
  final AppSettings? settings;

  /// Fixes the layout the level is hidden in. Left out - which is how the game
  /// plays it - every visit hides the level differently.
  final int? seed;

  /// Used to offer the next level when this one is finished. Without it the
  /// level simply ends.
  final LevelCatalog? catalog;

  /// Told about the win, so the level list can show it as done.
  final LevelProgress? progress;

  /// The music and the effects. Left out, the level plays in silence, which is
  /// what tests and the layout tool want: neither has an audio device behind
  /// it. Which track is playing is the level list's business, not this
  /// screen's - see [_playNext] for the one case where it is not.
  final GameAudio? audio;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  GameScene? _scene;
  final Set<String> _foundIds = {};
  SceneObject? _hintTarget;
  Offset? _missMarker;
  Timer? _hintTimer;
  Timer? _missTimer;

  /// Counts down the quiet since the last find, and is what shows a hint to a
  /// player who has stopped looking. A child of this age does not ask for
  /// help, so the game has to notice instead.
  Timer? _idleTimer;

  final _random = Random();

  late final GameAudio _audio = widget.audio ?? GameAudio.silent();

  /// The band the room was hidden at. Held rather than read live, so changing
  /// the age setting mid-level cannot describe the level the player is looking
  /// at as something else.
  late DifficultyProfile _profile = _chosenProfile;

  /// True once the game has stepped in for a player who is stuck: two hints
  /// have come and gone without a find. It only ever adds help, and it lasts
  /// the rest of the level.
  bool _assisting = false;

  int _hintsTaken = 0;
  int _hintsSinceFind = 0;

  /// When the room was revealed, for the bands that end on a rating.
  DateTime? _startedAt;

  /// The rating, worked out the moment the last thing was found and then left
  /// alone. Read live it would keep falling while the card sat on screen.
  int? _finalStars;

  DifficultyProfile get _chosenProfile =>
      widget.settings?.profile ?? DifficultyProfile.fallback;

  /// 0 while loading (scene fully hidden by smoke), 1 once revealed.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  bool _revealDone = false;

  /// The scene file could not be read - the smoke gives way to an apology
  /// instead of hanging there.
  bool _loadFailed = false;

  bool get _levelComplete =>
      _scene != null && _foundIds.length == _scene!.finds.length;

  @override
  void initState() {
    super.initState();
    _loadScene();
  }

  @override
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different level in the same screen: back to the smoke and reload.
    if (oldWidget.level.id != widget.level.id) _startOver();
  }

  /// Hints the player may still ask for, or null where there is no limit.
  int? get _hintsLeft => _profile.manualHints == null
      ? null
      : max(0, _profile.manualHints! - _hintsTaken);

  @override
  void dispose() {
    _hintTimer?.cancel();
    _missTimer?.cancel();
    _idleTimer?.cancel();
    _reveal.dispose();
    super.dispose();
  }

  /// Loads the scene JSON and decodes every image it needs before showing
  /// anything - a level never appears half-dressed, backdrop first and
  /// sprites after. The smoke clears only once it is all in memory.
  Future<void> _loadScene() async {
    final GameScene scene;
    _profile = _chosenProfile;
    try {
      scene = await widget.level.loadScene(
        seed: widget.seed,
        profile: _profile,
      );
    } catch (error, stack) {
      // A missing or malformed scene file would otherwise leave the level
      // conjuring forever, with the reason lost in an unawaited future.
      debugPrint('peepo: failed to load ${widget.level.id} - $error\n$stack');
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    if (!mounted) return;
    // Peepo too: he is in the smoke on the way in and on the card at the end,
    // and a level can be opened without passing the list first.
    unawaited(Peepo.precacheAll(context));
    await Future.wait([
      for (final asset in [
        scene.background,
        for (final object in scene.objects) object.sprite,
        for (final object in scene.objects) object.chip,
      ])
        // onError keeps one bad asset from stranding the level behind the
        // smoke forever; the rest of the scene still comes up.
        precacheImage(
          AssetImage(asset),
          context,
          onError: (error, stack) =>
              debugPrint('peepo: failed to load $asset - $error'),
        ),
    ]);
    if (!mounted) return;
    setState(() => _scene = scene);
    // With the reveal, not before it: the whoosh is the smoke going, and the
    // smoke does not go until the room underneath it is drawn.
    _audio.play(Sfx.reveal);
    await _reveal.forward();
    if (!mounted) return;
    setState(() => _revealDone = true);
    // The clock and the quiet both start when the room does, not when it was
    // asked for: decoding a level is not time the player spent looking.
    _startedAt = DateTime.now();
    _restartIdle();
  }

  /// Restarts the wait before the game offers a hint on its own.
  ///
  /// Called on every find and after every hint, so the countdown measures the
  /// quiet rather than the level.
  void _restartIdle() {
    _idleTimer?.cancel();
    final after = _profile.autoHintAfter;
    if (after == null || _levelComplete || !_revealDone) return;
    _idleTimer = Timer(after, () {
      if (mounted) _showHint(asked: false);
    });
  }

  void _handleSceneTap(Offset normalized) {
    final scene = _scene;
    if (scene == null || _levelComplete) return;

    // Tap tolerance is the age band's: a three year old aiming at the duck and
    // landing beside it has found the duck.
    final hit = scene.hitTest(
      normalized,
      _foundIds,
      padding: _profile.tapPadding,
    );
    if (hit != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _foundIds.add(hit.id);
        if (_hintTarget?.id == hit.id) {
          _hintTarget = null;
          _hintTimer?.cancel();
        }
        _missMarker = null;
      });
      _hintsSinceFind = 0;
      if (_levelComplete) {
        _idleTimer?.cancel();
        _finalStars = _rate(scene);
        widget.progress?.markComplete(widget.level.id);
        // The fanfare instead of the find, not on top of it: the last object
        // is one event, and two cues at once would read as a mistake.
        _audio.play(Sfx.complete);
      } else {
        _audio.play(Sfx.found);
        _restartIdle();
      }
    } else {
      _audio.play(Sfx.miss);
      HapticFeedback.selectionClick();
      setState(() => _missMarker = normalized);
      _missTimer?.cancel();
      _missTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _missMarker = null);
      });
    }
  }

  /// Points at something still hidden.
  ///
  /// [asked] separates the two ways this happens. A hint the player asked for
  /// comes out of their allowance, where the band has one. A hint the game
  /// offered - because nothing has been found for a while - is free, and two
  /// of them in a row without a find is what turns assist on.
  void _showHint({bool asked = true}) {
    final scene = _scene;
    if (scene == null || _levelComplete) return;
    if (asked && (_hintsLeft ?? 1) <= 0) return;
    final unfound = scene.finds
        .where((o) => !_foundIds.contains(o.id))
        .toList();
    // Nothing to point at - a scene that repeats an id has fewer distinct
    // ids than objects, so the completion count alone can still say "playing".
    if (unfound.isEmpty) return;
    final target = unfound[_random.nextInt(unfound.length)];
    _audio.play(Sfx.hint);
    _hintsSinceFind++;
    if (!asked && _hintsSinceFind >= 2) _startAssist();
    setState(() {
      _hintTarget = target;
      if (asked) _hintsTaken++;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(_profile.hintHold, () {
      if (mounted) setState(() => _hintTarget = null);
    });
    _restartIdle();
  }

  /// Quietly helps a player who is stuck: sooner hints, held longer, a wider
  /// tap, and no allowance to run out of.
  ///
  /// One-way on purpose. Nothing here can make the level harder again, and
  /// nothing about it is announced - a child who is struggling is not told so.
  void _startAssist() {
    if (_assisting || !(widget.settings?.assistWhenStuck ?? true)) return;
    _assisting = true;
    setState(() => _profile = _profile.withAssist());
  }

  /// Plays the level again, freshly hidden.
  ///
  /// Reloading is the point: placement happens at load, so a second run of the
  /// same level puts everything somewhere else. Clearing the found set alone
  /// would hand the player back the room they just learned.
  void _reset() {
    _audio.play(Sfx.tap);
    _startOver();
  }

  /// Back behind the smoke, then load the level over again.
  void _startOver() {
    _idleTimer?.cancel();
    _hintTimer?.cancel();
    setState(() {
      _scene = null;
      _revealDone = false;
      _loadFailed = false;
      _foundIds.clear();
      _hintTarget = null;
      _missMarker = null;
      _assisting = false;
      _hintsTaken = 0;
      _hintsSinceFind = 0;
      _startedAt = null;
      _finalStars = null;
      _profile = _chosenProfile;
    });
    _reveal.value = 0;
    _loadScene();
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    if (_revealDone && scene != null) return _buildGame(scene);
    if (_loadFailed) return _SceneLoadFailure(levelName: widget.level.name);

    return Stack(
      children: [
        // The scene materializes underneath the smoke: by the time the fog
        // thins out it is already fully drawn.
        AnimatedBuilder(
          animation: _reveal,
          builder: (context, child) {
            final t = Curves.easeOut.transform(
              (_reveal.value * 2.2).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: t,
              child: Transform.scale(scale: 1.05 - 0.05 * t, child: child),
            );
          },
          child: scene == null
              ? const ColoredBox(color: PeepoColors.ground)
              : _buildGame(scene),
        ),
        // The scene below is drawn (and hit-testable) while it is still
        // hidden by the fog, so the fog has to swallow taps - otherwise a tap
        // on the smoke finds an object nobody can see yet.
        Positioned.fill(
          child: AbsorbPointer(
            child: AnimatedBuilder(
              animation: _reveal,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                children: [
                  SmokeCloud(clear: _reveal.value),
                  if (_reveal.value < 0.15)
                    Opacity(
                      opacity: (1 - _reveal.value * 8).clamp(0.0, 1.0),
                      child: const _ConjuringIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Swaps this screen for the next level, so Back still lands on the level
  /// list rather than walking a stack of finished levels.
  void _playNext(Level next) {
    _audio.play(Sfx.tap);
    // The one place the level list cannot set the track: this route replaces
    // itself, so nothing pops back to the list to change it.
    _audio.playMusic(next.id);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          level: next,
          catalog: widget.catalog,
          progress: widget.progress,
          settings: widget.settings,
          audio: widget.audio,
        ),
      ),
    );
  }

  /// The rating for a finished level, or null for the bands that do not have
  /// one - which is every band below eight, where a score that can be lost
  /// turns a game into a test.
  ///
  /// Three stars is the level found at the band's own pace with no help. One
  /// is spent by taking a hint, another by taking twice as long as par. It
  /// never falls below one: finishing is always worth something.
  int? _rate(GameScene scene) {
    if (_profile.scoring != Scoring.stars) return null;
    final started = _startedAt;
    if (started == null) return 3;
    final par = _profile.parPerObject * scene.finds.length;
    final taken = DateTime.now().difference(started);
    var stars = 3;
    if (_hintsTaken > 0) stars--;
    if (taken > par * 2) stars--;
    return max(1, stars);
  }

  Widget _buildGame(GameScene scene) {
    final next = widget.catalog?.after(widget.level);
    return Scaffold(
      backgroundColor: PeepoColors.ground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: PeepoColors.cream,
        title: Text(scene.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _HintButton(
              onPressed: _levelComplete || (_hintsLeft ?? 1) <= 0
                  ? null
                  : _showHint,
              remaining: _hintsLeft,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SceneView(
                  scene: scene,
                  foundIds: _foundIds,
                  onSceneTap: _handleSceneTap,
                  hintTarget: _hintTarget,
                  missMarker: _missMarker,
                  spriteOpacity: _profile.blendOpacity,
                ),
              ),
              _ObjectListBar(
                scene: scene,
                foundIds: _foundIds,
                showLabels: _profile.showLabels,
              ),
            ],
          ),
          if (_levelComplete)
            _LevelCompleteOverlay(
              audio: _audio,
              onPlayAgain: _reset,
              thumbnail: widget.level.thumbnail,
              onNextLevel: next == null ? null : () => _playNext(next),
              nextLevelName: next?.name,
              nextLevelThumbnail: next?.thumbnail,
              stars: _finalStars,
            ),
        ],
      ),
    );
  }
}

/// Loading state shown inside the smoke while the scene assets decode.
class _ConjuringIndicator extends StatefulWidget {
  const _ConjuringIndicator();

  @override
  State<_ConjuringIndicator> createState() => _ConjuringIndicatorState();
}

class _ConjuringIndicatorState extends State<_ConjuringIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) => CustomPaint(
                  painter: _RunePainter(_spin.value),
                  child: const Center(
                    child: Peepo(pose: PeepoPose.search, size: 74),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'PEEPO IS HIDING',
              style: TextStyle(
                color: PeepoColors.cream,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two counter-rotating arcs around a soft glow, in the two colours Peepo is
/// made of - teal for the bird, sunny for the field he stands on.
class _RunePainter extends CustomPainter {
  _RunePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final turn = t * 2 * pi;
    final pulse = 0.5 + 0.5 * sin(turn * 2);

    canvas.drawCircle(
      center,
      size.shortestSide * (0.22 + 0.05 * pulse),
      Paint()
        ..color = PeepoColors.sunny.withValues(alpha: 0.18 + 0.12 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    void arc(double radius, double from, double sweep, Color color) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        from,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = color,
      );
    }

    final outer = size.shortestSide * 0.42;
    arc(outer, turn, 2.1, PeepoColors.sunny);
    arc(outer, turn + pi, 1.2, PeepoColors.sunny.withValues(alpha: 0.4));
    arc(outer * 0.68, -turn * 1.4, 1.7, PeepoColors.teal);
  }

  @override
  bool shouldRepaint(_RunePainter old) => old.t != t;
}

/// Shown when the scene file itself could not be read, so the level ends in a
/// way out rather than in endless fog.
class _SceneLoadFailure extends StatelessWidget {
  const _SceneLoadFailure({required this.levelName});

  final String levelName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeepoColors.ground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: PeepoColors.cream,
        title: Text(levelName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Peepo(pose: PeepoPose.wave, size: 120, semantic: true),
              const SizedBox(height: 12),
              const Text(
                'Peepo lost this room',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PeepoColors.sunny,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'It could not be opened. Try another one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PeepoColors.dimSky, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.grid_view),
                label: const Text('All Levels'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar listing the objects to find, checked off as found.
///
/// The whole list always fits the screen width: chips are sized to a
/// balanced grid and wrap onto extra rows instead of scrolling sideways.
class _ObjectListBar extends StatefulWidget {
  const _ObjectListBar({
    required this.scene,
    required this.foundIds,
    this.showLabels = true,
  });

  final GameScene scene;
  final Set<String> foundIds;

  /// Whether the chips carry the object's name. Off for a player who cannot
  /// read yet, where the picture is the whole ask.
  final bool showLabels;

  @override
  State<_ObjectListBar> createState() => _ObjectListBarState();
}

class _ObjectListBarState extends State<_ObjectListBar> {
  static const _spacing = 6.0;
  static const _minChipWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PeepoColors.ground,
        // The bar is chrome laid over the picture, so it gets the same dark
        // line every drawn thing in the game has, rather than fading into the
        // bottom of the scene.
        border: Border(
          top: BorderSide(
            color: PeepoColors.outline,
            width: PeepoColors.strokeWidth,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Sized off the full list, so chips keep their size as others
            // are found instead of resizing on every catch.
            final columns = _columnsFor(widget.scene.groups.length, width);
            final chipWidth = (width - _spacing * (columns - 1)) / columns;
            // One label style for the whole bar, sized off the full list, so
            // every chip is the same box no matter how long its name is.
            // Null where the band shows pictures alone, and then the picture
            // takes the room the words would have had.
            final label = widget.showLabels
                ? _LabelMetrics.forLabels(
                    widget.scene.groups.map((g) => g.label),
                    chipWidth - _ObjectChip.horizontalPadding * 2,
                    DefaultTextStyle.of(context).style,
                  )
                : null;
            // Every kind keeps its slot for the whole level: a found chip
            // fades out in place rather than leaving the bar, so nothing the
            // player is still hunting for moves under their eyes.
            return Wrap(
              spacing: _spacing,
              runSpacing: _spacing,
              alignment: WrapAlignment.center,
              children: [
                for (final group in widget.scene.groups)
                  // The key belongs on the outermost child of the Wrap:
                  // keyed only on the chip inside, an unkeyed wrapper would
                  // be matched positionally and hand a running chip's state
                  // to the next kind along.
                  SizedBox(
                    key: ValueKey(group.kind),
                    width: chipWidth,
                    child: _ObjectChip(
                      group: group,
                      label: label,
                      foundIds: widget.foundIds,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Chips per row: as few rows as fit at [_minChipWidth], then balanced so
  /// the last row is not left nearly empty.
  static int _columnsFor(int count, double width) {
    final fitting = ((width + _spacing) / (_minChipWidth + _spacing))
        .floor()
        .clamp(2, 12);
    if (count <= fitting) return count;
    final rows = (count / fitting).ceil();
    return (count / rows).ceil();
  }
}

/// The text style and the label box every chip in the bar shares.
///
/// Names differ in length, so left alone the chips would come out different
/// heights and long single words would break mid-word. Both are settled once
/// for the whole bar: the text shrinks until the longest word fits a chip,
/// and every label gets the height of the longest one.
class _LabelMetrics {
  const _LabelMetrics({required this.style, required this.lines});

  static const lineHeight = 1.15;
  static const _maxFontSize = 11.0;
  static const _minFontSize = 7.0;
  static const _step = 0.5;
  static const _maxLines = 3;

  /// The style as it is actually painted, so measuring matches drawing.
  final TextStyle style;

  /// Lines the longest label needs - the height every chip reserves.
  final int lines;

  double get height => lines * style.fontSize! * lineHeight;

  /// Measures [labels] wrapped to [maxWidth], the text width inside a chip,
  /// as they will be painted on top of [base] - the inherited text style.
  factory _LabelMetrics.forLabels(
    Iterable<String> labels,
    double maxWidth,
    TextStyle base,
  ) {
    final width = max(maxWidth, 1.0);
    var fontSize = (width * 0.16).clamp(_minFontSize, _maxFontSize);
    TextStyle styleAt(double size) => base.copyWith(
      color: PeepoColors.cream,
      fontSize: size,
      height: lineHeight,
    );
    // Shrink until no word has to be broken across lines.
    while (fontSize > _minFontSize &&
        labels.any((l) => _longestWordWidth(l, styleAt(fontSize)) > width)) {
      fontSize = max(_minFontSize, fontSize - _step);
    }
    final style = styleAt(fontSize);
    var lines = 1;
    for (final label in labels) {
      lines = max(lines, _lineCount(label, style, width));
    }
    return _LabelMetrics(style: style, lines: min(lines, _maxLines));
  }

  static double _longestWordWidth(String label, TextStyle style) {
    var widest = 0.0;
    for (final word in label.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      widest = max(
        widest,
        _measure(word, style, double.infinity, (p) => p.width),
      );
    }
    return widest;
  }

  static int _lineCount(String label, TextStyle style, double maxWidth) =>
      _measure(label, style, maxWidth, (p) => p.computeLineMetrics().length);

  static T _measure<T>(
    String text,
    TextStyle style,
    double maxWidth,
    T Function(TextPainter) read,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    final value = read(painter);
    painter.dispose();
    return value;
  }
}

/// One object-list entry: sprite on top, label underneath. A thing placed
/// more than once shows a found/total counter until every copy is found.
///
/// The moment the last copy is found the chip pops once and then shrinks
/// away, so the bar only ever shows what is still missing.
class _ObjectChip extends StatefulWidget {
  const _ObjectChip({
    required this.group,
    required this.label,
    required this.foundIds,
  });

  static const horizontalPadding = 4.0;

  final ObjectGroup group;

  /// Text size and label height shared by every chip in the bar, or null
  /// where the bar shows pictures without their names.
  final _LabelMetrics? label;

  final Set<String> foundIds;

  @override
  State<_ObjectChip> createState() => _ObjectChipState();
}

class _ObjectChipState extends State<_ObjectChip>
    with SingleTickerProviderStateMixin {
  static const _pop = Duration(milliseconds: 280);
  static const _shrink = Duration(milliseconds: 260);

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: _pop + _shrink,
  );

  static final _split = _pop.inMilliseconds / (_pop + _shrink).inMilliseconds;

  late final Animation<double> _popT = CurvedAnimation(
    parent: _exit,
    curve: Interval(0, _split, curve: Curves.easeOut),
  );
  late final Animation<double> _shrinkT = CurvedAnimation(
    parent: _exit,
    curve: Interval(_split, 1, curve: Curves.easeInCubic),
  );

  @override
  void initState() {
    super.initState();
    // A chip can be built already complete - a level resumed part way, say.
    // Without this it would sit in the bar looking unfound.
    _syncExit();
  }

  @override
  void didUpdateWidget(_ObjectChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncExit();
  }

  /// Plays the chip out when its kind is complete, and back in on a reset.
  /// The animation is scale and opacity only, so the slot the chip occupies
  /// stays exactly where it was either way.
  void _syncExit() {
    final complete = widget.group.isComplete(widget.foundIds);
    if (complete && _exit.status != AnimationStatus.forward) {
      _exit.forward();
    } else if (!complete && _exit.value != 0) {
      _exit.value = 0;
    }
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final found = widget.group.foundCount(widget.foundIds);
    final complete = found == widget.group.total;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // A chip with no name under it gives the picture the space back: for
        // a player who cannot read, the picture is the entire ask.
        final imageSize = widget.label == null
            ? (width * 0.66).clamp(26.0, 46.0)
            : (width * 0.5).clamp(20.0, 34.0);
        return AnimatedBuilder(
          animation: _exit,
          builder: (context, child) => Transform.scale(
            scale: (1 + 0.14 * sin(_popT.value * pi)) * (1 - _shrinkT.value),
            child: Opacity(opacity: 1 - _shrinkT.value, child: child),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(
              horizontal: _ObjectChip.horizontalPadding,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              // Teal is the game's "yours, and done" colour everywhere else;
              // the Material green this used to be belongs to no other pixel
              // in the app and fired at the most rewarding moment in the loop.
              color: complete ? PeepoColors.tealDeep : PeepoColors.panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: imageSize,
                      height: imageSize,
                      child: Image.asset(
                        widget.group.sprite,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    if (widget.label case final label?) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: label.height,
                        child: Center(
                          child: Text(
                            widget.group.label,
                            textAlign: TextAlign.center,
                            maxLines: label.lines,
                            overflow: TextOverflow.ellipsis,
                            style: label.style,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Corner marker: a progress counter for a thing placed several
                // times, a plain check for a one-off.
                if (widget.group.total > 1)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _CountBadge(
                      found: found,
                      total: widget.group.total,
                      complete: complete,
                    ),
                  )
                else if (complete)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.check,
                      color: PeepoColors.cream,
                      size: 14,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// found/total counter for a thing that appears several times in the scene.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.found,
    required this.total,
    required this.complete,
  });

  final int found;
  final int total;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: complete ? PeepoColors.teal : PeepoColors.ground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$found/$total',
        style: TextStyle(
          color: complete ? PeepoColors.onAccent : PeepoColors.cream,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
    );
  }
}

/// The end of a level, celebrated the way the rest of the game is dressed: a
/// brass seal pressed on a warm card, with confetti thrown out from behind it.
/// Everything rides one finite run of a single controller, so the party ends
/// and the widget tree settles rather than animating forever.
class _LevelCompleteOverlay extends StatefulWidget {
  const _LevelCompleteOverlay({
    required this.audio,
    required this.onPlayAgain,
    this.thumbnail,
    this.onNextLevel,
    this.nextLevelName,
    this.nextLevelThumbnail,
    this.stars,
  });

  /// Rings the stars in as they land. The fanfare itself was played by the
  /// find that finished the level, a card's length before this exists.
  final GameAudio audio;

  final VoidCallback onPlayAgain;

  /// This level's backdrop, shown inside the replay button - the room the
  /// player is going back to, drawn rather than named.
  final String? thumbnail;

  /// One to three, or null for the younger bands, where finishing is the
  /// whole reward and a rating is something to fall short of.
  final int? stars;

  /// Null on the last level, which leaves replay as the only way on.
  final VoidCallback? onNextLevel;
  final String? nextLevelName;

  /// The next level's backdrop, shown inside the button. Three-year-olds do
  /// not read "Next Level"; they do recognise the place they are going.
  final String? nextLevelThumbnail;

  @override
  State<_LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<_LevelCompleteOverlay>
    with TickerProviderStateMixin {
  /// Where in the card's single run the star row rises, and how far apart the
  /// stars are rung. Shared by the drawing and the sound so the two cannot
  /// drift apart.
  static const _starsAt = 0.26;
  static const _starGap = Duration(milliseconds: 150);

  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..forward();

  /// A few heartbeats under the go arrow once the card has landed. A child
  /// who cannot read the card still sees the one thing on it that moves, and
  /// presses that. It is a finite run rather than a loop on purpose: a screen
  /// that never stops animating never settles, for the battery or for a test.
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  )..forward();

  /// Thrown once so a rebuild does not reshuffle the confetti mid-flight.
  /// A quarter of it flies in front of the card, which gives the burst depth
  /// rather than leaving it a flat halo behind a panel.
  late final List<_Confetti> _confetti = () {
    final random = Random();
    return List.generate(72, (i) => _Confetti(random, front: i % 4 == 0));
  }();
  late final List<_Confetti> _behindCard = _confetti
      .where((piece) => !piece.front)
      .toList();
  late final List<_Confetti> _overCard = _confetti
      .where((piece) => piece.front)
      .toList();

  /// One per star still to be rung, so leaving the card early does not ring
  /// the rest of them into an empty screen.
  final List<Timer> _pings = [];

  @override
  void initState() {
    super.initState();
    final stars = widget.stars;
    if (stars == null) return;
    // Timed off the same numbers the star row is drawn with: it rises over
    // [_starsAt] of the single run, so the first ping lands as it appears and
    // the rest follow it in.
    final rise = _in.duration! * _starsAt;
    for (var i = 1; i <= stars; i++) {
      _pings.add(
        Timer(rise + _starGap * (i - 1), () => widget.audio.play(Sfx.star(i))),
      );
    }
  }

  @override
  void dispose() {
    for (final ping in _pings) {
      ping.cancel();
    }
    _in.dispose();
    _beat.dispose();
    super.dispose();
  }

  /// A slice of the single run, so the pieces arrive in sequence.
  double _at(double begin, double end, {Curve curve = Curves.easeOutCubic}) =>
      Interval(begin, end, curve: curve).transform(_in.value);

  /// Swells [child] four times and leaves it at rest. Worn by whichever gold
  /// badge is the way on, so exactly one thing on the card ever moves.
  Widget _beating(Widget child) => AnimatedBuilder(
    animation: _beat,
    builder: (context, child) => Transform.scale(
      scale: 1 + 0.08 * max(0.0, sin(_beat.value * pi * 8)),
      child: child,
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _in,
        builder: (context, _) {
          final scrim = _at(0, 0.18, curve: Curves.easeOut);
          final pop = _at(0.04, 0.5, curve: Curves.elasticOut);
          return Stack(
            children: [
              Opacity(
                opacity: scrim,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.95,
                      colors: [PeepoColors.scrimSoft, PeepoColors.scrim],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
              _confettiLayer(front: false),
              Center(
                child: Transform.scale(
                  scale: 0.82 + 0.18 * pop,
                  child: Opacity(opacity: scrim, child: _card(context)),
                ),
              ),
              _confettiLayer(front: true),
            ],
          );
        },
      ),
    );
  }

  /// One half of the burst. The card is centred, so the seal it bursts from
  /// sits a little above the middle of the screen.
  Widget _confettiLayer({required bool front}) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ConfettiPainter(
            pieces: front ? _overCard : _behindCard,
            progress: _at(0.06, 1, curve: Curves.linear),
            lift: 105,
          ),
        ),
      ),
    );
  }

  /// A landscape phone leaves barely 300dp under the top bar, which the
  /// stacked card overruns - the last button lands off screen. Short and wide
  /// viewports get a two-column card instead: seal and headline on the left,
  /// the buttons on the right. Tablets keep the stacked card.
  Widget _card(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxHeight < 430 && constraints.maxWidth >= 520;
        return Container(
          constraints: BoxConstraints(maxWidth: wide ? 520 : 330),
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: wide
              ? const EdgeInsets.fromLTRB(24, 22, 24, 22)
              : const EdgeInsets.fromLTRB(24, 30, 24, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [PeepoColors.panelRaised, PeepoColors.panel],
            ),
            border: Border.all(
              color: PeepoColors.teal,
              width: PeepoColors.strokeWidth,
            ),
            boxShadow: [
              const BoxShadow(
                color: PeepoColors.shadow,
                blurRadius: 44,
                offset: Offset(0, 18),
              ),
              BoxShadow(
                color: PeepoColors.teal.withValues(alpha: 0.22),
                blurRadius: 70,
                spreadRadius: -14,
              ),
            ],
          ),
          child: wide
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _headline(sealSize: 78, titleSize: 24),
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _actions(context, wide: true),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._headline(sealSize: 92, titleSize: 26),
                    const SizedBox(height: 22),
                    ..._actions(context, wide: false),
                  ],
                ),
        );
      },
    );
  }

  /// Seal, rating and the two lines of copy - the half of the card that says
  /// what happened, as opposed to what to do next.
  List<Widget> _headline({
    required double sealSize,
    required double titleSize,
  }) {
    return [
      _seal(sealSize),
      if (widget.stars case final stars?) ...[
        const SizedBox(height: 14),
        _rise(_starsAt, _StarRow(stars: stars)),
      ],
      const SizedBox(height: 18),
      _rise(
        0.3,
        Text(
          'Level Complete!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: PeepoColors.cream,
            height: 1.1,
          ),
        ),
      ),
    ];
  }

  /// The two ways on, in the order a child is meant to reach for them.
  ///
  /// The audience starts at three, so the wording carries none of the weight:
  /// both ways to keep playing are wide cards showing where they lead. The
  /// text on each is for the parent and the eleven year old, not for the child
  /// deciding what to press. Getting out is Back, which already lands on the
  /// level list, so the card does not spend a third button saying it again.
  List<Widget> _actions(BuildContext context, {required bool wide}) {
    final hasNext = widget.onNextLevel != null;
    return [
      if (hasNext) ...[
        _rise(0.38, _nextLevelButton(compact: wide)),
        SizedBox(height: wide ? 10 : 12),
      ],
      _rise(0.45, _playAgainButton(compact: wide, primary: !hasNext)),
    ];
  }

  /// Where you are going, drawn rather than named: the next level's backdrop
  /// behind its own name, with a gold go arrow beating on the end of it.
  Widget _nextLevelButton({required bool compact}) {
    final height = compact ? 76.0 : 92.0;
    final badge = compact ? 52.0 : 62.0;
    final thumbnail = widget.nextLevelThumbnail;
    return SizedBox(
      height: height,
      child: Material(
        color: PeepoColors.tealDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
          side: const BorderSide(
            color: PeepoColors.teal,
            width: PeepoColors.strokeWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onNextLevel,
          child: Row(
            children: [
              // A round window on the level being offered, the same art the
              // level list uses, so the two read as the same place.
              Padding(
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: SizedBox.square(
                    dimension: height - 12,
                    child: thumbnail == null
                        ? const ColoredBox(color: PeepoColors.panelRaised)
                        : Image.asset(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => const ColoredBox(
                              color: PeepoColors.panelRaised,
                            ),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    widget.nextLevelName ?? 'Next Level',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: PeepoColors.cream,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _beating(
                  Container(
                    width: badge,
                    height: badge,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: PeepoColors.sealGradient,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PeepoColors.shadowSoft,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: badge * 0.62,
                      color: PeepoColors.outline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The same room again, hidden from scratch.
  ///
  /// Placement happens at load, so this is a different arrangement rather than
  /// the room the player has just learned - which is what the second line
  /// says, for whoever on the sofa can read it. A three-year-old gets the
  /// backdrop instead: same picture as the room they finished, so it reads as
  /// "here again" against the next level's "somewhere else".
  ///
  /// Wears the go button's shape a size down, so the two read as the same kind
  /// of choice with an obvious first. On the last level, where there is no next
  /// room to offer, it takes the gold badge instead - but never the beat, which
  /// stays the one moving thing on the card.
  Widget _playAgainButton({required bool compact, required bool primary}) {
    final height = compact ? 64.0 : 76.0;
    final badge = compact ? 44.0 : 52.0;
    final thumbnail = widget.thumbnail;
    final go = Container(
      width: badge,
      height: badge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: primary
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: PeepoColors.sealGradient,
              )
            : null,
        color: primary ? null : PeepoColors.panelRaised,
        boxShadow: const [
          BoxShadow(
            color: PeepoColors.shadowSoft,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.replay_rounded,
        size: badge * 0.62,
        color: primary ? PeepoColors.outline : PeepoColors.cream,
      ),
    );
    return SizedBox(
      height: height,
      child: Material(
        color: PeepoColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
          side: const BorderSide(
            color: PeepoColors.rim,
            width: PeepoColors.strokeWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPlayAgain,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: ClipOval(
                  child: SizedBox.square(
                    dimension: height - 12,
                    child: thumbnail == null
                        ? const ColoredBox(color: PeepoColors.panelRaised)
                        : Image.asset(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, __) => const ColoredBox(
                              color: PeepoColors.panelRaised,
                            ),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Play Again',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: PeepoColors.cream,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'New hiding places',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: PeepoColors.sunny.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.only(right: 8), child: go),
            ],
          ),
        ),
      ),
    );
  }

  /// The same gold seal the level list stamps on a finished card, at full
  /// size and with Peepo inside it, swinging into place over a faint glow.
  Widget _seal(double size) {
    final pop = _at(0.06, 0.5, curve: Curves.elasticOut);
    final glow = _at(0.12, 0.7, curve: Curves.easeOut);
    return Transform.rotate(
      angle: (1 - pop) * -0.4,
      child: Transform.scale(
        scale: 0.4 + 0.6 * pop,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [PeepoColors.cream, PeepoColors.sunny, PeepoColors.beak],
            ),
            boxShadow: [
              BoxShadow(
                color: PeepoColors.sunny.withValues(alpha: 0.4 * glow),
                blurRadius: 34,
                spreadRadius: 2,
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [PeepoColors.panel, PeepoColors.ground],
              ),
            ),
            child: Center(
              child: Peepo(pose: PeepoPose.cheer, size: size * 0.61),
            ),
          ),
        ),
      ),
    );
  }

  /// Each control fades up a beat after the one above it.
  Widget _rise(double begin, Widget child) {
    final t = _at(begin, begin + 0.22);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
    );
  }
}

/// One scrap of paper: where it is thrown, how fast, and how it tumbles.
/// The rating on the level-complete card, for the bands old enough to want
/// one. Stars that were not earned are drawn as outlines rather than left out,
/// so the row reads as a rating and not as a smaller prize.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stars of 3 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 34,
                color: i <= stars
                    ? PeepoColors.sunny
                    : PeepoColors.sunny.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Confetti {
  /// [front] scraps pass over the card, so they are thrown harder and drawn
  /// bigger - they read as nearer the player.
  _Confetti(Random random, {required this.front})
    : angle = random.nextDouble() * 2 * pi,
      speed = (front ? 300 : 190) + random.nextDouble() * 280,
      length = (front ? 10 : 7) + random.nextDouble() * 9,
      width = (front ? 4 : 3) + random.nextDouble() * 4,
      spin = (random.nextDouble() - 0.5) * 14,
      delay = random.nextDouble() * 0.18,
      ribbon = random.nextBool(),
      color = _palette[random.nextInt(_palette.length)];

  final bool front;

  static const _palette = PeepoColors.confetti;

  final double angle;
  final double speed;
  final double length;
  final double width;
  final double spin;
  final double delay;
  final bool ribbon;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.pieces,
    required this.progress,
    required this.lift,
  });

  final List<_Confetti> pieces;
  final double progress;

  /// How far above the middle of the screen the burst starts.
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final origin = size.center(Offset(0, -lift));
    final paint = Paint()..style = PaintingStyle.fill;
    for (final piece in pieces) {
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      // Thrown outwards fast, then slowed by drag and pulled down by gravity.
      final flung = Curves.decelerate.transform(t) * piece.speed;
      final offset = Offset(
        origin.dx + cos(piece.angle) * flung,
        origin.dy + sin(piece.angle) * flung + 320 * t * t,
      );
      final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
      paint.color = piece.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(piece.angle + piece.spin * t);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: piece.length,
        // Scraps flip as they fall, so their faces come and go edge on.
        height:
            piece.width * (piece.ribbon ? cos(piece.spin * t * 2).abs() : 1),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

/// The hint control: a little glowing lantern-glass orb rather than a flat
/// toolbar icon. It breathes while a hint is available and goes cold and
/// unlit once the level is complete.
class _HintButton extends StatefulWidget {
  const _HintButton({required this.onPressed, this.remaining});

  /// Null once there is nothing left to hint at, which also dims the orb.
  final VoidCallback? onPressed;

  /// Hints the player has left, where their band limits them. Null means as
  /// many as they like, and then nothing is counted at them.
  final int? remaining;

  @override
  State<_HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends State<_HintButton>
    with SingleTickerProviderStateMixin {
  static const _size = 44.0;

  /// A short burst of breathing rather than a forever-running loop: an
  /// endless ticker would keep the widget tree from ever settling.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _down = false;

  @override
  void initState() {
    super.initState();
    if (widget.onPressed != null) _pulse.forward(from: 0);
  }

  @override
  void didUpdateWidget(_HintButton old) {
    super.didUpdateWidget(old);
    final lit = widget.onPressed != null;
    if (lit && old.onPressed == null) {
      _pulse.forward(from: 0);
    } else if (!lit) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.onPressed != null;
    final left = widget.remaining;
    final orb = Tooltip(
      message: left == null ? 'Hint' : 'Hint - $left left',
      child: Semantics(
        button: true,
        enabled: lit,
        label: left == null ? 'Hint' : 'Hint, $left left',
        child: GestureDetector(
          onTapDown: lit ? (_) => setState(() => _down = true) : null,
          onTapCancel: lit ? () => setState(() => _down = false) : null,
          onTapUp: lit
              ? (_) {
                  setState(() => _down = false);
                  _pulse.forward(from: 0);
                  widget.onPressed!();
                }
              : null,
          child: AnimatedScale(
            scale: _down ? 0.88 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                // Two breaths across the run, then the orb rests warm.
                final glow = lit ? sin(pi * _pulse.value * 2).abs() : 0.0;
                // A brass ring around a lantern lens: the rim catches light
                // from the top left, the glass glows from within.
                return Container(
                  width: _size,
                  height: _size,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: lit
                          ? const [
                              PeepoColors.cream,
                              PeepoColors.sunny,
                              PeepoColors.beak,
                            ]
                          : const [
                              PeepoColors.panelRaised,
                              PeepoColors.panel,
                              PeepoColors.ground,
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: PeepoColors.sunny.withValues(
                          alpha: lit ? 0.20 + 0.28 * glow : 0,
                        ),
                        blurRadius: 10 + 10 * glow,
                        spreadRadius: 1 + 2 * glow,
                      ),
                      const BoxShadow(
                        color: PeepoColors.shadowSoft,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.4, -0.5),
                        radius: 1.0,
                        colors: lit
                            ? const [
                                PeepoColors.cream,
                                PeepoColors.sunny,
                                PeepoColors.beak,
                              ]
                            : const [
                                PeepoColors.panel,
                                PeepoColors.ground,
                                PeepoColors.outline,
                              ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lightbulb,
                        size: 20,
                        color: lit ? PeepoColors.onAccent : PeepoColors.faint,
                        shadows: lit
                            ? [
                                Shadow(
                                  color: PeepoColors.cream.withValues(
                                    alpha: 0.5 + 0.3 * glow,
                                  ),
                                  blurRadius: 5 + 4 * glow,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    if (left == null) return orb;
    // The allowance only appears where there is one to run out of, so the
    // younger bands never see a number counting down at them.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        orb,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: PeepoColors.ground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: PeepoColors.rim),
            ),
            child: Text(
              '$left',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: lit ? PeepoColors.sunny : PeepoColors.faint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
