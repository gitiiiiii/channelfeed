import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/video.dart';
import '../utils/formats.dart';

/// Thrown when a YouTube Data API call cannot be completed, either because
/// the network failed, the request was rejected, or no key is configured.
class YoutubeApiException implements Exception {
  const YoutubeApiException(this.message);

  final String message;

  @override
  String toString() => 'YoutubeApiException: $message';
}

/// Minimal client for the YouTube Data API v3.
///
/// The API key is read from the `YOUTUBE_API_KEY` define (see README), so no
/// secrets end up in the repository. Results are cached briefly in memory to
/// avoid hammering the API for the same query. Isolated in the services layer
/// so the data source can be swapped out without touching the UI.
class YoutubeApiService {
  YoutubeApiService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? const String.fromEnvironment('YOUTUBE_API_KEY');

  static const String _baseHost = 'www.googleapis.com';
  static const String _basePath = '/youtube/v3';
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxResults = 12;

  final http.Client _client;
  final String _apiKey;
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Searches YouTube for channels matching [query]. Results are enriched with
  /// subscriber counts, handles, and artwork through a batched details call.
  Future<List<Channel>> searchChannels(String query,
      {int maxResults = _maxResults}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <Channel>[];
    }
    final cacheKey = 'search:$trimmed';
    final cached = _read<List<Channel>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final search = await _getJson('search', <String, String>{
      'part': 'snippet',
      'type': 'channel',
      'q': trimmed,
      'maxResults': '$maxResults',
    });
    final ids = <String?>[
      for (final item in search['items'] as List<dynamic>? ?? const <dynamic>[])
        (item as Map<String, dynamic>)['id']?['channelId'] as String?,
    ].whereType<String>().toList();

    final channels = ids.isEmpty ? <Channel>[] : await getChannelDetails(ids);
    _write(cacheKey, channels);
    return channels;
  }

  /// Fetches channel details (name, handle, subscribers, artwork) for [ids].
  Future<List<Channel>> getChannelDetails(List<String> ids) async {
    final unique = (ids.toSet().toList()..sort());
    if (unique.isEmpty) {
      return const <Channel>[];
    }
    final cacheKey = 'details:${unique.join(',')}';
    final cached = _read<List<Channel>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final json = await _getJson('channels', <String, String>{
      'part': 'snippet,statistics',
      'id': unique.join(','),
    });
    final channels = <Channel>[
      for (final item in json['items'] as List<dynamic>? ?? const <dynamic>[])
        _channelFromJson(item as Map<String, dynamic>),
    ];
    _write(cacheKey, channels);
    return channels;
  }

  /// Fetches the most recent uploads for every channel in [channelIds],
  /// merged and sorted newest-first. Uses one batched `videos.list` call for
  /// duration and view counts instead of a per-video round trip.
  Future<List<Video>> getRecentVideos(List<String> channelIds,
      {int maxResults = _maxResults}) async {
    final unique = (channelIds.toSet().toList()..sort());
    if (unique.isEmpty) {
      return const <Video>[];
    }
    final cacheKey = 'feed:${unique.join(',')}';
    final cached = _read<List<Video>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    final uploadIds = <String>{};
    for (final channelId in unique) {
      final search = await _getJson('search', <String, String>{
        'part': 'snippet',
        'type': 'video',
        'channelId': channelId,
        'order': 'date',
        'maxResults': '$maxResults',
      });
      for (final item in search['items'] as List<dynamic>? ?? const <dynamic>[]) {
        final videoId = (item as Map<String, dynamic>)['id']?['videoId'];
        if (videoId is String) {
          uploadIds.add(videoId);
        }
      }
    }

    final videos = uploadIds.isEmpty
        ? <Video>[]
        : await _videosById(uploadIds.toList());
    _write(cacheKey, videos);
    return videos;
  }

  Future<List<Video>> _videosById(List<String> ids) async {
    final json = await _getJson('videos', <String, String>{
      'part': 'snippet,contentDetails,statistics',
      'id': ids.join(','),
    });
    final videos = <Video>[
      for (final item in json['items'] as List<dynamic>? ?? const <dynamic>[])
        _videoFromJson(item as Map<String, dynamic>),
    ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return videos;
  }

  Future<Map<String, dynamic>> _getJson(
    String resource,
    Map<String, String> params,
  ) async {
    if (!hasApiKey) {
      throw const YoutubeApiException(
        'No YouTube API key configured. See the README for setup.',
      );
    }
    final uri = Uri.https(
      _baseHost,
      '$_basePath/$resource',
      <String, String>{...params, 'key': _apiKey},
    );
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw YoutubeApiException(
          'YouTube API returned HTTP ${response.statusCode}.',
        );
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on YoutubeApiException {
      rethrow;
    } on TimeoutException {
      throw const YoutubeApiException('The request timed out.');
    } catch (error) {
      throw YoutubeApiException('Network error: $error');
    }
  }

  Channel _channelFromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>? ?? const {};
    final statistics = json['statistics'] as Map<String, dynamic>? ?? const {};
    final id = (json['id'] as String?) ?? '';
    final name = (snippet['title'] as String?) ?? 'Unknown channel';
    var handle = (snippet['customUrl'] as String?) ?? '';
    if (handle.isNotEmpty && !handle.startsWith('@')) {
      handle = '@$handle';
    }
    final subscribers =
        int.tryParse('${statistics['subscriberCount'] ?? ''}') ?? 0;
    return Channel(
      id: id,
      name: name,
      handle: handle.isEmpty ? null : handle,
      subscriberCount: subscribers,
      description: (snippet['description'] as String?) ?? '',
      brandColor: channelBrandColorFor(id),
      thumbnailUrl: _thumbnailUrl(snippet),
    );
  }

  Video _videoFromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] as Map<String, dynamic>? ?? const {};
    final content = json['contentDetails'] as Map<String, dynamic>? ?? const {};
    final statistics = json['statistics'] as Map<String, dynamic>? ?? const {};
    return Video(
      id: (json['id'] as String?) ?? '',
      channelId: (snippet['channelId'] as String?) ?? '',
      title: (snippet['title'] as String?) ?? 'Untitled video',
      duration:
          parseIso8601Duration((content['duration'] as String?) ?? 'PT0S'),
      publishedAt: DateTime.tryParse((snippet['publishedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      views: int.tryParse('${statistics['viewCount'] ?? ''}') ?? 0,
      thumbnailUrl: _thumbnailUrl(snippet),
    );
  }

  String? _thumbnailUrl(Map<String, dynamic> snippet) {
    final thumbnails = snippet['thumbnails'] as Map<String, dynamic>? ?? const {};
    final medium = thumbnails['medium'] as Map<String, dynamic>?;
    final small = thumbnails['default'] as Map<String, dynamic>?;
    return (medium?['url'] as String?) ?? (small?['url'] as String?);
  }

  T? _read<T>(String key) {
    final entry = _cache[key];
    if (entry == null) {
      return null;
    }
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void _write<T>(String key, T value) {
    _cache[key] = _CacheEntry(value, DateTime.now().add(_cacheTtl));
  }
}

class _CacheEntry {
  const _CacheEntry(this.value, this.expiresAt);

  final Object? value;
  final DateTime expiresAt;
}

const List<Color> _palette = <Color>[
  Color(0xFF6C5CE7),
  Color(0xFF0984E3),
  Color(0xFF00B894),
  Color(0xFFE17055),
  Color(0xFFD63031),
  Color(0xFFE84393),
  Color(0xFF00CEC9),
  Color(0xFF2D3436),
];

/// Deterministic brand color derived from a channel id, used for generated
/// avatars until real channel artwork is loaded. Stable across sessions.
Color channelBrandColorFor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _palette[hash % _palette.length];
}
