import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which levels the player has finished.
///
/// Kept on the device and nowhere else: a child's progress is the only thing
/// this app remembers about them, and it never leaves the tablet.
///
/// Built without a store - which is how the tests build it - it works exactly
/// the same and forgets on restart.
class LevelProgress extends ChangeNotifier {
  LevelProgress({Set<String>? completed, SharedPreferences? store})
    : _completed = {...?completed},
      _store = store;

  static const _completedKey = 'progress.completed';

  final Set<String> _completed;
  final SharedPreferences? _store;

  Set<String> get completed => Set.unmodifiable(_completed);

  bool isComplete(String levelId) => _completed.contains(levelId);

  void markComplete(String levelId) {
    if (!_completed.add(levelId)) return;
    _save();
    notifyListeners();
  }

  /// Wipes the record of finished levels - the one destructive thing in the
  /// settings screen, and the reason that screen sits behind a grown-up gate.
  void reset() {
    if (_completed.isEmpty) return;
    _completed.clear();
    _save();
    notifyListeners();
  }

  void _save() => _store?.setStringList(_completedKey, _completed.toList());

  static Future<LevelProgress> load() async {
    final store = await SharedPreferences.getInstance();
    return LevelProgress(
      completed: {...?store.getStringList(_completedKey)},
      store: store,
    );
  }
}
