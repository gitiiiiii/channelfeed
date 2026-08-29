import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:channelfeed/main.dart';
import 'package:channelfeed/models/channel.dart';
import 'package:channelfeed/models/video.dart';
import 'package:channelfeed/screens/channels_screen.dart';
import 'package:channelfeed/services/channel_service.dart';
import 'package:channelfeed/services/content_repository.dart';
import 'package:channelfeed/services/feed_service.dart';
import 'package:channelfeed/services/youtube_api_service.dart';
import 'package:channelfeed/utils/formats.dart';

/// In-memory repository used to exercise live-mode behavior without network.
class FakeContentRepository implements ContentRepository {
  FakeContentRepository({this.live = true});

  bool live;
  final List<String> searchCalls = <String>[];
  final List<Set<String>> feedCalls = <Set<String>>[];
  List<Channel> searchResults = <Channel>[];
  List<Channel> detailsResults = <Channel>[];
  List<Video> feedResults = <Video>[];
  bool throwOnFeed = false;

  @override
  bool get isLive => live;

  @override
  Future<List<Channel>> searchChannels(String query) async {
    searchCalls.add(query);
    return searchResults;
  }

  @override
  Future<List<Channel>> fetchChannelDetails(List<String> ids) async {
    return detailsResults
        .where((channel) => ids.contains(channel.id))
        .toList();
  }

  @override
  Future<List<Video>> fetchRecentVideos(Set<String> channelIds,
      {bool forceRefresh = false}) async {
    feedCalls.add(channelIds);
    if (throwOnFeed) {
      throw const YoutubeApiException('boom');
    }
    return feedResults;
  }
}

http.Response _jsonResponse(Object body) =>
    http.Response(jsonEncode(body), 200,
        headers: <String, String>{'content-type': 'application/json'});

void main() {
  group('parseIso8601Duration', () {
    test('parses hours, minutes and seconds', () {
      expect(parseIso8601Duration('PT1H2M3S'),
          const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(parseIso8601Duration('PT12M34S'),
          const Duration(minutes: 12, seconds: 34));
      expect(parseIso8601Duration('PT45S'), const Duration(seconds: 45));
      expect(parseIso8601Duration('PT0S'), Duration.zero);
    });

    test('returns zero for malformed input', () {
      expect(parseIso8601Duration(''), Duration.zero);
      expect(parseIso8601Duration('P1DT1H'), Duration.zero);
      expect(parseIso8601Duration('nonsense'), Duration.zero);
    });
  });

  group('YoutubeApiService', () {
    test('rejects requests without an API key', () async {
      final service = YoutubeApiService(
        client: MockClient((request) async => _jsonResponse(<String, Object>{})),
        apiKey: '',
      );
      expect(service.hasApiKey, isFalse);
      expect(
        () => service.searchChannels('flutter'),
        throwsA(isA<YoutubeApiException>()),
      );
    });

    test('searchChannels parses and enriches results', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        final path = request.url.path;
        if (path == '/youtube/v3/search') {
          return _jsonResponse(<String, Object>{
            'items': <Object>[
              <String, Object>{
                'id': <String, String>{'channelId': 'UC-abc'},
                'snippet': <String, Object>{
                  'title': 'Flutter Devs',
                  'description': 'Tutorials',
                  'thumbnails': <String, Object>{
                    'default': <String, String>{'url': 'http://x/def.jpg'},
                  },
                },
              },
            ],
          });
        }
        if (path == '/youtube/v3/channels') {
          return _jsonResponse(<String, Object>{
            'items': <Object>[
              <String, Object>{
                'id': 'UC-abc',
                'snippet': <String, Object>{
                  'title': 'Flutter Devs',
                  'customUrl': 'flutterdevs',
                  'description': 'Tutorials',
                  'thumbnails': <String, Object>{
                    'medium': <String, String>{'url': 'http://x/med.jpg'},
                  },
                },
                'statistics': <String, String>{'subscriberCount': '120000'},
              },
            ],
          });
        }
        fail('Unexpected path $path');
      });

      final service = YoutubeApiService(client: client, apiKey: 'test-key');
      final channels = await service.searchChannels('flutter');

      expect(requestCount, 2);
      expect(channels, hasLength(1));
      expect(channels.first.id, 'UC-abc');
      expect(channels.first.name, 'Flutter Devs');
      expect(channels.first.handle, '@flutterdevs');
      expect(channels.first.subscriberCount, 120000);
      expect(channels.first.thumbnailUrl, 'http://x/med.jpg');
    });

    test('caches identical search queries', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return _jsonResponse(<String, Object>{'items': <Object>[]});
      });

      final service = YoutubeApiService(client: client, apiKey: 'test-key');
      await service.searchChannels('flutter');
      await service.searchChannels('flutter');
      expect(requestCount, 1);
    });

    test('getRecentVideos parses duration, views and sorts', () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/youtube/v3/search') {
          return _jsonResponse(<String, Object>{
            'items': <Object>[
              <String, Object>{
                'id': <String, String>{'videoId': 'v-1'},
                'snippet': <String, Object>{
                  'channelId': 'UC-abc',
                  'title': 'First upload',
                },
              },
              <String, Object>{
                'id': <String, String>{'videoId': 'v-2'},
                'snippet': <String, Object>{
                  'channelId': 'UC-abc',
                  'title': 'Second upload',
                },
              },
            ],
          });
        }
        if (path == '/youtube/v3/videos') {
          return _jsonResponse(<String, Object>{
            'items': <Object>[
              <String, Object>{
                'id': 'v-1',
                'snippet': <String, Object>{
                  'channelId': 'UC-abc',
                  'title': 'First upload',
                  'publishedAt': '2026-08-20T10:00:00Z',
                  'thumbnails': <String, Object>{
                    'medium': <String, String>{'url': 'http://x/v1.jpg'},
                  },
                },
                'contentDetails': <String, String>{'duration': 'PT12M34S'},
                'statistics': <String, String>{'viewCount': '99999'},
              },
              <String, Object>{
                'id': 'v-2',
                'snippet': <String, Object>{
                  'channelId': 'UC-abc',
                  'title': 'Second upload',
                  'publishedAt': '2026-08-25T10:00:00Z',
                },
                'contentDetails': <String, String>{'duration': 'PT5S'},
                'statistics': <String, String>{'viewCount': '1'},
              },
            ],
          });
        }
        fail('Unexpected path $path');
      });

      final service = YoutubeApiService(client: client, apiKey: 'test-key');
      final videos = await service.getRecentVideos(<String>['UC-abc']);

      expect(videos.map((v) => v.id), <String>['v-2', 'v-1']);
      expect(videos.first.duration, const Duration(seconds: 5));
      expect(videos.last.duration, const Duration(minutes: 12, seconds: 34));
      expect(videos.last.views, 99999);
      expect(videos.last.thumbnailUrl, 'http://x/v1.jpg');
    });

    test('surfaces HTTP errors as YoutubeApiException', () async {
      final client = MockClient(
        (request) async => http.Response('Forbidden', 403),
      );
      final service = YoutubeApiService(client: client, apiKey: 'test-key');
      expect(
        () => service.searchChannels('flutter'),
        throwsA(isA<YoutubeApiException>()),
      );
    });

    test('reuses per-channel searches when the selection grows', () async {
      final searchCalls = <String>[];
      var videosCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/youtube/v3/search') {
          final channelId = request.url.queryParameters['channelId']!;
          searchCalls.add(channelId);
          return _jsonResponse(<String, Object>{
            'items': <Object>[
              <String, Object>{
                'id': <String, String>{'videoId': '$channelId-1'},
                'snippet': <String, Object>{
                  'channelId': channelId,
                },
              },
            ],
          });
        }
        if (path == '/youtube/v3/videos') {
          videosCalls++;
          return _jsonResponse(<String, Object>{'items': <Object>[]});
        }
        fail('Unexpected path $path');
      });

      final service = YoutubeApiService(client: client, apiKey: 'test-key');
      await service.getRecentVideos(<String>['a']);
      await service.getRecentVideos(<String>['a', 'b']);

      expect(searchCalls, <String>['a', 'b']);
      expect(videosCalls, 2);
    });

    test('forceRefresh bypasses the cached feed', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final path = request.url.path;
        if (path == '/youtube/v3/search') {
          return _jsonResponse(<String, Object>{'items': <Object>[]});
        }
        if (path == '/youtube/v3/videos') {
          return _jsonResponse(<String, Object>{'items': <Object>[]});
        }
        fail('Unexpected path $path');
      });

      final service = YoutubeApiService(client: client, apiKey: 'test-key');
      await service.getRecentVideos(<String>['a']);
      final cachedCount = calls;
      await service.getRecentVideos(<String>['a']);
      expect(calls, cachedCount);

      await service.getRecentVideos(<String>['a'], forceRefresh: true);
      expect(calls, greaterThan(cachedCount));
    });
  });

  group('FeedService live mode', () {
    test('refresh() populates the feed and resolve() uses it', () async {
      final channels = <Channel>[
        Channel(
          id: 'c1',
          name: 'C1',
          brandColor: const Color(0xFF6C5CE7),
          subscriberCount: 1,
          description: '',
        ),
      ];
      final service = ChannelService(
        channels: channels,
        initiallySelected: const <String>{'c1'},
      );
      final repo = FakeContentRepository()
        ..feedResults = <Video>[
          Video(
            id: 'v1',
            channelId: 'c1',
            title: 'Live video',
            duration: const Duration(minutes: 3),
            publishedAt: DateTime(2026, 8, 25),
            views: 10,
          ),
        ];
      final feed = FeedService(
        channelService: service,
        videos: const <Video>[],
        repository: repo,
      );

      await feed.refresh();
      expect(feed.isLive, isTrue);
      expect(feed.isLoading, isFalse);
      expect(feed.hasData, isTrue);
      expect(feed.resolve(FeedFilter.all).map((v) => v.id), <String>['v1']);
    });

    test('selection changes trigger a refresh for the new ids', () async {
      final service = ChannelService(channels: <Channel>[
        Channel(
          id: 'c1',
          name: 'C1',
          brandColor: const Color(0xFF6C5CE7),
          subscriberCount: 1,
          description: '',
        ),
        Channel(
          id: 'c2',
          name: 'C2',
          brandColor: const Color(0xFF0984E3),
          subscriberCount: 1,
          description: '',
        ),
      ]);
      final repo = FakeContentRepository();
      final feed = FeedService(
        channelService: service,
        videos: const <Video>[],
        repository: repo,
      );

      service.setSelected(const <String>{'c2'});
      await feed.refresh();
      expect(repo.feedCalls, isNotEmpty);
      expect(repo.feedCalls.last, <String>{'c2'});
    });

    test('refresh() error is exposed without losing previous data', () async {
      final service = ChannelService(channels: <Channel>[
        Channel(
          id: 'c1',
          name: 'C1',
          brandColor: const Color(0xFF6C5CE7),
          subscriberCount: 1,
          description: '',
        ),
      ], initiallySelected: const <String>{'c1'});
      final repo = FakeContentRepository()
        ..feedResults = <Video>[
          Video(
            id: 'v1',
            channelId: 'c1',
            title: 'Live video',
            duration: const Duration(minutes: 3),
            publishedAt: DateTime(2026, 8, 25),
            views: 10,
          ),
        ];
      final feed = FeedService(
        channelService: service,
        videos: const <Video>[],
        repository: repo,
      );
      await feed.refresh();
      expect(feed.errorMessage, isNull);

      repo.throwOnFeed = true;
      await feed.refresh();
      expect(feed.errorMessage, isNotNull);
      expect(feed.hasData, isTrue);
    });

    test('unchanged selection does not trigger another fetch', () async {
      final service = ChannelService(channels: <Channel>[
        Channel(
          id: 'c1',
          name: 'C1',
          brandColor: const Color(0xFF6C5CE7),
          subscriberCount: 1,
          description: '',
        ),
      ], initiallySelected: const <String>{'c1'});
      final repo = FakeContentRepository();
      final feed = FeedService(
        channelService: service,
        videos: const <Video>[],
        repository: repo,
      );
      await feed.refresh();
      final callCount = repo.feedCalls.length;

      service.upsertChannels(<Channel>[
        Channel(
          id: 'c1',
          name: 'C1 renamed',
          brandColor: const Color(0xFF6C5CE7),
          subscriberCount: 2,
          description: 'Updated.',
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(repo.feedCalls.length, callCount);
    });

    test('explicit refresh always refetches, even for the same selection',
        () async {
      final service = ChannelService(channels: <Channel>[
        Channel(
          id: 'c1',
          name: 'C1',
          brandColor: const Color(0xFF6C5CE7),
          subscriberCount: 1,
          description: '',
        ),
      ], initiallySelected: const <String>{'c1'});
      final repo = FakeContentRepository();
      final feed = FeedService(
        channelService: service,
        videos: const <Video>[],
        repository: repo,
      );
      await feed.refresh();
      final callCount = repo.feedCalls.length;

      await feed.refresh();
      expect(repo.feedCalls.length, callCount + 1);
    });
  });

  group('ChannelsScreen live search', () {
    testWidgets('searches the API and lets the user follow a result',
        (tester) async {
      final service = ChannelService(
        channels: const <Channel>[],
        initiallySelected: const <String>{},
      );
      final repo = FakeContentRepository()
        ..searchResults = <Channel>[
          const Channel(
            id: 'UC-real',
            name: 'Real Channel',
            handle: '@realchannel',
            subscriberCount: 5000,
            description: 'From the API.',
            brandColor: Color(0xFF6C5CE7),
          ),
        ];

      await tester.pumpWidget(
        MaterialApp(
          home: ChannelsScreen(
            channelService: service,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'real');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.searchCalls, <String>['real']);
      expect(find.text('Real Channel'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Follow'));
      await tester.pumpAndSettle();

      expect(service.isSelected('UC-real'), isTrue);
      expect(service.channelById('UC-real'), isNotNull);
      expect(find.text('1 following'), findsOneWidget);
    });

    testWidgets('offline mode keeps local directory search', (tester) async {
      final service = ChannelService(
        channels: const <Channel>[
          Channel(
            id: 'a',
            name: 'Alpha Channel',
            handle: '@alpha',
            subscriberCount: 100,
            description: 'Local.',
            brandColor: Color(0xFF6C5CE7),
          ),
        ],
        initiallySelected: const <String>{},
      );
      final repo = FakeContentRepository(live: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChannelsScreen(channelService: service, repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha Channel'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pumpAndSettle();
      expect(repo.searchCalls, isEmpty);
      expect(find.text('Alpha Channel'), findsOneWidget);
    });
  });

  group('ChannelFeed app live mode', () {
    testWidgets('hydrates followed channels and shows the live feed',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final repo = FakeContentRepository()
        ..detailsResults = <Channel>[
          const Channel(
            id: 'UC-live',
            name: 'Live Channel',
            handle: '@livechannel',
            subscriberCount: 9000,
            description: 'From the API.',
            brandColor: Color(0xFF0984E3),
          ),
        ]
        ..feedResults = <Video>[
          Video(
            id: 'v-live',
            channelId: 'UC-live',
            title: 'A live upload',
            duration: const Duration(minutes: 6),
            publishedAt: DateTime(2026, 8, 26),
            views: 42,
            thumbnailUrl: 'http://x/thumb.jpg',
          ),
        ];

      await tester.pumpWidget(ChannelFeedApp(
        repository: repo,
        initialSelected: const <String>{'UC-live'},
      ));
      await tester.pumpAndSettle();

      expect(repo.feedCalls, isNotEmpty);
      expect(repo.feedCalls.last, contains('UC-live'));
      expect(find.text('A live upload'), findsOneWidget);
    });
  });
}
