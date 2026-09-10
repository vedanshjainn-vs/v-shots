import 'dart:convert';
import 'dart:isolate';

/// JSON decoding helper with main-isolate protection.
///
/// Network responses (InnerTube, YouTube Data API) regularly land in the
/// 50–500 KB range; decoding those on the UI isolate costs 5–20 ms+ per
/// call and shows up as scroll jank in the feeds. Payloads at or above
/// [threshold] are decoded on a background isolate; smaller ones decode
/// inline (the isolate hop costs more than the decode itself).
///
/// Output is byte-identical to [jsonDecode] — this is purely a
/// jank-avoidance wrapper with no behavior change.
Future<dynamic> decodeJsonMaybeOffThread(
  String source, {
  int threshold = 24 * 1024,
}) async {
  if (source.length < threshold) {
    return jsonDecode(source);
  }
  return Isolate.run(() => jsonDecode(source));
}
