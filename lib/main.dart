import 'package:flutter/material.dart';

import 'data/mock_data.dart';
import 'models/channel.dart';
import 'models/preferences.dart';
import 'models/user_profile.dart';
import 'models/video.dart';
import 'screens/home_shell.dart';
import 'services/channel_service.dart';
import 'services/feed_service.dart';
import 'services/local_store.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await LocalStore.loadPreferences();
  final followedIds = await LocalStore.loadFollowedIds();
  runApp(
    ChannelFeedApp(
      initialPreferences: preferences,
      initialSelected: followedIds,
      persistPreferences: LocalStore.savePreferences,
      persistSelection: LocalStore.saveFollowedIds,
    ),
  );
}

/// Root widget. Services are created once here and injected into the shell,
/// so channel selection and preferences stay alive across tab switches.
class ChannelFeedApp extends StatefulWidget {
  const ChannelFeedApp({
    super.key,
    this.channels,
    this.videos,
    this.userProfile,
    this.initialSelected,
    this.initialPreferences,
    this.persistPreferences,
    this.persistSelection,
  });

  final List<Channel>? channels;
  final List<Video>? videos;
  final UserProfile? userProfile;
  final Set<String>? initialSelected;
  final Preferences? initialPreferences;
  final Future<void> Function(Preferences preferences)? persistPreferences;
  final Future<void> Function(Set<String> selectedIds)? persistSelection;

  @override
  State<ChannelFeedApp> createState() => _ChannelFeedAppState();
}

class _ChannelFeedAppState extends State<ChannelFeedApp> {
  late final ChannelService _channelService;
  late final FeedService _feedService;
  late final SettingsService _settingsService;
  late final UserProfile _userProfile;

  @override
  void initState() {
    super.initState();
    final channels = widget.channels ?? mockChannels;
    _channelService = ChannelService(
      channels: channels,
      initiallySelected:
          widget.initialSelected ?? const <String>{'aurora', 'codeforge'},
      onSelectionChanged: widget.persistSelection,
    );
    _feedService = FeedService(
      channelService: _channelService,
      videos: widget.videos ?? buildMockVideos(),
    );
    _settingsService = SettingsService(
      initial: widget.initialPreferences,
      onChanged: widget.persistPreferences,
    );
    _userProfile = widget.userProfile ??
        const UserProfile(name: 'Alex Chen', email: 'alex.chen@example.com');
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorSchemeSeed: const Color(0xFF6C5CE7),
      brightness: brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        return MaterialApp(
          title: 'ChannelFeed',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: _settingsService.themeMode,
          home: HomeShell(
            channelService: _channelService,
            feedService: _feedService,
            settingsService: _settingsService,
            userProfile: _userProfile,
          ),
        );
      },
    );
  }
}
