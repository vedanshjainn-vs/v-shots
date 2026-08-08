// ════════════════════════════════════════════════
// Project Lyra — Event Bus Tests
// ════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:project_lyra/core/events/bus/app_event_bus.dart';
import 'package:project_lyra/core/events/types/app_event.dart';

void main() {
  group('AppEventBus', () {
    late AppEventBus bus;

    setUp(() {
      bus = AppEventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('receives emitted events', () async {
      final events = <AppEvent>[];

      bus.on<TrackPlayedEvent>((event) => events.add(event));

      bus.emit(const TrackPlayedEvent(
        trackId: '123',
        title: 'Test Track',
      ));

      await Future.delayed(Duration.zero);

      expect(events.length, 1);
      expect(events.first, isA<TrackPlayedEvent>());
      expect((events.first as TrackPlayedEvent).trackId, '123');
    });

    test('filters events by type', () async {
      final trackEvents = <TrackPlayedEvent>[];
      final authEvents = <UserSignedInEvent>[];

      bus.on<TrackPlayedEvent>((e) => trackEvents.add(e));
      bus.on<UserSignedInEvent>((e) => authEvents.add(e));

      bus.emit(const TrackPlayedEvent(trackId: '1', title: 'Song'));
      bus.emit(const UserSignedInEvent(userId: 'user1'));
      bus.emit(const TrackPlayedEvent(trackId: '2', title: 'Song 2'));

      await Future.delayed(Duration.zero);

      expect(trackEvents.length, 2);
      expect(authEvents.length, 1);
    });

    test('where returns filtered stream', () async {
      final events = <TrackPlayedEvent>[];

      bus.where<TrackPlayedEvent>().listen(events.add);

      bus.emit(const TrackPlayedEvent(trackId: '1', title: 'Song'));
      bus.emit(const UserSignedOutEvent());
      bus.emit(const TrackPlayedEvent(trackId: '2', title: 'Song 2'));

      await Future.delayed(Duration.zero);

      expect(events.length, 2);
    });

    test('multiple listeners receive same event', () async {
      int count = 0;

      bus.on<TrackPlayedEvent>((_) => count++);
      bus.on<TrackPlayedEvent>((_) => count++);

      bus.emit(const TrackPlayedEvent(trackId: '1', title: 'Song'));

      await Future.delayed(Duration.zero);

      expect(count, 2);
    });
  });
}
