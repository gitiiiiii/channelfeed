import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:channelfeed/models/channel.dart';
import 'package:channelfeed/services/auth_service.dart';
import 'package:channelfeed/services/channel_service.dart';
import 'package:channelfeed/services/cloud_selection_store.dart';
import 'package:channelfeed/services/selection_sync.dart';

const List<Channel> _channels = <Channel>[
  Channel(
    id: 'a',
    name: 'Alpha Channel',
    subscriberCount: 1200000,
    description: 'Alpha videos.',
    brandColor: Color(0xFF6C5CE7),
  ),
  Channel(
    id: 'b',
    name: 'Beta Channel',
    subscriberCount: 80000,
    description: 'Beta videos.',
    brandColor: Color(0xFF0984E3),
  ),
  Channel(
    id: 'c',
    name: 'Gamma Channel',
    subscriberCount: 5000,
    description: 'Gamma videos.',
    brandColor: Color(0xFF00B894),
  ),
];

class FakeAuthService extends AuthService {
  FakeAuthService(this.signedInValue);

  bool signedInValue;

  @override
  bool get isSignedIn => signedInValue;

  void setSignedIn(bool value) {
    signedInValue = value;
    notifyListeners();
  }
}

class FakeCloudStore extends CloudSelectionStore {
  FakeCloudStore(this.stored)
      : super(accessTokenProvider: () async => 'test-token');

  Set<String>? stored;
  int pushCount = 0;

  @override
  Future<Set<String>?> fetch({http.Client? client}) async => stored;

  @override
  Future<bool> push(Set<String> ids, {http.Client? client}) async {
    stored = Set<String>.of(ids);
    pushCount++;
    return true;
  }
}

class ThrowingCloudStore extends CloudSelectionStore {
  ThrowingCloudStore()
      : super(accessTokenProvider: () async => 'test-token');

  @override
  Future<Set<String>?> fetch({http.Client? client}) async =>
      throw Exception('offline');

  @override
  Future<bool> push(Set<String> ids, {http.Client? client}) async =>
      throw Exception('offline');
}

void main() {
  group('CloudSelectionStore', () {
    test('fetch returns stored ids', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/drive/v3/files' &&
            request.url.queryParameters['spaces'] == 'appDataFolder') {
          return http.Response(
            '{"files":[{"id":"file123"}]}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/drive/v3/files/file123') {
          return http.Response(
            '{"ids":["aurora","codeforge"]}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });
      final store =
          CloudSelectionStore(accessTokenProvider: () async => 'token');

      final ids = await store.fetch(client: client);

      expect(ids, <String>{'aurora', 'codeforge'});
    });

    test('fetch returns null when signed out or offline', () async {
      final store =
          CloudSelectionStore(accessTokenProvider: () async => null);
      expect(await store.fetch(), isNull);
    });

    test('push creates the file when missing and uploads ids', () async {
      var created = false;
      final client = MockClient((request) async {
        if (request.url.path == '/drive/v3/files' &&
            request.method == 'GET') {
          return http.Response('{"files":[]}', 200);
        }
        if (request.url.path == '/drive/v3/files' &&
            request.method == 'POST') {
          created = true;
          return http.Response('{"id":"file123"}', 200);
        }
        if (request.url.path == '/upload/drive/v3/files/file123') {
          expect(request.body, '{"ids":["aurora","codeforge"]}');
          return http.Response('', 200);
        }
        return http.Response('{"error":"not found"}', 404);
      });
      final store =
          CloudSelectionStore(accessTokenProvider: () async => 'token');

      final ok =
          await store.push(<String>{'aurora', 'codeforge'}, client: client);

      expect(ok, isTrue);
      expect(created, isTrue);
    });
  });

  group('SelectionSync', () {
    test('sign-in merges cloud and local selections without losing data',
        () async {
      final auth = FakeAuthService(false);
      final channels = ChannelService(
        channels: _channels,
        initiallySelected: const <String>{'a'},
      );
      final store = FakeCloudStore(<String>{'b', 'c'});
      final sync = SelectionSync(
        authService: auth,
        channelService: channels,
        store: store,
        pushDebounce: Duration.zero,
      )..start();

      expect(store.pushCount, 0);

      auth.setSignedIn(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(channels.isSelected('a'), isTrue);
      expect(channels.isSelected('b'), isTrue);
      expect(channels.isSelected('c'), isTrue);
      expect(store.stored, <String>{'a', 'b', 'c'});
      sync.dispose();
    });

    test('selection changes are pushed to the cloud while signed in',
        () async {
      final auth = FakeAuthService(true);
      final channels = ChannelService(
        channels: _channels,
        initiallySelected: const <String>{'a'},
      );
      final store = FakeCloudStore(null);
      final sync = SelectionSync(
        authService: auth,
        channelService: channels,
        store: store,
        pushDebounce: Duration.zero,
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      channels.toggleSelection('b');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(store.stored, <String>{'a', 'b'});
      sync.dispose();
    });

    test('channel removals are pushed to the cloud while signed in', () async {
      final auth = FakeAuthService(true);
      final channels = ChannelService(
        channels: _channels,
        initiallySelected: const <String>{'a', 'b'},
      );
      final store = FakeCloudStore(<String>{'a', 'b'});
      final sync = SelectionSync(
        authService: auth,
        channelService: channels,
        store: store,
        pushDebounce: Duration.zero,
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      channels.toggleSelection('b');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(store.stored, <String>{'a'});
      sync.dispose();
    });

    test('offline cloud failures do not break local functionality', () async {
      final auth = FakeAuthService(true);
      final channels = ChannelService(
        channels: _channels,
        initiallySelected: const <String>{'a'},
      );
      final sync = SelectionSync(
        authService: auth,
        channelService: channels,
        store: ThrowingCloudStore(),
        pushDebounce: Duration.zero,
      )..start();

      await sync.syncNow();
      channels.toggleSelection('b');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(channels.isSelected('a'), isTrue);
      expect(channels.isSelected('b'), isTrue);
      sync.dispose();
    });
  });
}
