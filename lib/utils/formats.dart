const List<String> _compactSuffixes = <String>['', 'K', 'M', 'B'];

/// Formats a large number into a compact string such as 1.2K, 3.4M, 5.1B.
String formatCompactNumber(int value) {
  if (value < 1000) {
    return '$value';
  }
  double scaled = value.toDouble();
  var suffixIndex = 0;
  while (scaled >= 1000 && suffixIndex < _compactSuffixes.length - 1) {
    scaled /= 1000;
    suffixIndex++;
  }
  final precision = scaled >= 100 ? 0 : (scaled >= 10 ? 1 : 2);
  final text = scaled.toStringAsFixed(precision);
  final trimmed = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return '$trimmed${_compactSuffixes[suffixIndex]}';
}

/// Formats a duration as mm:ss or hh:mm:ss.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$mm:$ss';
  }
  return '$mm:$ss';
}

/// Formats a timestamp as a short relative label such as "3h ago".
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final difference = reference.difference(time);
  if (difference.isNegative || difference.inSeconds < 60) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  if (difference.inDays < 30) {
    return '${difference.inDays ~/ 7}w ago';
  }
  if (difference.inDays < 365) {
    return '${difference.inDays ~/ 30}mo ago';
  }
  return '${difference.inDays ~/ 365}y ago';
}
