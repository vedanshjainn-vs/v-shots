// ════════════════════════════════════════════════
// Project Lyra — History Data Models
// ════════════════════════════════════════════════

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/history_entities.dart';

part 'history_models.freezed.dart';
part 'history_models.g.dart';

@freezed
class HistoryEntryModel with _$HistoryEntryModel {
  const factory HistoryEntryModel({
    required String id,
    required String contentId,
    required String title,
    String? subtitle,
    String? imageUrl,
    required String contentType,
    String? playedAt,
    @Default(0) int playedDurationMs,
    @Default(0) int totalDurationMs,
    @Default(false) bool completed,
  }) = _HistoryEntryModel;

  factory HistoryEntryModel.fromJson(Map<String, dynamic> json) => _$HistoryEntryModelFromJson(json);
}

/// Entity conversion extension.
extension HistoryEntryModelX on HistoryEntryModel {
  HistoryEntry toEntity() => HistoryEntry(
        id: id, contentId: contentId, title: title,
        subtitle: subtitle, imageUrl: imageUrl, contentType: contentType,
        playedAt: playedAt != null ? DateTime.tryParse(playedAt!) : null,
        playedDuration: Duration(milliseconds: playedDurationMs),
        totalDuration: Duration(milliseconds: totalDurationMs),
        completed: completed,
      );
}

/// Convert entity to model.
extension HistoryEntryEntityX on HistoryEntry {
  HistoryEntryModel toModel() => HistoryEntryModel(
        id: id, contentId: contentId, title: title,
        subtitle: subtitle, imageUrl: imageUrl, contentType: contentType,
        playedAt: playedAt?.toIso8601String(),
        playedDurationMs: playedDuration.inMilliseconds,
        totalDurationMs: totalDuration.inMilliseconds,
        completed: completed,
      );
}
