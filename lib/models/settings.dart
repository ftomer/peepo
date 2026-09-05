import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'difficulty.dart';

/// Everything a grown-up has chosen, kept on the device.
///
/// One household setting rather than one per child: the age band and the
/// levels finished are shared by whoever picks up the tablet. Profiles would
/// change what is stored here and nothing else that reads it.
///
/// Nothing in here leaves the device and none of it identifies anybody, which
/// is what COPPA and both stores' family programmes require of an app for
/// under-13s.
class AppSettings extends ChangeNotifier {
  AppSettings({
    AgeBand band = AgeBand.look,
    bool assistWhenStuck = true,
    bool ageChosen = false,
    bool music = true,
    bool soundEffects = true,
    SharedPreferences? store,
  }) : _band = band,
       _assistWhenStuck = assistWhenStuck,
       _ageChosen = ageChosen,
       _music = music,
       _soundEffects = soundEffects,
       _store = store;

  static const _bandKey = 'settings.ageBand';
  static const _assistKey = 'settings.assistWhenStuck';
  static const _ageChosenKey = 'settings.ageChosen';
  static const _musicKey = 'settings.music';
  static const _effectsKey = 'settings.soundEffects';

  /// Null until [load] has run, and in tests that build settings by hand -
  /// in-memory settings work exactly the same, they just forget.
  final SharedPreferences? _store;

  AgeBand _band;
  bool _assistWhenStuck;
  bool _ageChosen;
  bool _music;
  bool _soundEffects;

  /// The age band every level is played at.
  AgeBand get band => _band;

  set band(AgeBand value) {
    if (_band == value && _ageChosen) return;
    _band = value;
    _ageChosen = true;
    _store?.setString(_bandKey, value.id);
    _store?.setBool(_ageChosenKey, true);
    notifyListeners();
  }

  /// Whether the game may quietly help a player who is stuck. Assist only
  /// ever adds help - see [DifficultyProfile.withAssist].
  bool get assistWhenStuck => _assistWhenStuck;

  set assistWhenStuck(bool value) {
    if (_assistWhenStuck == value) return;
    _assistWhenStuck = value;
    _store?.setBool(_assistKey, value);
    notifyListeners();
  }

  /// Whether a track plays under the screens.
  ///
  /// Separate from [soundEffects] because they are turned off for different
  /// reasons: the music goes when the game is being played beside somebody
  /// else, the effects go when the noise itself is the problem. A grown-up
  /// who wants one of those rarely wants both.
  bool get music => _music;

  set music(bool value) {
    if (_music == value) return;
    _music = value;
    _store?.setBool(_musicKey, value);
    notifyListeners();
  }

  /// Whether the game answers a find, a miss, a hint and a finished level with
  /// a sound.
  bool get soundEffects => _soundEffects;

  set soundEffects(bool value) {
    if (_soundEffects == value) return;
    _soundEffects = value;
    _store?.setBool(_effectsKey, value);
    notifyListeners();
  }

  /// False until a grown-up has picked an age, which is what the first-run
  /// age card asks for. Until then the game plays at [AgeBand.look].
  bool get ageChosen => _ageChosen;

  /// How this device's levels are hidden and helped.
  DifficultyProfile get profile => _band.profile;

  /// Reads the stored settings, falling back to the middle band.
  static Future<AppSettings> load() async {
    final store = await SharedPreferences.getInstance();
    return AppSettings(
      band: AgeBand.byId(store.getString(_bandKey)) ?? AgeBand.look,
      assistWhenStuck: store.getBool(_assistKey) ?? true,
      ageChosen: store.getBool(_ageChosenKey) ?? false,
      music: store.getBool(_musicKey) ?? true,
      soundEffects: store.getBool(_effectsKey) ?? true,
      store: store,
    );
  }
}
