// ════════════════════════════════════════════════
// Project Lyra — Circuit Breaker Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/network/circuit_breaker/circuit_breaker.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        name: 'test',
        config: const CircuitBreakerConfig(
          failureThreshold: 3,
          successThreshold: 2,
          timeout: Duration(seconds: 1),
        ),
      );
    });

    test('starts in closed state', () {
      expect(breaker.state, CircuitState.closed);
      expect(breaker.isAvailable, true);
    });

    test('opens after failure threshold', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(breaker.state, CircuitState.open);
      expect(breaker.isAvailable, false);
    });

    test('throws CircuitBreakerOpenException when open', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(
        () => breaker.execute(() async => 'ok'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('transitions to half-open after timeout', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      expect(breaker.state, CircuitState.open);

      // Wait for timeout.
      await Future.delayed(const Duration(seconds: 2));

      // Next call should trigger half-open.
      final result = await breaker.execute(() async => 'ok');
      expect(result, 'ok');
    });

    test('closes after success threshold in half-open', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      await Future.delayed(const Duration(seconds: 2));

      // Two successful calls should close the circuit.
      await breaker.execute(() async => 'ok');
      await breaker.execute(() async => 'ok');

      expect(breaker.state, CircuitState.closed);
    });

    test('resets failure count on success', () async {
      try {
        await breaker.execute(() async => throw Exception('fail'));
      } catch (_) {}

      await breaker.execute(() async => 'ok');

      try {
        await breaker.execute(() async => throw Exception('fail'));
      } catch (_) {}

      // Should still be closed (only 1 failure after reset).
      expect(breaker.state, CircuitState.closed);
    });

    test('reset returns to closed state', () async {
      for (int i = 0; i < 3; i++) {
        try {
          await breaker.execute(() async => throw Exception('fail'));
        } catch (_) {}
      }

      breaker.reset();

      expect(breaker.state, CircuitState.closed);
      expect(breaker.isAvailable, true);
    });
  });
}
