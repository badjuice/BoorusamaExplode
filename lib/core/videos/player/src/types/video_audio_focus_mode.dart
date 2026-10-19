/// What a playing video does when another app or a call takes the audio.
enum VideoAudioFocusMode {
  muteWhileInterrupted,
  pauseAndResume,
  mixWithOthers;

  factory VideoAudioFocusMode.parse(dynamic value) => switch (value) {
    'muteWhileInterrupted' || '0' || 0 => muteWhileInterrupted,
    'pauseAndResume' || '1' || 1 => pauseAndResume,
    'mixWithOthers' || '2' || 2 => mixWithOthers,
    _ => defaultValue,
  };

  static const VideoAudioFocusMode defaultValue = muteWhileInterrupted;

  /// When false the player itself requests audio focus and pauses on loss.
  bool get playerMixesWithOthers => this != pauseAndResume;

  dynamic toData() => index;
}
