// ════════════════════════════════════════════════
// V Shots — Auth Service (Google Sign-In via Supabase)
// ════════════════════════════════════════════════
//
// Implements Supabase's officially documented native Google Sign-In
// flow: https://supabase.com/blog/flutter-authentication
//
// ⚠️ Uses the google_sign_in v7.x API, which is a COMPLETE breaking
// redesign from v6.x and earlier (confirmed via pub.dev's own package
// page + changelog during this session — this is not a guess):
//   - GoogleSignIn is now a singleton: GoogleSignIn.instance (no more
//     `GoogleSignIn(...)` constructor — that now throws
//     "doesn't have an unnamed constructor").
//   - You MUST call `await GoogleSignIn.instance.initialize(...)`
//     exactly once before calling any other method.
//   - `signIn()` is gone; the replacement is `authenticate()`.
//   - Authentication (identity/idToken) and Authorization
//     (accessToken/scopes) are now separate steps — `authenticate()`
//     only gives you identity; to get an accessToken you must
//     additionally call `authorizationClient.authorizeScopes(...)`.
//     Supabase's signInWithIdToken only strictly requires the idToken,
//     so this service requests the accessToken too (Supabase's own
//     example passes both) but treats it as optional.
//
// ⚠️ CRITICAL CONFIGURATION STEP THIS CODE CANNOT DO FOR YOU:
// Supabase's own docs are explicit: "open Authentication -> Providers ->
// Google... add the WEB client ID you obtained... to Authorized Client
// IDs field." This requires a Google **Client Secret** (from the Web
// OAuth client whose ID is in .env as GOOGLE_WEB_CLIENT_ID) to be
// entered into the Supabase Dashboard's Google provider settings. That
// secret was not provided to this session (only a Client ID was), and
// changing Supabase's provider config requires either the Dashboard UI
// or a separate Management API personal access token (distinct from
// both the anon key and the database password available this session).
//
// ACTION REQUIRED FROM YOU before Google Sign-In works end-to-end:
//   1. https://supabase.com/dashboard/project/jzxtxqjheggyoqwohqjg/auth/providers
//   2. Enable the Google provider.
//   3. Paste the Web Client ID (same value as GOOGLE_WEB_CLIENT_ID in
//      .env) into "Client ID (for OAuth)".
//   4. Paste the corresponding Client Secret (Google Cloud Console ->
//      Credentials -> your Web OAuth client) into "Client Secret".
//   5. Confirm that OAuth client's "Authorized redirect URIs" in Google
//      Cloud Console includes the callback URL Supabase shows on that
//      same settings page.
// Until this is done, signInWithGoogle() will fail at the
// supabase.auth.signInWithIdToken() step with a config/audience error
// from Supabase — expected, not a bug in this Dart code.
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

  bool _googleSignInReady = false;

  /// Must be called once, early (e.g. from main() alongside
  /// SupabaseService.initialize()), per google_sign_in v7's mandatory
  /// initialize() requirement. Safe to call multiple times.
  Future<void> initializeGoogleSignIn() async {
    if (_googleSignInReady) return;

    final webClientId = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID');
    if (webClientId == null || webClientId.isEmpty) {
      debugPrint(
        '[AuthService] GOOGLE_WEB_CLIENT_ID missing from .env — Google '
        'Sign-In disabled. Other app features are unaffected.',
      );
      return;
    }

    try {
      // serverClientId (not clientId) is the correct parameter for
      // "sign in on Android but verify the ID token against a backend
      // that expects a Web-type audience" — which is exactly Supabase's
      // model. See the file-level note on Web vs Android client IDs.
      await GoogleSignIn.instance.initialize(serverClientId: webClientId);
      _googleSignInReady = true;
      debugPrint('[AuthService] GoogleSignIn initialized.');
    } catch (e) {
      debugPrint('[AuthService] GoogleSignIn.initialize() failed: $e');
    }
  }

  /// Signs in with Google and exchanges the resulting ID token for a
  /// Supabase session. Returns AuthResult.failure with a human-readable
  /// message on any failure — never throws, so callers can show the
  /// error directly in a SnackBar without their own try/catch.
  Future<AuthResult> signInWithGoogle() async {
    if (!SupabaseService.isAvailable) {
      return const AuthResult.failure(
        'Cloud sign-in is unavailable right now. You can still use the '
        'app without an account.',
      );
    }

    await initializeGoogleSignIn();
    if (!_googleSignInReady) {
      return const AuthResult.failure(
        'Google Sign-In is not configured. See auth_service.dart.',
      );
    }

    try {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return const AuthResult.failure(
          'Google Sign-In is not supported on this platform.',
        );
      }

      final googleUser = await GoogleSignIn.instance.authenticate();

      // Identity (idToken) — synchronous in v7, not a Future.
      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        return const AuthResult.failure(
          'Google did not return an ID token. Please try again.',
        );
      }

      // Authorization (accessToken) is now a SEPARATE step in v7 — best
      // effort only. Supabase's signInWithIdToken works with just the
      // idToken; the accessToken is passed along when available because
      // Supabase's own official example does the same.
      String? accessToken;
      try {
        final authorization = await googleUser.authorizationClient
            .authorizeScopes(<String>['email', 'profile']);
        accessToken = authorization.accessToken;
      } catch (e) {
        debugPrint(
          '[AuthService] Could not obtain accessToken (non-fatal, '
          'idToken alone is sufficient for Supabase): $e',
        );
      }

      final response = await SupabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        return const AuthResult.failure('Sign-in failed — please try again.');
      }

      return AuthResult.success(response.user);
    } on GoogleSignInException catch (e) {
      // User cancelled the picker is one of several GoogleSignInException
      // codes in v7 — treat cancellation as a silent non-error.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const AuthResult.failure(null);
      }
      debugPrint(
        '[AuthService] GoogleSignInException: ${e.code} ${e.description}',
      );
      return AuthResult.failure(
        'Google Sign-In failed: ${e.description ?? e.code}',
      );
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
      if (_googleSignInReady) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      // Non-fatal — proceed to sign out of Supabase regardless.
    }
    if (SupabaseService.isAvailable) {
      await SupabaseService.client.auth.signOut();
    }
  }

  /// Deletes the signed-in Auth user via the server-side
  /// `delete_own_account` RPC (SECURITY DEFINER, auth.uid() only).
  /// Never uses a service-role key in the client.
  Future<AuthResult> deleteAccount() async {
    if (!SupabaseService.isAvailable) {
      return const AuthResult.failure(
        'Account deletion is unavailable right now. Please try again later.',
      );
    }
    final user = SupabaseService.currentUser;
    if (user == null) {
      return const AuthResult.failure(
        'You need to be signed in to delete your account.',
      );
    }
    try {
      await SupabaseService.client.rpc<void>('delete_own_account');
    } on AuthException catch (e) {
      debugPrint(
        '[AuthService] delete_own_account AuthException: ${e.message}',
      );
      return AuthResult.failure('Could not delete account: ${e.message}');
    } catch (e) {
      debugPrint('[AuthService] delete_own_account failed: $e');
      return const AuthResult.failure(
        'Could not delete account. Please try again.',
      );
    }
    return const AuthResult.success(null);
  }

  bool get isSignedIn => SupabaseService.currentUser != null;
}
