// ════════════════════════════════════════════════
// Project Lyra — Test Data Builders
// ════════════════════════════════════════════════
//
// Builder pattern for creating test data.
// Provides sensible defaults, easily overridden.
// ════════════════════════════════════════════════

import 'package:project_lyra/core/downloads/download_status.dart';
import 'package:project_lyra/core/downloads/download_task.dart';
import 'package:project_lyra/core/events/types/app_event.dart';
import 'package:project_lyra/core/sync/queue/sync_operation.dart';

/// Builder for creating [DownloadTask] instances in tests.
class DownloadTaskBuilder {
  String _id = 'test_download_1';
  String _url = 'https://example.com/track.mp3';
  DownloadType _type = DownloadType.track;
  String _title = 'Test Track';
  DownloadStatus _status = DownloadStatus.queued;
  DownloadPriority _priority = DownloadPriority.normal;
  double _progress = 0.0;

  DownloadTaskBuilder withId(String id) { _id = id; return this; }
  DownloadTaskBuilder withUrl(String url) { _url = url; return this; }
  DownloadTaskBuilder withTitle(String title) { _title = title; return this; }
  DownloadTaskBuilder withStatus(DownloadStatus status) { _status = status; return this; }
  DownloadTaskBuilder withPriority(DownloadPriority priority) { _priority = priority; return this; }
  DownloadTaskBuilder withProgress(double progress) { _progress = progress; return this; }

  DownloadTask build() => DownloadTask(
    id: _id,
    url: _url,
    type: _type,
    title: _title,
    status: _status,
    priority: _priority,
    progress: _progress,
    createdAt: DateTime.now(),
  );
}

/// Builder for creating [SyncOperation] instances in tests.
class SyncOperationBuilder {
  String _id = 'test_sync_1';
  SyncOperationType _type = SyncOperationType.like;
  String _entityType = 'track';
  String _entityId = 'track_123';

  SyncOperationBuilder withId(String id) { _id = id; return this; }
  SyncOperationBuilder withType(SyncOperationType type) { _type = type; return this; }
  SyncOperationBuilder withEntityType(String type) { _entityType = type; return this; }
  SyncOperationBuilder withEntityId(String id) { _entityId = id; return this; }

  SyncOperation build() => SyncOperation(
    id: _id,
    type: _type,
    entityType: _entityType,
    entityId: _entityId,
    createdAt: DateTime.now(),
  );
}

/// Builder for creating [TrackPlayedEvent] instances in tests.
class TrackEventBuilder {
  String _trackId = 'track_123';
  String _title = 'Test Track';
  String? _artist = 'Test Artist';
  String? _source = 'home';

  TrackEventBuilder withTrackId(String id) { _trackId = id; return this; }
  TrackEventBuilder withTitle(String title) { _title = title; return this; }
  TrackEventBuilder withArtist(String? artist) { _artist = artist; return this; }
  TrackEventBuilder withSource(String? source) { _source = source; return this; }

  TrackPlayedEvent build() => TrackPlayedEvent(
    trackId: _trackId,
    title: _title,
    artist: _artist,
    source: _source,
  );
}
