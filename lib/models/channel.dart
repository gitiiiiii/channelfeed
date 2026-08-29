import 'package:flutter/material.dart';

import '../utils/formats.dart';

/// A YouTube channel that a user can follow or unfollow.
class Channel {
  const Channel({
    required this.id,
    required this.name,
    this.handle,
    required this.subscriberCount,
    required this.description,
    required this.brandColor,
    this.thumbnailUrl,
  });

  final String id;
  final String name;

  /// Channel handle (e.g. `@auroralabs`). Absent when the API has not
  /// reported one for this channel.
  final String? handle;
  final int subscriberCount;
  final String description;
  final Color brandColor;

  /// Remote artwork for the channel when it comes from a live API. `null` in
  /// offline/mock mode, where the UI falls back to generated avatars.
  final String? thumbnailUrl;

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  String get subscriberLabel =>
      '${formatCompactNumber(subscriberCount)} subscribers';

  /// The public YouTube page for this channel.
  String get youtubeUrl {
    final handle = this.handle;
    if (handle != null && handle.isNotEmpty) {
      final at = handle.startsWith('@') ? handle : '@$handle';
      return 'https://www.youtube.com/$at';
    }
    return 'https://www.youtube.com/channel/$id';
  }

  Channel copyWith({
    String? name,
    String? handle,
    int? subscriberCount,
    String? description,
    Color? brandColor,
    String? thumbnailUrl,
  }) {
    return Channel(
      id: id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      description: description ?? this.description,
      brandColor: brandColor ?? this.brandColor,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
