// ════════════════════════════════════════════════
// Project Lyra — History Entities
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_entities.freezed.dart';
part 'history_entities.g.dart';

@freezed
class HistoryEntry with _$HistoryEntry {
  const factory HistoryEntry({
    required String id,
    required String contentId,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String contentType,
    DateTime? playedAt,
    @Default(Duration.zero) Duration playedDuration,
    @Default(Duration.zero) Duration totalDuration,
    @Default(false) bool completed,
  }) = _HistoryEntry;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => _$HistoryEntryFromJson(json);
}

@freezed
class HistoryGroup with _$HistoryGroup {
  const factory HistoryGroup({
    required String date,
    @Default([]) List<HistoryEntry> entries,
  }) = _HistoryGroup;

  factory HistoryGroup.fromJson(Map<String, dynamic> json) => _$HistoryGroupFromJson(json);
}
