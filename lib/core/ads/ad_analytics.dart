// ═════════════════════════════════════════════════════════════════════════
// V Shots — Ad Analytics
//
// Centralized ad event logging. The app has no external analytics SDK
// (by design — no new data collectors added), so events are:
//   - kept in a bounded in-memory session list (debugging + future export)
//   - printed via debugPrint (stripped from release builds)
//   - optionally forwarded to a pluggable [AdAnalyticsSink] so a future
//     backend (e.g. a Supabase ad_events table) can be wired with ONE line
//     and zero placement changes.
//
// Event vocabulary (fixed, spec-aligned):
//   ad_request · ad_loaded · ad_load_failed · ad_impression · ad_closed
//   rewarded_started · rewarded_completed · interstitial_shown · native_rendered
//
// No personal data is collected — placement + outcome only.
// ═════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// One recorded ad event.
class AdEvent {
  const AdEvent({
    required this.kind,
    required this.at,
    this.placement,
    this.detail,
  });

  /// Event kind — one of the fixed vocabulary values above.
  final String kind;

  final DateTime at;

  /// Where it happened (e.g. 'home', 'for_you_feed', 'search', 'playlist',
  /// 'library', 'player', 'tab_switch') or null for app-level events.
  final String? placement;

  /// Free-form, non-PII detail (e.g. error message, unit kind).
  final String? detail;

  @override
  String toString() {
    final buf = StringBuffer('AdEvent($kind');
    if (placement != null) buf.write(', $placement');
    if (detail != null) buf.write(', $detail');
    buf.write(', $at)');
    return buf.toString();
  }
}

/// Pluggable forwarder for ad events (future backend hook).
typedef AdAnalyticsSink = void Function(AdEvent event);

/// Static centralized logger (call `AdAnalytics.log(...)` from anywhere).
class AdAnalytics {
  AdAnalytics._();

  /// Optional external forwarder. Set once during startup if a backend is
  /// configured; placements never change.
  static AdAnalyticsSink? sink;

  /// Bounded in-memory session list (drop the oldest beyond the cap).
  static final List<AdEvent> session = [];

  static const int _maxEvents = 500;

  /// Records an event. Never throws, never blocks.
  static void log(String kind, {String? placement, String? detail}) {
    final event = AdEvent(
      kind: kind,
      at: DateTime.now(),
      placement: placement,
      detail: detail,
    );
    session.add(event);
    if (session.length > _maxEvents) {
      session.removeAt(0);
    }
    final s = sink;
    if (s != null) {
      try {
        s(event);
      } catch (e) {
        debugPrint('[AdAnalytics] sink error: $e');
      }
    }
    if (kDebugMode) {
      debugPrint(
          '[AdAnalytics] $kind${placement != null ? ' @ $placement' : ''}'
          '${detail != null ? ' — $detail' : ''}');
    }
  }

  /// Number of events of [kind] this session (diagnostics/tests).
  static int countOf(String kind) =>
      session.where((e) => e.kind == kind).length;

  /// Test helper.
  @visibleForTesting
  static void clear() {
    session.clear();
  }
}
