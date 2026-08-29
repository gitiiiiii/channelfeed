import 'dart:async';

import 'package:flutter/material.dart';

import '../models/channel.dart';
import '../services/channel_service.dart';
import '../services/content_repository.dart';
import '../widgets/channel_card.dart';
import '../widgets/empty_state.dart';
import 'youtube_webview_screen.dart';

/// Channels tab: search the channel directory and follow channels.
///
/// With a live [ContentRepository] the search hits the YouTube Data API
/// (debounced); without one the built-in channel directory is searched.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({
    super.key,
    required this.channelService,
    this.repository,
  });

  final ChannelService channelService;
  final ContentRepository? repository;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _remoteSearching = false;
  String? _remoteError;
  List<Channel> _remoteResults = <Channel>[];

  bool get _isLive => widget.repository?.isLive ?? false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    if (!_isLive) {
      return;
    }
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _remoteResults = <Channel>[];
        _remoteError = null;
        _remoteSearching = false;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _runRemoteSearch(value));
  }

  Future<void> _runRemoteSearch(String query) async {
    setState(() {
      _remoteSearching = true;
      _remoteError = null;
    });
    try {
      final results = await widget.repository!.searchChannels(query);
      if (!mounted) {
        return;
      }
      setState(() => _remoteResults = results);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _remoteError = 'Could not reach YouTube. '
            'Check your connection and API key.';
      });
    } finally {
      if (mounted) {
        setState(() => _remoteSearching = false);
      }
    }
  }

  void _followRemoteChannel(Channel channel) {
    widget.channelService.upsertChannels(<Channel>[channel]);
    widget.channelService.toggleSelection(channel.id);
  }

  void _openChannel(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YoutubeWebViewScreen(
          initialUrl: channel.youtubeUrl,
          title: channel.name,
        ),
      ),
    );
  }

  Widget _buildLocalResults(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.channelService,
      builder: (context, _) {
        final results = widget.channelService.search(_query);
        if (results.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: 'No channels found',
            message: 'Try a different name or keyword.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final channel = results[index];
            return ChannelCard(
              channel: channel,
              selected:
                  widget.channelService.isSelected(channel.id),
              onToggle: () =>
                  widget.channelService.toggleSelection(channel.id),
              onOpen: () => _openChannel(channel),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveResults(BuildContext context) {
    if (_query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search YouTube',
        message: 'Find channels by name or handle and follow them '
            'to build your feed.',
      );
    }
    if (_remoteSearching && _remoteResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_remoteError != null && _remoteResults.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'Search failed',
        message: _remoteError!,
        action: OutlinedButton.icon(
          onPressed: () => _runRemoteSearch(_query),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (_remoteResults.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No channels found',
        message: 'Try a different name or keyword.',
      );
    }
    return ListenableBuilder(
      listenable: widget.channelService,
      builder: (context, _) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: _remoteResults.length,
          itemBuilder: (context, index) {
            final channel = _remoteResults[index];
            return ChannelCard(
              channel: channel,
              selected: widget.channelService.isSelected(channel.id),
              onToggle: () => _followRemoteChannel(channel),
              onOpen: () => _openChannel(channel),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: <Widget>[
          ListenableBuilder(
            listenable: widget.channelService,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Chip(
                    avatar: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text('${widget.channelService.selectedCount} '
                        'following'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: _isLive
                    ? 'Search YouTube channels'
                    : 'Search channels',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _isLive
                    ? _buildLiveResults(context)
                    : _buildLocalResults(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
