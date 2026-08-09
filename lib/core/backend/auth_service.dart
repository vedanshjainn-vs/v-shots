// ════════════════════════════════════════════════
// V Shots — Auth Service (Google Sign-In via Supabase)
// ════════════════════════════════════════════════
//
// Implements Supabase's officially documented native Google Sign-In
// flow for Flutter: https://supabase.com/blog/flutter-authentication
//
// ⚠️ CRITICAL CONFIGURATION STEP THIS CODE CANNOT DO FOR YOU:
// Supabase's own docs are explicit: "open Authentication -> Providers ->
// Google... add the WEB client ID you obtained... to Authorized Client
// IDs field. No need to add the Android or iOS client IDs here."
//
// This requires a Google **Client Secret** (from the same Web OAuth
// client whose ID is in .env as GOOGLE_WEB_CLIENT_ID) to be entered
// into the Supabase Dashboard's Google provider settings. That secret
// was NOT provided to this session (only a Client ID was), and
// Supabase's provider config can only be changed via the Dashboard UI
// or a separate "Management API" personal access token (distinct from
// both the anon key and the database password we have) — neither of
// which this session has access to.
//
// ACTION REQUIRED FROM YOU before Google Sign-In will work end-to-end:
//   1. Go to https://supabase.com/dashboard/project/jzxtxqjheggyoqwohqjg/auth/providers
//   2. Enable the Google provider.
//   3. Paste the Web Client ID (same value as GOOGLE_WEB_CLIENT_ID in
//      .env) into "Client ID (for OAuth)".
//   4. Paste the corresponding Client Secret (from Google Cloud Console
//      -> Credentials -> your Web OAuth client) into "Client Secret".
//   5. Confirm the OAuth client's "Authorized redirect URIs" in Google
//      Cloud Console includes the callback URL Supabase shows on that
//      same provider settings page.
// Until this is done, calling signInWithGoogle() below will fail at
// the supabase.auth.signInWithIdToken() step with an audience/config
// error from Supabase — that failure is expected and does not indicate
// a bug in this Dart code.
// ════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AuthResult {
  const AuthResult.success(this.user) : error = null;
  const AuthResult.failure(this.error) : user = null;

  final User? user;
  final String? error;

  bool get isSuccess => error == null;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  GoogleSignIn? _googleSignIn;

  GoogleSignIn _getGoogleSignIn() {
    // Lazily constructed so a missing .env value doesn't crash app
    // startup — only fails when the user actually taps "Sign in with
    // Google", with a clear message instead of a startup crash.
    if (_googleSignIn != null) return _googleSignIn!;

    final webClientId = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID');
    if (webClientId == null || webClientId.isEmpty) {
      throw StateError(
        'GOOGLE_WEB_CLIENT_ID missing from .env — cannot configure '
        'Google Sign-In.',
      );
    }

    // serverClientId (not clientId) is the correct parameter here —
    // per Supabase's own docs and the google_sign_in package docs,
    // this must be the WEB client ID even on Android; Android's own
    // client ID is auto-matched by Google Play Services via the app's
    // package name + registered SHA-1 fingerprints and is never passed
    // in code.
    return _googleSignIn = GoogleSignIn(serverClientId: webClientId);
  }

  /// Signs in with Google and exchanges the resulting ID token for a
  /// Supabase session. Returns AuthResult.failure with a human-readable
  /// message on any failure — never throws, so callers can show the
  /// error directly in a SnackBar without a try/catch of their own.
  Future<AuthResult> signInWithGoogle() async {
    if (!SupabaseService.isAvailable) {
      return const AuthResult.failure(
        'Cloud sign-in is unavailable right now. You can still use the '
        'app without an account.',
      );
    }

    try {
      final googleSignIn = _getGoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the picker — not an error.
        return const AuthResult.failure(null);
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return const AuthResult.failure(
          'Google did not return an ID token. Please try again.',
        );
      }

      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        return const AuthResult.failure(
          'Sign-in failed — please try again.',
        );
      }

      return AuthResult.success(response.user);
    } on AuthException catch (e) {
      // This is the exact failure mode described in the file header if
      // the Supabase Dashboard's Google provider isn't configured yet.
      debugPrint('[AuthService] Supabase AuthException: ${e.message}');
      return AuthResult.failure(
        'Sign-in configuration issue: ${e.message}. If you are the '
        'developer, see the setup steps at the top of auth_service.dart.',
      );
    } catch (e) {
      debugPrint('[AuthService] Unexpected sign-in error: $e');
      return const AuthResult.failure(
        'Something went wrong signing in. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (_) {
      // Non-fatal — proceed to sign out of Supabase regardless.
    }
    if (SupabaseService.isAvailable) {
      await SupabaseService.client.auth.signOut();
    }
  }

  bool get isSignedIn => SupabaseService.currentUser != null;
}
