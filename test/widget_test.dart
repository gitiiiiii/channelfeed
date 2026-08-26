import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:channelfeed/main.dart';
import 'package:channelfeed/models/channel.dart';
import 'package:channelfeed/models/preferences.dart';
import 'package:channelfeed/models/video.dart';
import 'package:channelfeed/screens/channels_screen.dart';
import 'package:channelfeed/screens/home_screen.dart';
import 'package:channelfeed/screens/profile_screen.dart';
import 'package:channelfeed/services/channel_service.dart';
import 'package:channelfeed/services/feed_service.dart';
import 'package:channelfeed/services/local_store.dart';
import 'package:channelfeed/services/settings_service.dart';
import 'package:channelfeed/utils/formats.dart';
import 'package:channelfeed/widgets/video_card.dart';

const List<Channel> _testChannels = <Channel>[
  Channel(
    id: 'a',
    name: 'Alpha Channel',
    handle: '@alpha',
    subscriberCount: 1200000,
    description: 'Alpha videos.',
    brandColor: Color(0xFF6C5CE7),
  ),
  Channel(
    id: 'b',
    name: 'Beta Channel',
    handle: '@beta',
    subscriberCount: 80000,
    description: 'Beta videos.',
    brandColor: Color(0xFF0984E3),
  ),
];

List<Video> _testVideos(DateTime now) => <Video>[
      Video(
        id: 'a-1',
        channelId: 'a',
        title: 'Alpha first video',
        duration: const Duration(minutes: 5),
        publishedAt: now.subtract(const Duration(days: 1)),
        views: 1000,
      ),
      Video(
        id: 'b-1',
        channelId: 'b',
        title: 'Beta first video',
        duration: const Duration(minutes: 8),
        publishedAt: now.subtract(const Duration(days: 3)),
        views: 500,
      ),
    ];

Finder _navDestination(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

/// Pumps [app] on a phone-sized surface and settles all animations.
Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  group('formats', () {
    test('formatCompactNumber', () {
      expect(formatCompactNumber(0), '0');
      expect(formatCompactNumber(999), '999');
      expect(formatCompactNumber(1200), '1.2K');
      expect(formatCompactNumber(3400000), '3.4M');
      expect(formatCompactNumber(5100000000), '5.1B');
    });

    test('formatDuration', () {
      expect(formatDuration(const Duration(minutes: 12, seconds: 34)), '12:34');
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });

    test('formatRelativeTime', () {
      final now = DateTime(2026, 8, 26, 12, 0);
      expect(formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(formatRelativeTime(now.subtract(const Duration(days: 10)), now: now), '1w ago');
    });
  });

  group('services', () {
    test('ChannelService toggles selection and notifies', () {
      final service = ChannelService(channels: _testChannels);
      var notified = 0;
      service.addListener(() => notified++);

      expect(service.isSelected('a'), isFalse);
      service.toggleSelection('a');
      expect(service.isSelected('a'), isTrue);
      expect(service.selectedCount, 1);
      expect(notified, 1);

      service.toggleSelection('a');
      expect(service.isSelected('a'), isFalse);
      expect(notified, 2);
    });

    test('ChannelService search matches name and handle', () {
      final service = ChannelService(channels: _testChannels);
      expect(service.search('alpha').map((c) => c.id), <String>['a']);
      expect(service.search('@beta').map((c) => c.id), <String>['b']);
      expect(service.search('').length, 2);
      expect(service.search('nope'), isEmpty);
    });

    test('FeedService filters by followed channels', () {
      final service = ChannelService(channels: _testChannels);
      final feed = FeedService(channelService: service, videos: _testVideos(DateTime.now()));

      expect(feed.allVideos.length, 2);
      expect(feed.followedVideos, isEmpty);

      service.toggleSelection('a');
      expect(feed.followedVideos.map((v) => v.id), <String>['a-1']);

      feed.filter = FeedFilter.channels;
      expect(feed.resolve(FeedFilter.channels).map((v) => v.id), <String>['a-1']);
    });

    test('SettingsService persists preferences', () {
      final settings = SettingsService();
      expect(settings.autoplay, isTrue);
      settings.setAutoplay(false);
      settings.setThemeMode(ThemeMode.dark);
      expect(settings.autoplay, isFalse);
      expect(settings.themeMode, ThemeMode.dark);
    });

    test('SettingsService reports changes to onChanged', () async {
      Preferences? reported;
      final settings = SettingsService(
        onChanged: (value) async => reported = value,
      );

      settings.setAutoplay(false);
      expect(reported?.autoplay, isFalse);

      settings.setThemeMode(ThemeMode.light);
      expect(reported?.themeMode, ThemeMode.light);
    });

    test('ChannelService reports selection to onSelectionChanged', () async {
      Set<String>? reported;
      final service = ChannelService(
        channels: _testChannels,
        onSelectionChanged: (ids) async => reported = ids,
      );

      service.toggleSelection('a');
      expect(reported, <String>{'a'});

      service.toggleSelection('b');
      expect(reported, <String>{'a', 'b'});

      service.toggleSelection('a');
      expect(reported, <String>{'b'});
    });
  });

  group('LocalStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('loads defaults when nothing is stored', () async {
      final preferences = await LocalStore.loadPreferences();
      expect(preferences.themeMode, ThemeMode.system);
      expect(preferences.autoplay, isTrue);
      expect(preferences.showViewCounts, isTrue);

      final followed = await LocalStore.loadFollowedIds();
      expect(followed, isNull);
    });

    test('round-trips preferences', () async {
      await LocalStore.savePreferences(const Preferences(
        themeMode: ThemeMode.dark,
        autoplay: false,
        showViewCounts: false,
      ));

      final loaded = await LocalStore.loadPreferences();
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.autoplay, isFalse);
      expect(loaded.showViewCounts, isFalse);
    });

    test('round-trips followed channel ids', () async {
      await LocalStore.saveFollowedIds(<String>{'b', 'a', 'c'});

      final loaded = await LocalStore.loadFollowedIds();
      expect(loaded, <String>{'a', 'b', 'c'});
    });
  });

  group('ChannelFeed app', () {
    testWidgets('boots to Home with the feed and three tabs', (tester) async {
      await _pumpApp(tester, const ChannelFeedApp());

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(_navDestination('Home'), findsOneWidget);
      expect(_navDestination('Channels'), findsOneWidget);
      expect(_navDestination('Profile'), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(VideoCard), findsWidgets);
    });

    testWidgets('tab navigation switches between screens', (tester) async {
      await _pumpApp(tester, const ChannelFeedApp());

      await tester.tap(_navDestination('Channels'));
      await tester.pumpAndSettle();
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 1);
      expect(find.byType(ChannelsScreen), findsOneWidget);
      expect(find.text('Search channels'), findsOneWidget);

      await tester.tap(_navDestination('Profile'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Alex Chen'), findsOneWidget);
    });

    testWidgets('following a channel updates the feed and profile', (tester) async {
      await _pumpApp(tester, const ChannelFeedApp());

      await tester.tap(_navDestination('Channels'));
      await tester.pumpAndSettle();
      expect(find.text('2 following'), findsOneWidget);

      final followButtons = find.widgetWithText(OutlinedButton, 'Follow');
      await tester.tap(followButtons.first);
      await tester.pumpAndSettle();
      expect(find.text('3 following'), findsOneWidget);
    });

    testWidgets('Channels feed filter only shows followed channels', (tester) async {
      final now = DateTime.now();
      await _pumpApp(
        tester,
        ChannelFeedApp(
          channels: _testChannels,
          videos: _testVideos(now),
          initialSelected: const <String>{'a'},
        ),
      );

      expect(find.text('Alpha first video'), findsOneWidget);
      expect(find.text('Beta first video'), findsOneWidget);

      final channelsSegment = find.descendant(
        of: find.byType(SegmentedButton<FeedFilter>),
        matching: find.text('Channels'),
      );
      await tester.tap(channelsSegment);
      await tester.pumpAndSettle();

      expect(find.text('Alpha first video'), findsOneWidget);
      expect(find.text('Beta first video'), findsNothing);
    });

    testWidgets('profile settings toggle view counts on cards', (tester) async {
      await _pumpApp(tester, const ChannelFeedApp());

      await tester.tap(_navDestination('Profile'));
      await tester.pumpAndSettle();

      final autoplaySwitch = find.byType(SwitchListTile);
      expect(autoplaySwitch, findsWidgets);

      await tester.tap(find.text('Show view counts'));
      await tester.pumpAndSettle();

      await tester.tap(_navDestination('Home'));
      await tester.pumpAndSettle();

      final alphaTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>();
      expect(alphaTexts.any((t) => t.contains('views')), isFalse);
    });

    testWidgets('follow selection and settings persist to storage',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await _pumpApp(
        tester,
        ChannelFeedApp(
          persistPreferences: LocalStore.savePreferences,
          persistSelection: LocalStore.saveFollowedIds,
        ),
      );

      await tester.tap(_navDestination('Channels'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Follow').first);
      await tester.pumpAndSettle();

      await tester.tap(_navDestination('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show view counts'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      final storedIds = prefs.getStringList(LocalStore.followedChannelIdsKey);
      expect(storedIds, isNotNull);
      expect(storedIds!.length, 3);
      expect(storedIds, containsAll(<String>['aurora', 'codeforge']));
      expect(prefs.getBool(LocalStore.showViewCountsKey), isFalse);
    });
  });
}
