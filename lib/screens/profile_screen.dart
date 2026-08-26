import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/channel_service.dart';
import '../services/settings_service.dart';

/// Profile tab: user info, followed channels, and preferences.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.userProfile,
    required this.channelService,
    required this.settingsService,
    this.onManageChannels,
  });

  final UserProfile userProfile;
  final ChannelService channelService;
  final SettingsService settingsService;
  final VoidCallback? onManageChannels;

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              userProfile.initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  userProfile.name,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  userProfile.email,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  '${channelService.selectedCount} channels followed',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }

  Widget _buildChannelsSection(BuildContext context) {
    final theme = Theme.of(context);
    final selected = channelService.selectedChannels;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selected.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'No channels yet',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Follow channels to build your personal feed.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (onManageChannels != null)
                    FilledButton.tonalIcon(
                      onPressed: onManageChannels,
                      icon: const Icon(Icons.search),
                      label: const Text('Browse channels'),
                    ),
                ],
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final channel in selected)
                    InputChip(
                      avatar: CircleAvatar(
                        backgroundColor: channel.brandColor,
                        child: Text(
                          channel.initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      label: Text(channel.name),
                      onDeleted: () =>
                          channelService.toggleSelection(channel.id),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: <Widget>[
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_motion_outlined),
            title: const Text('Autoplay next video'),
            subtitle: const Text('Preload the next video in your feed.'),
            value: settingsService.autoplay,
            onChanged: settingsService.setAutoplay,
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Show view counts'),
            subtitle: const Text('Display views on each video card.'),
            value: settingsService.showViewCounts,
            onChanged: settingsService.setShowViewCounts,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.palette_outlined, size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Theme',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Choose how ChannelFeed looks.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: <ThemeMode>{settingsService.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    settingsService.setThemeMode(selection.first);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: <Widget>[
          Text(
            'ChannelFeed builds a feed from only the channels you choose. '
            'It is an independent app and does not control or modify any '
            'other application.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            'ChannelFeed v1.0.0',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          channelService,
          settingsService,
        ]),
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: <Widget>[
                  _buildHeader(context),
                  _buildSectionTitle(context, 'YOUR CHANNELS'),
                  _buildChannelsSection(context),
                  _buildSectionTitle(context, 'SETTINGS'),
                  _buildSettingsSection(context),
                  _buildAboutSection(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
