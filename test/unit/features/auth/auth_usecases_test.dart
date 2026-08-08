// ════════════════════════════════════════════════
// Project Lyra — Auth Use Cases Tests
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:project_lyra/core/errors/failure.dart';
import 'package:project_lyra/core/usecase/usecase.dart';
import 'package:project_lyra/features/auth/domain/entities/auth_entities.dart';
import 'package:project_lyra/features/auth/domain/repositories/auth_repository.dart';
import 'package:project_lyra/features/auth/domain/usecases/auth_usecases.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;
  late LoginWithEmail loginWithEmail;
  late Logout logout;
  late GetCurrentUser getCurrentUser;

  setUp(() {
    mockRepository = MockAuthRepository();
    loginWithEmail = LoginWithEmail(mockRepository);
    logout = Logout(mockRepository);
    getCurrentUser = GetCurrentUser(mockRepository);
  });

  final testUser = LyraUser(
    id: 'user_123',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  group('LoginWithEmail', () {
    test('returns user on success', () async {
      when(() => mockRepository.loginWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => Right(testUser));

      final result = await loginWithEmail(
        const LoginParams(email: 'test@example.com', password: 'password123'),
      );

      expect(result, Right(testUser));
      verify(() => mockRepository.loginWithEmail(
            email: 'test@example.com',
            password: 'password123',
          )).called(1);
    });

    test('returns failure on error', () async {
      when(() => mockRepository.loginWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const Left(UnauthorizedFailure()));

      final result = await loginWithEmail(
        const LoginParams(email: 'test@example.com', password: 'wrong'),
      );

      expect(result, const Left(UnauthorizedFailure()));
    });
  });

  group('Logout', () {
    test('returns Right on success', () async {
      when(() => mockRepository.logout())
          .thenAnswer((_) async => const Right(null));

      final result = await logout(const NoParams());

      expect(result, const Right(null));
      verify(() => mockRepository.logout()).called(1);
    });
  });

  group('GetCurrentUser', () {
    test('returns user when authenticated', () async {
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => Right(testUser));

      final result = await getCurrentUser(const NoParams());

      expect(result, Right(testUser));
    });

    test('returns null when not authenticated', () async {
      when(() => mockRepository.getCurrentUser())
          .thenAnswer((_) async => const Right(null));

      final result = await getCurrentUser(const NoParams());

      expect(result, const Right(null));
    });
  });
}
