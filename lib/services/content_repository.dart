import '../models/channel.dart';
import '../models/video.dart';
import 'youtube_api_service.dart';

/// Data source for channel search and the personalized video feed.
///
/// The app runs in two modes:
///   * live   - backed by the YouTube Data API when a key is configured;
///   * offline - the built-in mock data, so the app still works without a key.
///
/// Screens and services depend on this abstraction, keeping the API code
/// isolated in the services layer and easily swappable.
abstract class ContentRepository {
  /// Whether the repository serves real data from the network.
  bool get isLive;

  Future<List<Channel>> searchChannels(String query);

  Future<List<Channel>> fetchChannelDetails(List<String> ids);

  Future<List<Video>> fetchRecentVideos(Set<String> channelIds);
}

/// Live repository backed by the YouTube Data API v3.
class YoutubeContentRepository implements ContentRepository {
  YoutubeContentRepository(this._api);

  final YoutubeApiService _api;

  @override
  bool get isLive => _api.hasApiKey;

  @override
  Future<List<Channel>> searchChannels(String query) =>
      _api.searchChannels(query);

  @override
  Future<List<Channel>> fetchChannelDetails(List<String> ids) =>
      _api.getChannelDetails(ids);

  @override
  Future<List<Video>> fetchRecentVideos(Set<String> channelIds) =>
      _api.getRecentVideos(channelIds.toList());
}
