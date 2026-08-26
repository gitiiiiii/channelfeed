import 'package:flutter/foundation.dart';

import '../models/video.dart';
import 'channel_service.dart';

/// How the Home feed is filtered and sorted.
enum FeedFilter {
  /// Every mock video, newest first.
  all,

  /// Recent uploads (last [latestWindow]), newest first.
  latest,

  /// Only videos from followed channels, newest first.
  channels,
}

/// Builds the personalized feed from the channel directory and the user's
/// followed channels.
class FeedService extends ChangeNotifier {
  FeedService({
    required this.channelService,
    required List<Video> videos,
  }) : _allVideos = List.unmodifiable(videos) {
    channelService.addListener(notifyListeners);
  }

  static const Duration latestWindow = Duration(days: 30);

  final ChannelService channelService;
  final List<Video> _allVideos;

  FeedFilter _filter = FeedFilter.latest;
  FeedFilter get filter => _filter;

  set filter(FeedFilter value) {
    if (value == _filter) {
      return;
    }
    _filter = value;
    notifyListeners();
  }

  bool get hasVideos => _allVideos.isNotEmpty;

  List<Video> get _sortedByNewest =>
      [..._allVideos]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  List<Video> get allVideos => _sortedByNewest;

  List<Video> get recentVideos {
    final cutoff = DateTime.now().subtract(latestWindow);
    return _sortedByNewest
        .where((video) => video.publishedAt.isAfter(cutoff))
        .toList();
  }

  List<Video> get followedVideos => _sortedByNewest
      .where((video) => channelService.isSelected(video.channelId))
      .toList();

  /// Resolves the video list for the currently selected [FeedFilter].
  List<Video> resolve(FeedFilter filter) {
    switch (filter) {
      case FeedFilter.all:
        return allVideos;
      case FeedFilter.latest:
        return recentVideos;
      case FeedFilter.channels:
        return followedVideos;
    }
  }
}
