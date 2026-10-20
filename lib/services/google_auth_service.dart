import 'package:google_sign_in/google_sign_in.dart';

/// Native Google Sign-In, shared by "Continue with Google" (login) and
/// "Connect Google" (Login & Security) so the client setup lives in one place.
class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  /// Web OAuth client ID from BuyTheWay - Web's .env (GOOGLE_CLIENT_ID). It
  /// doubles as the `serverClientId` the native SDK needs to mint an
  /// id_token the backend's audience check accepts.
  static const String serverClientId =
      '968790382765-ueq74oaa6njkt297sqvgfn831g2vmnbs.apps.googleusercontent.com';

  final GoogleSignIn _google = GoogleSignIn.instance;
  Future<void>? _initialized;

  Future<void> _ensureInitialized() {
    return _initialized ??= _google
        .initialize(serverClientId: serverClientId)
        .catchError((Object e) {
      _initialized = null; // allow a retry after a failed init
      throw e;
    });
  }

  /// Shows the account chooser and returns the chosen account's id_token, or
  /// null if the user cancelled. Signs out first so the chooser always
  /// appears instead of silently reusing the last Google account.
  Future<String?> pickIdToken() async {
    await _ensureInitialized();
    await signOut();
    try {
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const GoogleAuthException();
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const GoogleAuthException();
    }
  }

  /// Clears the device's Google session; never throws.
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _google.signOut();
    } catch (_) {}
  }
}

/// Google could not hand back a usable account (anything but cancelling).
class GoogleAuthException implements Exception {
  const GoogleAuthException();

  @override
  String toString() => 'Google sign-in failed. Please try again.';
}
