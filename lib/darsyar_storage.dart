import 'package:shared_preferences/shared_preferences.dart';

/// A small persistence boundary for DarsYar's existing SharedPreferences data.
///
/// Storage keys and serialized values intentionally remain unchanged so
/// existing installations and exported backups stay compatible.
class DarsYarStorage {
  Future<void> _writeQueue = Future<void>.value();

  static const _readKeys = <String>{
    'darsyar.tasks',
    'darsyar.studySessions',
    'darsyar.results',
    'darsyar.exams',
    'darsyar.answers',
    'darsyar.answerKey',
    'darsyar.marked',
    'darsyar.count',
    'darsyar.activeExamId',
  };

  Future<DarsYarStorageSnapshot> readSnapshot() async {
    final preferences = await SharedPreferences.getInstance();
    final values = <String, Object?>{};
    final presentKeys = <String>{};

    for (final key in _readKeys) {
      try {
        if (preferences.containsKey(key)) presentKeys.add(key);
        values[key] = preferences.get(key);
      } catch (_) {
        // A damaged or unsupported key must not block other stored sections.
      }
    }

    return DarsYarStorageSnapshot._(values, presentKeys);
  }

  /// Writes a group of string values as one best-effort transaction.
  ///
  /// SharedPreferences has no native multi-key transaction, so previous
  /// values are captured and restored if any write fails.
  Future<bool> writeStrings(Map<String, String> values) {
    final snapshot = Map<String, String>.unmodifiable(values);
    final pending = _writeQueue.then((_) => _writeTransaction(snapshot));
    _writeQueue = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  Future<bool> _writeTransaction(Map<String, String> values) async {
    if (values.isEmpty) return true;

    SharedPreferences? preferences;
    Map<String, Object?>? previousValues;
    try {
      final store = await SharedPreferences.getInstance();
      preferences = store;
      previousValues = {
        for (final key in values.keys) key: store.get(key),
      };

      for (final entry in values.entries) {
        if (!await store.setString(entry.key, entry.value)) {
          await _rollback(store, previousValues);
          return false;
        }
      }
      return true;
    } catch (_) {
      if (preferences != null && previousValues != null) {
        await _rollback(preferences, previousValues);
      }
      return false;
    }
  }

  Future<void> _rollback(
    SharedPreferences preferences,
    Map<String, Object?> previousValues,
  ) async {
    for (final entry in previousValues.entries) {
      try {
        final value = entry.value;
        if (value == null) {
          await preferences.remove(entry.key);
        } else if (value is String) {
          await preferences.setString(entry.key, value);
        } else if (value is bool) {
          await preferences.setBool(entry.key, value);
        } else if (value is int) {
          await preferences.setInt(entry.key, value);
        } else if (value is double) {
          await preferences.setDouble(entry.key, value);
        } else if (value is List<String>) {
          await preferences.setStringList(entry.key, value);
        } else {
          await preferences.remove(entry.key);
        }
      } catch (_) {
        // Best effort only; preserve the original transaction outcome.
      }
    }
  }
}

class DarsYarStorageSnapshot {
  const DarsYarStorageSnapshot._(this._values, this._presentKeys);

  final Map<String, Object?> _values;
  final Set<String> _presentKeys;

  String? stringValue(String key) {
    final value = _values[key];
    return value is String ? value : null;
  }

  int? intValue(String key) {
    final value = _values[key];
    return value is int ? value : null;
  }

  bool containsKey(String key) => _presentKeys.contains(key);
}
