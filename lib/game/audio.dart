import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../models/settings.dart';

/// Tells a screen when the route it pushed has gone and it is on top again.
///
/// A screen cannot work that out by awaiting the route it pushed. A level that
/// replaces itself with the next one completes the pushed route's future
/// synchronously, so the level list would hand its own music back over the top
/// of the track the next level has only just asked for. This fires when the
/// screen is genuinely uncovered, and never on a replacement.
final RouteObserver<ModalRoute<dynamic>> musicRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

/// A cue the game plays over the music, and the file it lives in.
///
/// How loud each one is was decided when the file was written, not here - see
/// `tools/audio.py`. Ranking them against each other in the player would mean
/// the ranking changed with the device volume, and the point of it is that
/// finishing a level is always the loudest thing that happens and a tap on
/// nothing is always the quietest.
enum Sfx {
  found('found.wav'),
  miss('miss.wav'),
  hint('hint.wav'),
  complete('complete.wav'),
  reveal('reveal.wav'),
  tap('tap.wav'),
  star1('star_1.wav'),
  star2('star_2.wav'),
  star3('star_3.wav');

  const Sfx(this.file);

  final String file;

  /// Paths are given to audioplayers without the `assets/` in front: its asset
  /// cache puts that there itself.
  String get source => 'audio/sfx/$file';

  /// The ping for the [n]th star landing on the level-complete card, counted
  /// from one. They rise, so three stars sound like more than two without a
  /// child having to count them.
  static Sfx star(int n) => [star1, star2, star3][(n - 1).clamp(0, 2)];
}

/// Every sound the game makes: one looping track under each screen, and a
/// short cue for each thing that happens.
///
/// One instance for the whole app, made in `main()` and handed down the way
/// the settings and the progress are. It owns the two things a screen should
/// not have to think about:
///
/// - **Which track.** A screen says what it wants playing and forgets about
///   it. Asking for the track that is already on is free, so a rebuild costs
///   nothing and the music does not restart when a level does.
/// - **When nothing should play.** Music off, effects off, or the app in the
///   background: all three are handled here, in one place, so no caller has to
///   check a setting before making a sound.
///
/// Nothing about it is on the network. The tracks and the cues are files in
/// the bundle, which is the only kind of audio a COPPA app can afford.
class GameAudio with WidgetsBindingObserver {
  GameAudio({required AppSettings settings})
    : _settings = settings,
      _silent = false {
    settings.addListener(_request);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Audio that never happens.
  ///
  /// The plugin is not touched, not even to make a player, which is what tests
  /// and the layout tool need: there is no audio device behind either of them
  /// and every call into the plugin would throw.
  GameAudio.silent() : _settings = null, _silent = true;

  /// The track under the level list and everything reached from it. Levels
  /// use their own id, so a level folder and a track file share a name.
  static const menuTrack = 'menu';

  final AppSettings? _settings;
  final bool _silent;

  /// The two music players the crossfade needs: one playing out, one playing
  /// in. Made on first use so [GameAudio.silent] can exist without them.
  final List<AudioPlayer> _deck = [];

  /// The player a listener can hear. The other one is free to be loaded into.
  int _live = 0;

  /// What each deck player was last set to, so a transition that interrupts a
  /// fade picks the volumes up where that fade left them rather than jumping
  /// to the top of a fresh one.
  final List<double> _volume = [0, 0];

  /// One pool per cue, each holding its file decoded and ready. A pool rather
  /// than a player because a child finding two things in the same second
  /// should hear two chimes, not one chime cut off.
  final Map<Sfx, AudioPool> _pools = {};

  /// The decodes in flight, kept so a cue asked for while it is still loading
  /// waits for that load instead of being dropped or decoded a second time.
  final Map<Sfx, Future<AudioPool?>> _loading = {};

  /// What the screen on top wants playing, and what the last queued
  /// transition was asked to make of it. They differ while music is off or
  /// the app is in the background.
  String? _wanted;
  String? _target;

  bool _onScreen = true;
  bool _disposed = false;

  /// Transitions run one at a time. Overlapping them is the one thing a
  /// crossfade cannot survive: both share the same two players, so each would
  /// be loading, resuming and stopping the player the other is using.
  Future<void> _queue = Future<void>.value();

  /// Bumped by every change of mind, so a fade that is still stepping when the
  /// next one is asked for gives up instead of fighting it.
  int _generation = 0;

  /// Long enough to be heard as one piece of music becoming another, short
  /// enough to be over before a level has finished materialising.
  static const _fadeStep = Duration(milliseconds: 50);
  static const _fadeSteps = 14;

  /// Tells the platform how the game's audio should sit beside everything else
  /// on the device. Called once, before the first sound.
  ///
  /// Both halves say the same thing: be a guest. On iOS the ambient category
  /// means the ring/silent switch turns the game off, which is what a parent
  /// flicking that switch in a waiting room is asking for. On Android asking
  /// for no audio focus means a podcast the grown-up had on keeps playing
  /// rather than being stopped by a children's game.
  static Future<void> configure() async {
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
  }

  /// Decodes every cue up front.
  ///
  /// Worth doing on the level list, where there is a person reading it, so
  /// that the first find in the first level is not the one find that arrives
  /// late.
  Future<void> warm() async {
    if (_silent) return;
    for (final cue in Sfx.values) {
      await _pool(cue);
    }
  }

  /// Plays [cue] now, or does nothing if a grown-up turned the effects off.
  void play(Sfx cue) {
    if (_silent || !(_settings!.soundEffects)) return;
    final ready = _pools[cue];
    if (ready != null) {
      _guard(ready.start());
      return;
    }
    // Not decoded yet, or still decoding: play it as soon as it is there.
    // Late is better than missing, and it only ever happens once per cue.
    _guard(_pool(cue).then((pool) => pool?.start()));
  }

  /// The track the screen on top has asked for, whether or not it is audible.
  ///
  /// Only a test has any business reading this: it is how the navigation that
  /// hands the music from screen to screen is checked without an audio device.
  @visibleForTesting
  String? get track => _wanted;

  /// Says which track belongs under the screen that is now on top.
  ///
  /// Idempotent: asking for the track that is already playing changes
  /// nothing, so a screen may call this from every build.
  void playMusic(String track) {
    if (_wanted == track) return;
    _wanted = track;
    _request();
  }

  /// Takes the music away with nothing to replace it - the app is closing, or
  /// a screen with no track of its own has come up.
  void stopMusic() {
    if (_wanted == null) return;
    _wanted = null;
    _request();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The music stops when the game goes off screen and comes back when it
    // returns. Off screen means off screen, not merely out of focus: a game
    // window behind a browser, or the app switcher held open, is
    // [AppLifecycleState.inactive] and still perfectly visible, and cutting
    // the music every time something else took the keyboard would be a game
    // that keeps flinching.
    final onScreen =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (onScreen == _onScreen) return;
    _onScreen = onScreen;
    _request();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_silent) return;
    _settings!.removeListener(_request);
    WidgetsBinding.instance.removeObserver(this);
    for (final player in _deck) {
      await player.dispose();
    }
    for (final pool in _pools.values) {
      await pool.dispose();
    }
  }

  /// Queues bringing what is sounding into line with what should be.
  ///
  /// Everything that can change the answer - the screen, the setting, the
  /// lifecycle - comes through here, so there is one description of what
  /// should be playing rather than three that have to agree.
  void _request() {
    if (_silent || _disposed) return;
    final wanted = _onScreen && _settings!.music ? _wanted : null;
    if (wanted == _target) return;
    _target = wanted;
    // A fade still stepping belongs to a decision that has just been
    // overtaken. It gives up on its next step, so the transition queued here
    // begins within a step rather than at the end of a fade.
    final generation = ++_generation;
    _queue = _queue
        .then((_) => _sync(wanted, generation))
        .catchError((Object error) => debugPrint('peepo: music - $error'));
  }

  /// One transition, run with the queue to itself.
  Future<void> _sync(String? wanted, int generation) async {
    // Overtaken while it waited its turn: the transition behind it in the
    // queue is the one that knows what should be playing.
    if (_disposed || generation != _generation) return;

    if (_deck.isEmpty) {
      if (wanted == null) return;
      for (var i = 0; i < 2; i++) {
        final player = AudioPlayer(playerId: 'peepo-music-$i');
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(0);
        _deck.add(player);
      }
    }

    final out = _live;
    if (wanted == null) {
      await _fade(out: out, into: null, generation: generation);
      return;
    }

    final into = 1 - out;
    // Whatever is in the idle player is over: either the last fade stopped it,
    // or the last fade was interrupted and left it sounding under the track
    // that replaced it.
    await _deck[into].stop();
    await _setVolume(into, 0);
    try {
      await _deck[into].setSource(AssetSource('audio/music/$wanted.mp3'));
      await _deck[into].resume();
    } catch (error) {
      // A level whose track was never generated. It plays without one rather
      // than taking the screen down with it, and the track it replaced goes
      // anyway: the last level's music under this one would be worse than
      // silence. tools/audio.sh music <id>, and test/audio_test.dart is where
      // this should have been caught.
      debugPrint('peepo: no music for $wanted - $error');
      await _fade(out: out, into: null, generation: generation);
      return;
    }
    // Claimed the moment the player is sounding, so an interrupted fade still
    // leaves this pointing at the track a listener can hear.
    _live = into;
    if (generation != _generation || _disposed) return;
    await _fade(out: out, into: into, generation: generation);
  }

  /// Walks deck player [out] down and [into] up together, and stops [out] at
  /// the bottom.
  ///
  /// Equal-power rather than straight lines, for the same reason the tracks
  /// themselves are joined that way: two unrelated pieces of music summed with
  /// linear fades sag in the middle, and the middle is the seam.
  Future<void> _fade({
    required int out,
    required int? into,
    required int generation,
  }) async {
    // Where the volumes actually are, which is not always the ends: this fade
    // may be picking up after one that was interrupted part of the way down.
    final from = _volume[out];
    final to = into == null ? 0.0 : _volume[into];
    for (var step = 1; step <= _fadeSteps; step++) {
      await Future<void>.delayed(_fadeStep);
      // Somebody changed their mind mid-fade. Whoever did owns the volumes now.
      if (generation != _generation || _disposed) return;
      final t = step / _fadeSteps;
      await _setVolume(out, from * _equalPower(1 - t));
      if (into != null) {
        await _setVolume(into, to + (1 - to) * _equalPower(t));
      }
    }
    // Checked again after the last volume went in: stopping a player the next
    // transition has already loaded and resumed would leave the game silent.
    if (generation != _generation || _disposed) return;
    await _deck[out].stop();
    _volume[out] = 0;
  }

  Future<void> _setVolume(int index, double value) async {
    _volume[index] = value;
    await _deck[index].setVolume(value);
  }

  static double _equalPower(double t) => sqrt(t.clamp(0.0, 1.0));

  Future<AudioPool?> _pool(Sfx cue) {
    final existing = _pools[cue];
    if (existing != null) return Future.value(existing);
    // Two warm() calls, or a play() racing warm(), share the one decode. Two
    // pools for the same cue would leak one of them, and turning the second
    // caller away would drop the sound it asked for.
    return _loading[cue] ??= _load(cue);
  }

  Future<AudioPool?> _load(Sfx cue) async {
    try {
      final pool = await AudioPool.create(
        source: AssetSource(cue.source),
        // One is enough for almost everything; the second covers two finds in
        // the same moment, which is the only cue that ever overlaps itself.
        maxPlayers: 2,
      );
      if (_disposed) {
        await pool.dispose();
        return null;
      }
      return _pools[cue] = pool;
    } catch (error) {
      debugPrint('peepo: could not load ${cue.source} - $error');
      return null;
    } finally {
      _loading.remove(cue);
    }
  }

  /// Runs [work] for its effect and turns a failure into a line in the log.
  ///
  /// Sound is the one part of the game allowed to fail without the game
  /// failing: an interrupted audio session or a device with nothing to play
  /// out of should cost a cue, not an uncaught error in the zone.
  void _guard(Future<Object?> work) {
    unawaited(
      work.catchError((Object error) {
        debugPrint('peepo: audio - $error');
        return null;
      }),
    );
  }
}
