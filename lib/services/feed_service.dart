import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/video.dart';
import 'channel_service.dart';
import 'content_repository.dart';

/// How the Home feed is filtered and sorted.
///
/// Every mode is scoped to the user's followed channels; the feed never
/// shows videos from channels that are not selected.
enum FeedFilter {
  /// All videos from followed channels, newest first.
  all,

  /// Recent uploads (last [FeedService.latestWindow]) from followed channels,
  /// newest first.
  latest,

  /// All videos from followed channels, newest first (rendered grouped by
  /// channel on the Home screen).
  channels,
}

/// Builds the personalized feed from the channel directory and the user's
/// followed channels.
///
/// In live mode (a [ContentRepository] with [ContentRepository.isLive] true)
/// the feed is fetched from the network for the currently selected channels
/// and refreshed whenever the selection changes. Without a repository the
/// built-in mock videos are used, so the app stays fully functional offline.
class FeedService extends ChangeNotifier {
  FeedService({
    required this.channelService,
    required List<Video> videos,
    this.repository,
  }) : _allVideos = List.unmodifiable(videos) {
    channelService.addListener(_handleChannelsChanged);
    if (isLive) {
      unawaited(refresh());
    }
  }

  static const Duration latestWindow = Duration(days: 30);

  final ChannelService channelService;
  final List<Video> _allVideos;

  /// Live data source; `null` keeps the feed in offline (mock) mode.
  final ContentRepository? repository;

  FeedFilter _filter = FeedFilter.latest;
  FeedFilter get filter => _filter;

  bool _isLoading = false;
  String? _errorMessage;
  List<Video>? _liveVideos;
  Future<void>? _inflight;
  bool _refreshQueued = false;

  /// Whether the feed is backed by the live YouTube API.
  bool get isLive => repository?.isLive ?? false;

  /// True while a network refresh is in progress.
  bool get isLoading => _isLoading;

  /// Error message from the last failed refresh, or `null`.
  String? get errorMessage => _errorMessage;

  /// Whether the current source has produced any videos yet.
  bool get hasData =>
      isLive ? (_liveVideos?.isNotEmpty ?? false) : _allVideos.isNotEmpty;

  set filter(FeedFilter value) {
    if (value == _filter) {
      return;
    }
    _filter = value;
    notifyListeners();
  }

  bool get hasVideos => hasData;

  /// Re-fetches the feed for the currently selected channels. While a refresh
  /// is in flight, further calls return the same future and are coalesced
  /// into a single trailing refresh, so rapid selection changes end with
  /// fresh data and every caller awaits completion.
  Future<void> refresh() {
    if (!isLive) {
      return Future<void>.value();
    }
    final inflight = _inflight;
    if (inflight != null) {
      _refreshQueued = true;
      return inflight;
    }
    final cycle = _runRefreshCycle();
    _inflight = cycle;
    return cycle;
  }

  Future<void> _runRefreshCycle() async {
    do {
      _refreshQueued = false;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      try {
        final ids = channelService.selectedChannels.map((c) => c.id).toSet();
        _liveVideos = await repository!.fetchRecentVideos(ids);
      } catch (error) {
        _errorMessage = error.toString();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } while (_refreshQueued);
    _inflight = null;
  }

  void _handleChannelsChanged() {
    notifyListeners();
    if (isLive) {
      unawaited(refresh());
    }
  }

  List<Video> get _baseVideos =>
      isLive ? (_liveVideos ?? const <Video>[]) : _allVideos;

  List<Video> get _sortedByNewest =>
      [..._baseVideos]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

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

  List<Video> get recentFollowedVideos {
    final cutoff = DateTime.now().subtract(latestWindow);
    return followedVideos
        .where((video) => video.publishedAt.isAfter(cutoff))
        .toList();
  }

  /// Resolves the video list for the currently selected [FeedFilter].
  /// All modes are restricted to followed channels.
  List<Video> resolve(FeedFilter filter) {
    switch (filter) {
      case FeedFilter.all:
        return followedVideos;
      case FeedFilter.latest:
        return recentFollowedVideos;
      case FeedFilter.channels:
        return followedVideos;
    }
  }
}
