import '../utils/formats.dart';

/// A single video in the feed. Videos belong to a [Channel] via [channelId].
class Video {
  const Video({
    required this.id,
    required this.channelId,
    required this.title,
    required this.duration,
    required this.publishedAt,
    required this.views,
  });

  final String id;
  final String channelId;
  final String title;
  final Duration duration;
  final DateTime publishedAt;
  final int views;

  String get durationLabel => formatDuration(duration);
  String get viewsLabel => '${formatCompactNumber(views)} views';
  String get publishedLabel => formatRelativeTime(publishedAt);
}
