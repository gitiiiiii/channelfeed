import 'package:flutter/material.dart';

import '../utils/formats.dart';

/// A YouTube channel that a user can follow or unfollow.
class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.handle,
    required this.subscriberCount,
    required this.description,
    required this.brandColor,
  });

  final String id;
  final String name;
  final String handle;
  final int subscriberCount;
  final String description;
  final Color brandColor;

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  String get subscriberLabel =>
      '${formatCompactNumber(subscriberCount)} subscribers';
}
