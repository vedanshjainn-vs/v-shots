package com.vshots.live

// Extends AudioServiceActivity (instead of plain FlutterActivity) so
// audio_service can share this app's FlutterEngine for background
// playback — see https://pub.dev/packages/audio_service "Custom Android
// activity" setup docs, and lib/core/audio/vshots_audio_handler.dart
// for why background playback was added.
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity()
