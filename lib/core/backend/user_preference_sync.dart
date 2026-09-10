// ═════════════════════════════════════════════════════════════════════════════
// V Shots — User preference sync (cross-device, signed-in users)
// ═════════════════════════════════════════════════════════════════════════════
//
// Mirrors [PersonalizationStore]'s preference bundle into the EXISTING
// `user_taste_profile` table (user_id PK + profile JSONB) which already has
// owner-only RLS (read/update/upsert policies). No new tables, no policy
// changes, no service-role keys — the signed-in user's own JWT is the only
// writer, and RLS guarantees one user can never touch another user's row.
//
// Merge policy: freshest `updated_at` wins (device clocks drift, so ties
// prefer the REMOTE bundle on pull and the LOCAL bundle on push).
// Anonymous users: everything is a safe no-op — the local store remains the
// single source of truth and the app works exactly as before.
//
// All operations are fire-and-forget safe: failures log and never surface
// to the UI or block onboarding.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../storage/personalization_store.dart';
import 'supabase_service.dart';

class UserPreferenceSync {
  UserPreferenceSync._();

  static final UserPreferenceSync instance = UserPreferenceSync._();

  static const _table = 'user_taste_profile';
  bool _pushInFlight = false;

  /// Pushes the local preference bundle for the signed-in user.
  /// Merges into the existing `profile` JSONB (other keys are preserved).
  Future<void> pushIfSignedIn() async {
    final user = SupabaseService.currentUser;
    if (user == null) return; // Anonymous: local-only by design.
    if (_pushInFlight) return;
    _pushInFlight = true;
    try {
      final store = PersonalizationStore.instance;
      final bundle = store.toBundle();
      if (store.updatedAt == null) return; // Nothing chosen yet.

      final existing = await SupabaseService.client
          .from(_table)
          .select('profile')
          .eq('user_id', user.id)
          .maybeSingle();
      final remoteProfile =
          (existing?['profile'] as Map?)?.cast<String, dynamic>() ?? {};
      // Keep any OTHER keys already in the profile blob; own our namespace.
      remoteProfile['onboarding_prefs'] = bundle;

      await SupabaseService.client.from(_table).upsert({
        'user_id': user.id,
        'profile': remoteProfile,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('[PrefSync] pushed (${bundle['languages']?.length} langs, '
          '${bundle['artists']?.length} artists)');
    } catch (e) {
      debugPrint('[PrefSync] push failed (non-fatal): $e');
    } finally {
      _pushInFlight = false;
    }
  }

  /// Pulls the remote bundle on login/restore and adopts it when fresher
  /// than the local one. Returns true when local state changed.
  Future<bool> pullAndMergeIfSignedIn() async {
    final user = SupabaseService.currentUser;
    if (user == null) return false;
    try {
      final row = await SupabaseService.client
          .from(_table)
          .select('profile')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) return false;
      final profile = row['profile'] as Map?;
      final bundle = profile?['onboarding_prefs'];
      if (bundle is! Map) return false;
      final adopted = PersonalizationStore.instance
          .adoptRemoteBundle(bundle.cast<String, dynamic>());
      if (adopted) {
        debugPrint('[PrefSync] adopted fresher remote preferences');
      }
      return adopted;
    } catch (e) {
      debugPrint('[PrefSync] pull failed (non-fatal): $e');
      return false;
    }
  }
}
