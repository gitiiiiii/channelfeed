import 'package:flutter/foundation.dart';

import '../models/channel.dart';

/// Holds the full channel directory and the set of followed channels.
///
/// Notifies listeners whenever the selection changes so the feed, search
/// results, and profile stay in sync.
class ChannelService extends ChangeNotifier {
  ChannelService({
    required List<Channel> channels,
    Set<String>? initiallySelected,
  }) : _allChannels = List.unmodifiable(channels) {
    _byId = <String, Channel>{for (final channel in _allChannels) channel.id: channel};
    _selectedIds = <String>{...?initiallySelected}
      ..removeWhere((id) => !_byId.containsKey(id));
  }

  final List<Channel> _allChannels;
  late final Map<String, Channel> _byId;
  late final Set<String> _selectedIds;

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
      return channel.name.toLowerCase().contains(q) ||
          channel.handle.toLowerCase().contains(q) ||
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
  }
}
