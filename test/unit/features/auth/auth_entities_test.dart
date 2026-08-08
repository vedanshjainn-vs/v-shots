// ════════════════════════════════════════════════
// Project Lyra — Auth Entity Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/features/auth/domain/entities/auth_entities.dart';

void main() {
  group('LyraUser', () {
    test('creates with required fields', () {
      const user = LyraUser(id: '1', email: 'test@test.com');

      expect(user.id, '1');
      expect(user.email, 'test@test.com');
      expect(user.isEmailVerified, false);
      expect(user.isAnonymous, false);
      expect(user.subscriptionTier, SubscriptionTier.free);
    });

    test('supports copyWith', () {
      const user = LyraUser(id: '1', email: 'test@test.com');
      final updated = user.copyWith(displayName: 'New Name');

      expect(updated.displayName, 'New Name');
      expect(updated.id, '1');
    });

    test('serializes to JSON', () {
      const user = LyraUser(id: '1', email: 'test@test.com', displayName: 'Test');
      final json = user.toJson();

      expect(json['id'], '1');
      expect(json['email'], 'test@test.com');
      expect(json['displayName'], 'Test');
    });

    test('deserializes from JSON', () {
      final json = {
        'id': '1',
        'email': 'test@test.com',
        'displayName': 'Test',
        'isEmailVerified': true,
      };

      final user = LyraUser.fromJson(json);

      expect(user.id, '1');
      expect(user.isEmailVerified, true);
    });

    test('equality works correctly', () {
      const user1 = LyraUser(id: '1', email: 'test@test.com');
      const user2 = LyraUser(id: '1', email: 'test@test.com');
      const user3 = LyraUser(id: '2', email: 'other@test.com');

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
    });
  });

  group('SubscriptionTier', () {
    test('isPremium returns false for free', () {
      expect(SubscriptionTier.free.isPremium, false);
    });

    test('isPremium returns true for premium', () {
      expect(SubscriptionTier.premium.isPremium, true);
    });

    test('displayName returns correct values', () {
      expect(SubscriptionTier.free.displayName, 'Free');
      expect(SubscriptionTier.premium.displayName, 'Premium');
    });
  });
}
