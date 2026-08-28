import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/channel_service.dart';
import '../services/content_repository.dart';
import '../services/feed_service.dart';
import '../services/settings_service.dart';
import 'channels_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// The app shell: hosts the three tabs with bottom navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.channelService,
    required this.feedService,
    required this.settingsService,
    required this.userProfile,
    this.repository,
    this.authService,
  });

  final ChannelService channelService;
  final FeedService feedService;
  final SettingsService settingsService;
  final UserProfile userProfile;

  /// Live data source for the Channels search tab.
  final ContentRepository? repository;

  /// Optional Google sign-in state for the Profile tab.
  final AuthService? authService;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  void _goToChannels() {
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        feedService: widget.feedService,
        channelService: widget.channelService,
        settingsService: widget.settingsService,
        onOpenChannels: _goToChannels,
      ),
      ChannelsScreen(
        channelService: widget.channelService,
        repository: widget.repository,
      ),
      ProfileScreen(
        userProfile: widget.userProfile,
        channelService: widget.channelService,
        settingsService: widget.settingsService,
        onManageChannels: _goToChannels,
        authService: widget.authService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library_rounded),
            label: 'Channels',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
