import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/preferences.dart';

/// Persists user preferences and the followed-channel selection via
/// [SharedPreferences] so state survives app restarts.
class LocalStore {
  static const String themeModeKey = 'prefs.themeMode';
  static const String autoplayKey = 'prefs.autoplay';
  static const String showViewCountsKey = 'prefs.showViewCounts';
  static const String followedChannelIdsKey = 'prefs.followedChannelIds';

  static Future<Preferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return Preferences(
      themeMode: _themeModeFromString(prefs.getString(themeModeKey)),
      autoplay: prefs.getBool(autoplayKey) ?? const Preferences().autoplay,
      showViewCounts: prefs.getBool(showViewCountsKey) ??
          const Preferences().showViewCounts,
    );
  }

  static Future<void> savePreferences(Preferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, preferences.themeMode.name);
    await prefs.setBool(autoplayKey, preferences.autoplay);
    await prefs.setBool(showViewCountsKey, preferences.showViewCounts);
  }

  /// Returns null when nothing was stored yet, so the caller can fall back to
  /// the app's default selection.
  static Future<Set<String>?> loadFollowedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(followedChannelIdsKey);
    if (ids == null) {
      return null;
    }
    return <String>{...ids};
  }

  static Future<void> saveFollowedIds(Set<String> selectedIds) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = selectedIds.toList()..sort();
    await prefs.setStringList(followedChannelIdsKey, ids);
  }

  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
