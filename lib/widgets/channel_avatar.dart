import 'package:flutter/material.dart';

import '../models/channel.dart';

/// Circular channel avatar. Shows the channel's artwork when available and
/// falls back to a brand-colored initial otherwise.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({
    super.key,
    required this.channel,
    this.radius = 18,
  });

  final Channel channel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: channel.brandColor,
      child: Text(
        channel.initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.77,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final url = channel.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}
