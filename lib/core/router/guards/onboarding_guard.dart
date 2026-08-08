// ════════════════════════════════════════════════
// Project Lyra — Onboarding Guard
// ════════════════════════════════════════════════
//
// Redirects first-time users to onboarding flow.
// State persisted in SharedPreferences.
// ════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/storage_constants.dart';
import '../../storage/local_storage.dart';

/// Provider for onboarding state.
final onboardingGuardProvider = Provider<OnboardingGuard>((ref) {
  // TODO(team): Inject actual storage provider.
  return OnboardingGuard(storage: null);
});

/// Manages onboarding completion state.
class OnboardingGuard extends ChangeNotifier {
  OnboardingGuard({required LocalStorage? storage}) : _storage = storage;

  final LocalStorage? _storage;
  bool _isComplete = false;

  bool get isComplete => _isComplete;

  /// Check if onboarding has been completed.
  Future<bool> checkOnboarding() async {
    if (_storage == null) return false;
    final value = await _storage.getBool(StorageConstants.keyOnboardingComplete);
    _isComplete = value ?? false;
    notifyListeners();
    return _isComplete;
  }

  /// Mark onboarding as complete.
  Future<void> completeOnboarding() async {
    _isComplete = true;
    await _storage?.setBool(StorageConstants.keyOnboardingComplete, true);
    notifyListeners();
  }

  /// Reset onboarding (for testing).
  Future<void> resetOnboarding() async {
    _isComplete = false;
    await _storage?.remove(StorageConstants.keyOnboardingComplete);
    notifyListeners();
  }
}
