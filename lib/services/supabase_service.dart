// Stub SupabaseService — replace with real supabase_flutter integration when ready.
// This keeps the project compiling without the supabase_flutter package.

class AuthResponse {
  final UserStub? user;
  final SessionStub? session;
  AuthResponse({this.user, this.session});
}

class SessionStub {
  final String accessToken;
  SessionStub({required this.accessToken});
}

class UserStub {
  final String? email;
  final Map<String, dynamic>? userMetadata;
  UserStub({this.email, this.userMetadata});
}

class SupabaseService {
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw Exception('Supabase not configured. Please integrate supabase_flutter.');
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    throw Exception('Supabase not configured. Please integrate supabase_flutter.');
  }

  Future<void> signOut() async {}
}
