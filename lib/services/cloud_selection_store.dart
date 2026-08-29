import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cloud persistence for the followed-channel selection, stored as a small
/// JSON file in the signed-in user's private Google Drive AppData folder.
///
/// AppData is app-specific storage that does not show up in the user's Drive
/// listing, making it a lightweight per-user key-value store for
/// cross-device sync. Local [LocalStore] storage stays as an offline cache.
class CloudSelectionStore {
  CloudSelectionStore({required this.accessTokenProvider});

  /// Provides a valid OAuth access token for [driveAppdataScope], or null when
  /// signed out or no token can be obtained.
  final Future<String?> Function() accessTokenProvider;

  static const String driveAppdataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const String fileName = 'channelfeed_selection.json';

  static Uri get _filesUri =>
      Uri.parse('https://www.googleapis.com/drive/v3/files');
  static Uri _uploadUri(String fileId) => Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files/$fileId?uploadType=media');

  /// Returns the stored channel ids, or null when none exist or the cloud
  /// is unreachable.
  Future<Set<String>?> fetch({http.Client? client}) async {
    final token = await accessTokenProvider();
    if (token == null) {
      return null;
    }
    final http.Client httpClient = client ?? http.Client();
    try {
      final fileId = await _findFile(httpClient, token);
      if (fileId == null) {
        return null;
      }
      final response = await httpClient.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: _authHeaders(token),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final ids = data['ids'];
      if (ids is! List) {
        return null;
      }
      return <String>{
        for (final id in ids)
          if (id is String && id.isNotEmpty) id,
      };
    } catch (_) {
      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Uploads [ids] to the AppData file. Returns false when the user is signed
  /// out or the cloud is unreachable.
  Future<bool> push(Set<String> ids, {http.Client? client}) async {
    final token = await accessTokenProvider();
    if (token == null) {
      return false;
    }
    final http.Client httpClient = client ?? http.Client();
    try {
      final fileId = await _findFile(httpClient, token) ??
          await _createFile(httpClient, token);
      if (fileId == null) {
        return false;
      }
      final body = jsonEncode(<String, Object>{
        'ids': ids.toList()..sort(),
      });
      final response = await httpClient.patch(
        _uploadUri(fileId),
        headers: <String, String>{
          ..._authHeaders(token),
          'Content-Type': 'application/json',
        },
        body: body,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  Future<String?> _createFile(http.Client client, String token) async {
    final response = await client.post(
      _filesUri,
      headers: <String, String>{
        ..._authHeaders(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'name': fileName,
        'parents': <String>['appDataFolder'],
      }),
    );
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['id'] as String?;
  }

  Future<String?> _findFile(http.Client client, String token) async {
    final response = await client.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files'
        '?spaces=appDataFolder&fields=files(id)'
        '&q=name%3D%27$fileName%27',
      ),
      headers: _authHeaders(token),
    );
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final files = data['files'];
    if (files is! List || files.isEmpty) {
      return null;
    }
    return (files.first as Map<String, dynamic>)['id'] as String?;
  }

  static Map<String, String> _authHeaders(String token) =>
      <String, String>{'Authorization': 'Bearer $token'};
}
