import 'dart:async';

import 'auth_service.dart';
import 'channel_service.dart';
import 'cloud_selection_store.dart';

/// Keeps the followed-channel selection in sync with the signed-in user's
/// cloud copy.
///
/// On sign-in the cloud copy and the local selection are merged (a union, so
/// neither set is lost) and pushed back up. While signed in, every selection
/// change is debounced and pushed to the cloud. Offline/network failures are
/// swallowed so local functionality is never affected.
class SelectionSync {
  SelectionSync({
    required this.authService,
    required this.channelService,
    required this.store,
    this.pushDebounce = const Duration(milliseconds: 800),
  });

  final AuthService authService;
  final ChannelService channelService;
  final CloudSelectionStore store;
  final Duration pushDebounce;

  Timer? _debounce;
  bool _disposed = false;
  bool _syncing = false;

  void start() {
    authService.addListener(_onAuthChanged);
    channelService.addListener(_onChannelsChanged);
    if (authService.isSignedIn) {
      unawaited(syncNow());
    }
  }

  void _onAuthChanged() {
    if (authService.isSignedIn) {
      unawaited(syncNow());
    } else {
      _debounce?.cancel();
    }
  }

  void _onChannelsChanged() {
    if (_disposed || !authService.isSignedIn) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(pushDebounce, () {
      unawaited(_push());
    });
  }

  /// Merges the cloud copy with the local selection and pushes the result.
  ///
  /// Safe to call anytime, e.g. right after a sign-in or during a test.
  Future<void> syncNow() async {
    if (_syncing || _disposed) {
      return;
    }
    _syncing = true;
    try {
      final cloud = await store.fetch();
      final local = _selectedIds();
      final merged = <String>{...?cloud, ...local};
      channelService.setSelected(merged);
      await store.push(merged);
    } catch (_) {
      // Offline or cloud unavailable: the local selection is unaffected.
    } finally {
      _syncing = false;
    }
  }

  Future<void> _push() async {
    if (_syncing || _disposed) {
      return;
    }
    _syncing = true;
    try {
      await store.push(_selectedIds());
    } catch (_) {
      // Offline or cloud unavailable: the local selection is unaffected.
    } finally {
      _syncing = false;
    }
  }

  Set<String> _selectedIds() => <String>{
        for (final channel in channelService.selectedChannels) channel.id,
      };

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    authService.removeListener(_onAuthChanged);
    channelService.removeListener(_onChannelsChanged);
  }
}
