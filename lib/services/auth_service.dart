import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The web OAuth 2.0 client ID for the serverClientId Android configuration.
///
/// Provide it at build/run time with:
/// `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>`
const String _googleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// Thin wrapper around [GoogleSignIn.instance] that tracks the signed-in
/// account and notifies listeners when the auth state changes.
class AuthService extends ChangeNotifier {
  AuthService();

  final GoogleSignIn _signIn = GoogleSignIn.instance;
  GoogleSignInAccount? _account;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  String? _errorMessage;

  GoogleSignInAccount? get account => _account;
  bool get isSignedIn => _account != null;

  /// Details of the last failed sign-in attempt, if any.
  String? get errorMessage => _errorMessage;

  /// Must be called once before any other method, e.g. from `main()`.
  Future<void> initialize() async {
    final serverClientId = _googleServerClientId;
    await _signIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _subscription = _signIn.authenticationEvents.listen(_handleEvent);
    await _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final restored = await _signIn.attemptLightweightAuthentication();
      if (restored != null) {
        _account = restored;
        notifyListeners();
      }
    } catch (_) {
      // A failed restore attempt leaves the user signed out.
    }
  }

  void _handleEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _account = event.user;
      case GoogleSignInAuthenticationEventSignOut():
        _account = null;
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    try {
      final account = await _signIn.authenticate();
      _account = account;
      _errorMessage = null;
      notifyListeners();
    } on GoogleSignInException catch (error) {
      _errorMessage = error.description;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    _account = null;
    notifyListeners();
  }

  /// Returns an OAuth access token for [scopes], prompting the user to grant
  /// access if it has not been granted yet, or null when signed out or the
  /// request fails.
  Future<String?> getAccessToken(List<String> scopes) async {
    final account = _account;
    if (account == null) {
      return null;
    }
    final client = account.authorizationClient;
    final cached = await client.authorizationForScopes(scopes);
    if (cached != null) {
      return cached.accessToken;
    }
    try {
      final prompted = await client.authorizeScopes(scopes);
      return prompted.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
