import 'package:flutter/material.dart';

import '../services/channel_service.dart';
import '../widgets/channel_card.dart';
import '../widgets/empty_state.dart';

/// Channels tab: search the channel directory and follow channels.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key, required this.channelService});

  final ChannelService channelService;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search channels',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
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
                child: ListenableBuilder(
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
                          selected: widget.channelService
                              .isSelected(channel.id),
                          onToggle: () => widget.channelService
                              .toggleSelection(channel.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
