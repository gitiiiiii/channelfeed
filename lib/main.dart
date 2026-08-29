import 'dart:async';

import 'package:flutter/material.dart';

import 'data/mock_data.dart';
import 'models/channel.dart';
import 'models/preferences.dart';
import 'models/user_profile.dart';
import 'models/video.dart';
import 'screens/home_shell.dart';
import 'services/auth_service.dart';
import 'services/channel_service.dart';
import 'services/cloud_selection_store.dart';
import 'services/content_repository.dart';
import 'services/feed_service.dart';
import 'services/local_store.dart';
import 'services/selection_sync.dart';
import 'services/settings_service.dart';
import 'services/youtube_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService();
  await authService.initialize();
  final cloudStore = CloudSelectionStore(
    accessTokenProvider: () => authService.getAccessToken(
      const <String>[CloudSelectionStore.driveAppdataScope],
    ),
  );
  final preferences = await LocalStore.loadPreferences();
  final followedIds = await LocalStore.loadFollowedIds();
  final repository = YoutubeContentRepository(YoutubeApiService());
  runApp(
    ChannelFeedApp(
      initialPreferences: preferences,
      initialSelected: followedIds,
      persistPreferences: LocalStore.savePreferences,
      persistSelection: LocalStore.saveFollowedIds,
      repository: repository,
      authService: authService,
      cloudStore: cloudStore,
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
    this.repository,
    this.authService,
    this.cloudStore,
  });

  final List<Channel>? channels;
  final List<Video>? videos;
  final UserProfile? userProfile;
  final Set<String>? initialSelected;
  final Preferences? initialPreferences;
  final Future<void> Function(Preferences preferences)? persistPreferences;
  final Future<void> Function(Set<String> selectedIds)? persistSelection;

  /// Live data source. When absent (or without an API key) the app runs in
  /// offline mode with mock data.
  final ContentRepository? repository;

  /// Google sign-in state for the Profile tab.
  final AuthService? authService;

  /// Cloud persistence for the followed-channel selection, used to sync the
  /// selection across devices when the user is signed in.
  final CloudSelectionStore? cloudStore;

  @override
  State<ChannelFeedApp> createState() => _ChannelFeedAppState();
}

class _ChannelFeedAppState extends State<ChannelFeedApp> {
  late final ChannelService _channelService;
  late final FeedService _feedService;
  late final SettingsService _settingsService;
  late final UserProfile _userProfile;
  late final ContentRepository? _repository;
  late final AuthService? _authService;
  late final CloudSelectionStore? _cloudStore;
  SelectionSync? _selectionSync;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _authService = widget.authService;
    _cloudStore = widget.cloudStore;
    final isLive = _repository?.isLive ?? false;
    final channels = widget.channels ?? mockChannels;
    _channelService = ChannelService(
      channels: channels,
      // In live mode the mock directory is not a valid starting selection, so
      // first launch starts empty and the user picks real channels.
      initiallySelected: widget.initialSelected ??
          (isLive ? const <String>{} : const <String>{'aurora', 'codeforge'}),
      onSelectionChanged: widget.persistSelection,
    );
    _feedService = FeedService(
      channelService: _channelService,
      videos: widget.videos ?? buildMockVideos(),
      repository: _repository,
    );
    _settingsService = SettingsService(
      initial: widget.initialPreferences,
      onChanged: widget.persistPreferences,
    );
    _userProfile = widget.userProfile ??
        const UserProfile(name: 'Alex Chen', email: 'alex.chen@example.com');
    final cloudStore = _cloudStore;
    final authService = _authService;
    if (cloudStore != null && authService != null) {
      _selectionSync = SelectionSync(
        authService: authService,
        channelService: _channelService,
        store: cloudStore,
      )..start();
    }
    if (isLive) {
      unawaited(_hydrateSelectedChannels());
    }
  }

  @override
  void dispose() {
    _selectionSync?.dispose();
    super.dispose();
  }

  /// Restores real YouTube channels that were followed before a restart by
  /// fetching their details and re-marking them as selected.
  Future<void> _hydrateSelectedChannels() async {
    final persisted = widget.initialSelected;
    final repository = _repository;
    if (repository == null || persisted == null || persisted.isEmpty) {
      return;
    }
    try {
      final details = await repository.fetchChannelDetails(persisted.toList());
      _channelService.upsertChannels(details);
      _channelService.setSelected(persisted);
    } catch (_) {
      // Offline or invalid key: the feed surface surfaces the error.
    }
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
            repository: _repository,
            authService: _authService,
          ),
        );
      },
    );
  }
}
