import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:channelfeed/models/channel.dart';
import 'package:channelfeed/screens/youtube_webview_screen.dart';

void main() {
  group('YoutubeWebViewScreen.normalizeUrl', () {
    test('keeps a valid https watch URL unchanged', () {
      final uri = YoutubeWebViewScreen.normalizeUrl(
        'https://www.youtube.com/watch?v=abc123',
      );
      expect(uri, isNotNull);
      expect(uri.toString(), 'https://www.youtube.com/watch?v=abc123');
    });

    test('upgrades http YouTube pages to https', () {
      final uri = YoutubeWebViewScreen.normalizeUrl(
        'http://youtube.com/watch?v=abc123',
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.toString(), 'https://youtube.com/watch?v=abc123');
    });

    test('accepts non-YouTube https URLs', () {
      final uri = YoutubeWebViewScreen.normalizeUrl(
        'https://en.wikipedia.org/wiki/YouTube',
      );
      expect(uri, isNotNull);
    });

    test('rejects non-http schemes', () {
      expect(
        YoutubeWebViewScreen.normalizeUrl('javascript:alert(1)'),
        isNull,
      );
      expect(YoutubeWebViewScreen.normalizeUrl('file:///etc/passwd'), isNull);
    });

    test('rejects URLs without a host', () {
      expect(YoutubeWebViewScreen.normalizeUrl('https:///no-host'), isNull);
    });

    test('rejects empty and garbage input', () {
      expect(YoutubeWebViewScreen.normalizeUrl(''), isNull);
      expect(YoutubeWebViewScreen.normalizeUrl('not a url'), isNull);
    });
  });

  group('Channel.youtubeUrl', () {
    const base = Channel(
      id: 'UC123',
      name: 'Aurora Labs',
      subscriberCount: 1000,
      description: 'desc',
      brandColor: Colors.red,
    );

    test('uses the handle when present', () {
      const withHandle = Channel(
        id: 'UC123',
        name: 'Aurora Labs',
        handle: '@auroralabs',
        subscriberCount: 1000,
        description: 'desc',
        brandColor: Colors.red,
      );
      expect(withHandle.youtubeUrl, 'https://www.youtube.com/@auroralabs');
    });

    test('prefixes @ to handles that lack it', () {
      const bare = Channel(
        id: 'UC123',
        name: 'Aurora Labs',
        handle: 'auroralabs',
        subscriberCount: 1000,
        description: 'desc',
        brandColor: Colors.red,
      );
      expect(bare.youtubeUrl, 'https://www.youtube.com/@auroralabs');
    });

    test('falls back to the channel id when there is no handle', () {
      expect(base.youtubeUrl, 'https://www.youtube.com/channel/UC123');
    });
  });
}
