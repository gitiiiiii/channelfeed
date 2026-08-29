import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/channel_service.dart';
import '../widgets/channel_avatar.dart';
import '../widgets/empty_state.dart';
import 'youtube_webview_screen.dart';

/// A lightweight list of the channels the user has selected.
///
/// Each channel opens in the in-app YouTube WebView. The list stays in sync
/// with [ChannelService], so adding or removing a selection is reflected
/// immediately without an app restart.
class SelectedChannelsScreen extends StatelessWidget {
  const SelectedChannelsScreen({
    super.key,
    required this.channelService,
    this.onBrowseChannels,
  });

  final ChannelService channelService;

  /// Called from the zero-selection state to jump to the Channels tab.
  final VoidCallback? onBrowseChannels;

  void _openChannel(BuildContext context, Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YoutubeWebViewScreen(
          initialUrl: channel.youtubeUrl,
          title: channel.name,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return EmptyState(
      icon: Icons.subscriptions_outlined,
      title: 'No channels selected',
      message: 'Follow a few channels to browse their YouTube pages here.',
      action: onBrowseChannels == null
          ? null
          : FilledButton.icon(
              onPressed: onBrowseChannels,
              icon: const Icon(Icons.search),
              label: const Text('Browse channels'),
            ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    final channels = channelService.selectedChannels;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final handle = channel.handle;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: ChannelAvatar(channel: channel, radius: 24),
            title: Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: handle == null
                ? null
                : Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
            trailing: IconButton(
              tooltip: 'Remove ${channel.name}',
              icon: const Icon(Icons.close),
              onPressed: () => channelService.toggleSelection(channel.id),
            ),
            onTap: () => _openChannel(context, channel),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selected Channels')),
      body: ListenableBuilder(
        listenable: channelService,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: channelService.hasSelection
                  ? _buildList(context)
                  : _buildEmpty(),
            ),
          );
        },
      ),
    );
  }
}
