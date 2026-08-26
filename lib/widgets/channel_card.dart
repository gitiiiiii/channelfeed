import 'package:flutter/material.dart';

import '../models/channel.dart';

/// A channel row used in search results, showing a follow/selected toggle.
class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.channel,
    required this.selected,
    required this.onToggle,
  });

  final Channel channel;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: channel.brandColor,
              child: Text(
                channel.initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${channel.handle} \u2022 ${channel.subscriberLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            selected
                ? FilledButton.tonalIcon(
                    onPressed: onToggle,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Following'),
                  )
                : OutlinedButton.icon(
                    onPressed: onToggle,
                    icon: Icon(Icons.add, size: 18, color: primary),
                    label: Text(
                      'Follow',
                      style: TextStyle(color: primary),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
