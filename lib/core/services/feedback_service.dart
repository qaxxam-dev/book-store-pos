import 'package:audioplayers/audioplayers.dart';
import '../utils/force_haptic.dart';

enum FeedbackType {
  vibrate,
  beep,
  none,
}

class FeedbackService {
  static final AudioPlayer _player = AudioPlayer();

  // This could be moved to a provider if we want reactive updates to the setting,
  // but for a static service call, we might pass the type or manage it via a singleton with initialization.
  // For simplicity given the requirement "Settings Screen... selector... Logic",
  // we will accept the type as a parameter or check the preference.

  static Future<void> trigger(FeedbackType type) async {
    try {
      switch (type) {
        case FeedbackType.vibrate:
          await ForceHaptic.click();
          break;
        case FeedbackType.beep:
          // Re-create player or seek to 0 to allow rapid replays?
          // AudioPlayer handles overlap depending on mode, but simplest is stop then play for short beeps
          await _player.stop();
          await _player.setSource(AssetSource(
              'audio/beep.mp3')); // Using .mp3 as primary, fallback logic handled by audioplayers usually
          await _player.resume();
          break;
        case FeedbackType.none:
          break;
      }
    } catch (e) {
      print('Feedback error: $e');
    }
  }
}
