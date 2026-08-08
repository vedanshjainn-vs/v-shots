// ════════════════════════════════════════════════
// Project Lyra — Result Type Tests
// ════════════════════════════════════════════════

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/errors/failure.dart';
import 'package:project_lyra/core/errors/result.dart';

void main() {
  group('Result Extensions', () {
    test('isSuccess returns true for Right', () {
      final result = Right<Failure, String>('data');
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
    });

    test('isFailure returns true for Left', () {
      final result = Left<Failure, String>(const NetworkFailure());
      expect(result.isFailure, true);
      expect(result.isSuccess, false);
    });

    test('dataOrNull returns data for Right', () {
      final result = Right<Failure, String>('hello');
      expect(result.dataOrNull, 'hello');
    });

    test('dataOrNull returns null for Left', () {
      final result = Left<Failure, String>(const NetworkFailure());
      expect(result.dataOrNull, isNull);
    });

    test('failureOrNull returns failure for Left', () {
      final result = Left<Failure, String>(const NetworkFailure());
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('dataOr returns default for Left', () {
      final result = Left<Failure, String>(const NetworkFailure());
      expect(result.dataOr('default'), 'default');
    });

    test('mapData transforms Right value', () {
      final result = Right<Failure, int>(5);
      final mapped = result.mapData((n) => n * 2);
      expect(mapped.dataOrNull, 10);
    });

    test('onSuccess executes callback on Right', () {
      String? captured;
      final result = Right<Failure, String>('hello');
      result.onSuccess((data) => captured = data);
      expect(captured, 'hello');
    });

    test('onFailure executes callback on Left', () {
      Failure? captured;
      final result = Left<Failure, String>(const NetworkFailure());
      result.onFailure((f) => captured = f);
      expect(captured, isA<NetworkFailure>());
    });
  });

  group('FutureResult Extensions', () {
    test('flatMap chains async operations', () async {
      final result = await Future.value(Right<Failure, int>(5))
          .flatMap((n) async => Right(n.toString()));

      expect(result.dataOrNull, '5');
    });

    test('flatMap short-circuits on failure', () async {
      bool secondCalled = false;

      final result = await Future.value(
        Left<Failure, int>(const NetworkFailure()),
      ).flatMap((n) async {
        secondCalled = true;
        return Right(n.toString());
      });

      expect(result.isFailure, true);
      expect(secondCalled, false);
    });
  });
}
