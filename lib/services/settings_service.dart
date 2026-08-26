import 'package:flutter/material.dart';

import '../models/preferences.dart';

/// Owns the user's preferences and notifies listeners on change.
///
/// An optional [onChanged] callback is invoked after every update so the
/// caller can persist the new value (see [LocalStore]).
class SettingsService extends ChangeNotifier {
  SettingsService({
    Preferences? initial,
    Future<void> Function(Preferences preferences)? onChanged,
  }) : _preferences = initial ?? const Preferences() {
    _onChanged = onChanged;
  }

  Future<void> Function(Preferences preferences)? _onChanged;

  Preferences _preferences;
  Preferences get preferences => _preferences;

  ThemeMode get themeMode => _preferences.themeMode;
  bool get autoplay => _preferences.autoplay;
  bool get showViewCounts => _preferences.showViewCounts;

  void setThemeMode(ThemeMode mode) {
    if (mode == _preferences.themeMode) {
      return;
    }
    _preferences = _preferences.copyWith(themeMode: mode);
    _persist();
  }

  void setAutoplay(bool value) {
    if (value == _preferences.autoplay) {
      return;
    }
    _preferences = _preferences.copyWith(autoplay: value);
    _persist();
  }

  void setShowViewCounts(bool value) {
    if (value == _preferences.showViewCounts) {
      return;
    }
    _preferences = _preferences.copyWith(showViewCounts: value);
    _persist();
  }

  void _persist() {
    notifyListeners();
    _onChanged?.call(_preferences);
  }
}
