/// The local profile of the signed-in user.
class UserProfile {
  const UserProfile({required this.name, required this.email});

  final String name;
  final String email;

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'U' : trimmed[0].toUpperCase();
  }
}
