import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../models/video.dart';

/// Realistic sample channels used until the YouTube API is integrated.
const List<Channel> mockChannels = <Channel>[
  Channel(
    id: 'aurora',
    name: 'Aurora Labs',
    handle: '@auroralabs',
    subscriberCount: 2400000,
    description: 'Science, space, and the future of everything.',
    brandColor: Color(0xFF6C5CE7),
  ),
  Channel(
    id: 'codeforge',
    name: 'CodeForge',
    handle: '@codeforge',
    subscriberCount: 1100000,
    description: 'Practical programming tutorials and tooling deep dives.',
    brandColor: Color(0xFF0984E3),
  ),
  Channel(
    id: 'citywalks',
    name: 'City Walks',
    handle: '@citywalks',
    subscriberCount: 890000,
    description: 'Ambient walks through the world\u2019s most interesting cities.',
    brandColor: Color(0xFF00B894),
  ),
  Channel(
    id: 'morningbrew',
    name: 'Morning Brew Studio',
    handle: '@morningbrew',
    subscriberCount: 3200000,
    description: 'Long-form conversations with people shaping culture.',
    brandColor: Color(0xFFE17055),
  ),
  Channel(
    id: 'pixelframe',
    name: 'Pixel & Frame',
    handle: '@pixelframe',
    subscriberCount: 640000,
    description: 'Cinematography, gear, and photo essays.',
    brandColor: Color(0xFFD63031),
  ),
  Channel(
    id: 'dailybyte',
    name: 'The Daily Byte',
    handle: '@thedailybyte',
    subscriberCount: 5100000,
    description: 'A calm, clear take on the week\u2019s biggest stories.',
    brandColor: Color(0xFFE84393),
  ),
  Channel(
    id: 'soundscape',
    name: 'SoundScape',
    handle: '@soundscape',
    subscriberCount: 1800000,
    description: 'Original ambient music for focus and travel.',
    brandColor: Color(0xFF00CEC9),
  ),
  Channel(
    id: 'trailtrace',
    name: 'Trail & Trace',
    handle: '@trailandtrace',
    subscriberCount: 470000,
    description: 'Backpacking routes, maps, and honest gear reviews.',
    brandColor: Color(0xFF2D3436),
  ),
];

/// Builds realistic sample videos with timestamps relative to now so the
/// "Latest" filter behaves correctly whenever the app runs.
List<Video> buildMockVideos() {
  final now = DateTime.now();
  Video v({
    required String id,
    required String channelId,
    required String title,
    required int minutes,
    int seconds = 0,
    required int daysAgo,
    int hoursAgo = 0,
    required int views,
  }) {
    return Video(
      id: id,
      channelId: channelId,
      title: title,
      duration: Duration(minutes: minutes, seconds: seconds),
      publishedAt: now.subtract(Duration(days: daysAgo, hours: hoursAgo)),
      views: views,
    );
  }

  return <Video>[
    v(id: 'aurora-1', channelId: 'aurora', title: 'Why the Moon Is Slowly Leaving Us', minutes: 14, seconds: 32, daysAgo: 1, hoursAgo: 5, views: 840000),
    v(id: 'aurora-2', channelId: 'aurora', title: 'We Simulated a City on Mars \u2014 Here\u2019s What Broke', minutes: 22, seconds: 8, daysAgo: 9, views: 1200000),
    v(id: 'aurora-3', channelId: 'aurora', title: 'The Largest Telescope Ever Built, Explained', minutes: 18, seconds: 45, daysAgo: 42, views: 650000),

    v(id: 'codeforge-1', channelId: 'codeforge', title: 'Dart Records Are More Useful Than You Think', minutes: 11, seconds: 20, daysAgo: 0, hoursAgo: 9, views: 92000),
    v(id: 'codeforge-2', channelId: 'codeforge', title: 'Building a TUI App in 20 Minutes', minutes: 20, seconds: 4, daysAgo: 12, views: 310000),
    v(id: 'codeforge-3', channelId: 'codeforge', title: 'Why Your Builds Are Slow (and How to Fix Them)', minutes: 16, seconds: 55, daysAgo: 60, views: 480000),

    v(id: 'citywalks-1', channelId: 'citywalks', title: 'Night Walk Through Old Kyoto', minutes: 40, seconds: 12, daysAgo: 3, hoursAgo: 2, views: 210000),
    v(id: 'citywalks-2', channelId: 'citywalks', title: 'Lisbon at Dawn: A Morning Stroll', minutes: 35, seconds: 0, daysAgo: 20, views: 130000),
    v(id: 'citywalks-3', channelId: 'citywalks', title: 'Rainy Evening in Copenhagen', minutes: 45, seconds: 30, daysAgo: 75, views: 96000),

    v(id: 'morningbrew-1', channelId: 'morningbrew', title: 'What Games Studios Can Learn from Indie Teams', minutes: 58, seconds: 10, daysAgo: 2, hoursAgo: 8, views: 760000),
    v(id: 'morningbrew-2', channelId: 'morningbrew', title: 'A Conversation on Living Off the Grid', minutes: 64, seconds: 2, daysAgo: 15, views: 520000),

    v(id: 'pixelframe-1', channelId: 'pixelframe', title: 'How One Lens Changed the Way I Shoot', minutes: 12, seconds: 40, daysAgo: 4, hoursAgo: 11, views: 88000),
    v(id: 'pixelframe-2', channelId: 'pixelframe', title: 'Golden Hour Filming in the Desert', minutes: 9, seconds: 15, daysAgo: 33, views: 142000),

    v(id: 'dailybyte-1', channelId: 'dailybyte', title: 'The Week in 5 Minutes', minutes: 5, seconds: 18, daysAgo: 0, hoursAgo: 4, views: 950000),
    v(id: 'dailybyte-2', channelId: 'dailybyte', title: 'Why Ocean Maps Are Going Digital', minutes: 13, seconds: 0, daysAgo: 8, views: 405000),

    v(id: 'soundscape-1', channelId: 'soundscape', title: 'Focus Mix: Slow Waves', minutes: 60, seconds: 0, daysAgo: 5, views: 290000),
    v(id: 'soundscape-2', channelId: 'soundscape', title: 'Ambient Rain for Deep Work', minutes: 90, seconds: 0, daysAgo: 28, views: 540000),

    v(id: 'trailtrace-1', channelId: 'trailtrace', title: '5-Day Solo Loop \u2014 Full Gear Breakdown', minutes: 27, seconds: 35, daysAgo: 6, hoursAgo: 3, views: 41000),
    v(id: 'trailtrace-2', channelId: 'trailtrace', title: 'The Lightest Pack I\u2019ve Ever Used', minutes: 15, seconds: 48, daysAgo: 50, views: 73000),
  ];
}
