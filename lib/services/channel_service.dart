import 'package:flutter/foundation.dart';

import '../models/channel.dart';

/// Holds the full channel directory and the set of followed channels.
///
/// Notifies listeners whenever the selection changes so the feed, search
/// results, and profile stay in sync. An optional [onSelectionChanged] callback
/// fires after every change so the caller can persist the selection
/// (see [LocalStore]).
class ChannelService extends ChangeNotifier {
  ChannelService({
    required List<Channel> channels,
    Set<String>? initiallySelected,
    Future<void> Function(Set<String> selectedIds)? onSelectionChanged,
  }) : _allChannels = List.of(channels) {
    _onSelectionChanged = onSelectionChanged;
    _rebuildIndex();
    _selectedIds = <String>{...?initiallySelected}
      ..removeWhere((id) => !_byId.containsKey(id));
  }

  final List<Channel> _allChannels;
  Future<void> Function(Set<String> selectedIds)? _onSelectionChanged;
  late Map<String, Channel> _byId;
  late Set<String> _selectedIds;

  List<Channel> get allChannels => _allChannels;
  int get selectedCount => _selectedIds.length;
  bool get hasSelection => _selectedIds.isNotEmpty;

  List<Channel> get selectedChannels =>
      [for (final channel in _allChannels) if (_selectedIds.contains(channel.id)) channel];

  Channel? channelById(String id) => _byId[id];
  bool isSelected(String id) => _selectedIds.contains(id);

  /// Returns channels matching [query] by name, handle, or description.
  List<Channel> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _allChannels;
    }
    return _allChannels.where((channel) {
      final handle = channel.handle?.toLowerCase() ?? '';
      return channel.name.toLowerCase().contains(q) ||
          handle.contains(q) ||
          channel.description.toLowerCase().contains(q);
    }).toList();
  }

  void toggleSelection(String id) {
    if (!_byId.containsKey(id)) {
      return;
    }
    if (!_selectedIds.remove(id)) {
      _selectedIds.add(id);
    }
    notifyListeners();
    _onSelectionChanged?.call(<String>{..._selectedIds});
  }

  /// Adds channels returned by the live API to the directory, or refreshes
  /// the details of channels that already exist. Selection state is preserved.
  void upsertChannels(List<Channel> channels) {
    if (channels.isEmpty) {
      return;
    }
    for (final channel in channels) {
      final index = _allChannels.indexWhere((c) => c.id == channel.id);
      if (index == -1) {
        _allChannels.add(channel);
      } else {
        _allChannels[index] = channel;
      }
    }
    _rebuildIndex();
    notifyListeners();
  }

  /// Marks exactly [ids] as selected and persists the result. Used to restore
  /// real YouTube channels that were followed before a restart.
  void setSelected(Set<String> ids) {
    final previous = Set<String>.of(_selectedIds);
    _selectedIds
      ..clear()
      ..addAll(ids.where(_byId.containsKey));
    if (setEquals(previous, _selectedIds)) {
      return;
    }
    notifyListeners();
    _onSelectionChanged?.call(<String>{..._selectedIds});
  }

  void _rebuildIndex() {
    _byId = <String, Channel>{
      for (final channel in _allChannels) channel.id: channel,
    };
  }
}
