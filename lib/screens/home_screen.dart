import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/channel.dart';
import '../models/video.dart';
import '../services/channel_service.dart';
import '../services/feed_service.dart';
import '../services/settings_service.dart';
import '../widgets/channel_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/video_card.dart';

/// Home tab: the personalized vertical feed.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.feedService,
    required this.channelService,
    required this.settingsService,
    this.onOpenChannels,
  });

  final FeedService feedService;
  final ChannelService channelService;
  final SettingsService settingsService;
  final VoidCallback? onOpenChannels;

  /// Opens a video in the official YouTube app/browser without modifying it.
  Future<void> _openVideo(BuildContext context, Video video) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${video.id}');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showOpenError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenError(context);
      }
    }
  }

  void _showOpenError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this video.')),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SegmentedButton<FeedFilter>(
        segments: const <ButtonSegment<FeedFilter>>[
          ButtonSegment<FeedFilter>(
            value: FeedFilter.all,
            label: Text('All'),
            icon: Icon(Icons.view_stream_outlined),
          ),
          ButtonSegment<FeedFilter>(
            value: FeedFilter.latest,
            label: Text('Latest'),
            icon: Icon(Icons.access_time_filled),
          ),
          ButtonSegment<FeedFilter>(
            value: FeedFilter.channels,
            label: Text('Channels'),
            icon: Icon(Icons.video_library_outlined),
          ),
        ],
        selected: <FeedFilter>{feedService.filter},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          feedService.filter = selection.first;
        },
      ),
    );
  }

  Widget _buildNoChannelsState() {
    return EmptyState(
      icon: Icons.subscriptions_outlined,
      title: 'No channels selected',
      message: 'Your feed is built only from channels you follow. '
          'Select a few to see their videos here.',
      action: onOpenChannels == null
          ? null
          : FilledButton.icon(
              onPressed: onOpenChannels,
              icon: const Icon(Icons.add),
              label: const Text('Browse channels'),
            ),
    );
  }

  Widget _buildFeedErrorState() {
    return EmptyState(
      icon: Icons.cloud_off,
      title: 'Could not load your feed',
      message: feedService.errorMessage ?? 'Something went wrong.',
      action: FilledButton.icon(
        onPressed: feedService.refresh,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }

  Widget _buildVideoList(BuildContext context, List<Video> videos) {
    if (videos.isEmpty) {
      return EmptyState(
        icon: Icons.play_circle_outline,
        title: 'Your feed is empty',
        message: 'Follow a few channels to build a personalized feed, or '
            'check back later for fresh uploads.',
        action: onOpenChannels == null
            ? null
            : FilledButton.icon(
                onPressed: onOpenChannels,
                icon: const Icon(Icons.add),
                label: const Text('Browse channels'),
              ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final channel = channelService.channelById(video.channelId);
        if (channel == null) {
          return const SizedBox.shrink();
        }
        return VideoCard(
          video: video,
          channel: channel,
          showViewCounts: settingsService.showViewCounts,
          onTap: () => _openVideo(context, video),
        );
      },
    );
  }

  Widget _buildChannelsView(BuildContext context) {
    final grouped = <(Channel, List<Video>)>[];
    for (final channel in channelService.selectedChannels) {
      final videos = feedService.allVideos
          .where((video) => video.channelId == channel.id)
          .toList();
      if (videos.isNotEmpty) {
        grouped.add((channel, videos));
      }
    }
    if (grouped.isEmpty) {
      return const EmptyState(
        icon: Icons.video_library_outlined,
        title: 'Nothing here yet',
        message: 'Your followed channels have not uploaded any videos yet.',
      );
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: <Widget>[
        for (final (channel, videos) in grouped) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: <Widget>[
                ChannelAvatar(channel: channel, radius: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    channel.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          for (final video in videos)
            VideoCard(
              video: video,
              channel: channel,
              showViewCounts: settingsService.showViewCounts,
              onTap: () => _openVideo(context, video),
            ),
        ],
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!channelService.hasSelection) {
      return _buildNoChannelsState();
    }
    if (feedService.isLive) {
      if (feedService.isLoading && !feedService.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (feedService.errorMessage != null && !feedService.hasData) {
        return _buildFeedErrorState();
      }
    }
    if (feedService.filter == FeedFilter.channels) {
      return _buildChannelsView(context);
    }
    return _buildVideoList(context, feedService.resolve(feedService.filter));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ChannelFeed',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Your curated feed',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          feedService,
          channelService,
          settingsService,
        ]),
        builder: (context, _) {
          return Column(
            children: <Widget>[
              _buildFilterBar(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _buildContent(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
