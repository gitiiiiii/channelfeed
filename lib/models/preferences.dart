import 'package:flutter/material.dart';

/// User preferences managed from the Profile tab.
class Preferences {
  const Preferences({
    this.themeMode = ThemeMode.system,
    this.autoplay = true,
    this.showViewCounts = true,
  });

  final ThemeMode themeMode;
  final bool autoplay;
  final bool showViewCounts;

  Preferences copyWith({
    ThemeMode? themeMode,
    bool? autoplay,
    bool? showViewCounts,
  }) {
    return Preferences(
      themeMode: themeMode ?? this.themeMode,
      autoplay: autoplay ?? this.autoplay,
      showViewCounts: showViewCounts ?? this.showViewCounts,
    );
  }
}
