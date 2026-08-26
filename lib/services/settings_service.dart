import 'package:flutter/material.dart';

import '../models/preferences.dart';

/// Owns the user's preferences and notifies listeners on change.
class SettingsService extends ChangeNotifier {
  SettingsService({Preferences? initial})
      : _preferences = initial ?? const Preferences();

  Preferences _preferences;
  Preferences get preferences => _preferences;

  ThemeMode get themeMode => _preferences.themeMode;
  bool get autoplay => _preferences.autoplay;
  bool get showViewCounts => _preferences.showViewCounts;

  void setThemeMode(ThemeMode mode) {
    _preferences = _preferences.copyWith(themeMode: mode);
    notifyListeners();
  }

  void setAutoplay(bool value) {
    _preferences = _preferences.copyWith(autoplay: value);
    notifyListeners();
  }

  void setShowViewCounts(bool value) {
    _preferences = _preferences.copyWith(showViewCounts: value);
    notifyListeners();
  }
}
