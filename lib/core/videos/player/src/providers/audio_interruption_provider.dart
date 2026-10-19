// Dart imports:
import 'dart:async';

// Package imports:
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../foundation/platform.dart';

/// True while a call or another app holds the audio, so videos playing in
/// "mute while interrupted" mode should be silent.
final videoAudioInterruptedProvider =
    NotifierProvider<VideoAudioInterruptionNotifier, bool>(
      VideoAudioInterruptionNotifier.new,
    );

class VideoAudioInterruptionNotifier extends Notifier<bool> {
  StreamSubscription<AudioInterruptionEvent>? _subscription;
  AudioSession? _session;

  @override
  bool build() {
    ref.onDispose(() => _subscription?.cancel());
    return false;
  }

  /// Requests audio focus so interruptions are reported. Called when a video
  /// starts with sound; safe to call repeatedly.
  Future<void> acquireFocus() async {
    if (!ref.read(appPlatformProvider).isAndroid) return;

    try {
      final session = _session ??= await _configure();
      await session.setActive(true);
      state = false;
    } catch (_) {
      // Focus handling is best effort; playback works without it.
    }
  }

  Future<AudioSession> _configure() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.movie,
          usage: AndroidAudioUsage.media,
        ),
        androidWillPauseWhenDucked: false,
      ),
    );

    _subscription = session.interruptionEventStream.listen((event) {
      state = switch (event) {
        // A short notification sound can play over the video.
        AudioInterruptionEvent(type: AudioInterruptionType.duck) => false,
        AudioInterruptionEvent(:final begin) => begin,
      };
    });

    return session;
  }
}
