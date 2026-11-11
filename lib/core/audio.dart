import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

/// Sons, música e vibração.
class Sfx {
  static bool music = true, sound = true, vibration = true;
  static bool _ready = false;
  static final Map<String, int> _last = {};
  static const names = ['click', 'coin', 'cash', 'build', 'up', 'alert', 'level', 'nope', 'gift', 'pop', 'boost', 'whoosh', 'tick', 'ding', 'jet'];
  static final Map<String, AudioPool> _pools = {};

  static Future<void> init() async {
    try {
      await FlameAudio.audioCache.loadAll([...names.map((n) => '$n.wav'), 'music.wav']);
      FlameAudio.bgm.initialize();
      for (final n in names) {
        try { _pools[n] = await FlameAudio.createPool('$n.wav', minPlayers: 1, maxPlayers: n == 'coin' || n == 'up' || n == 'click' || n == 'tick' ? 3 : 2); } catch (_) {}
      }
      _ready = true;
    } catch (_) { _ready = false; }
  }

  static void play(String name, {double volume = 0.6, double rate = 1}) {
    if (!sound || !_ready) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[name] ?? 0) < 80) return;
    _last[name] = now;
    final pool = _pools[name]; if (pool == null) return;
    pool.start(volume: (volume * (0.85 + 0.15 * rate.clamp(0.5, 2.0))).clamp(0.0, 1.0)).catchError((_) => () async {});
  }

  static void startMusic() { if (!music || !_ready) return; try { FlameAudio.bgm.play('music.wav', volume: 0.25); } catch (_) {} }
  static void stopMusic() { try { FlameAudio.bgm.stop(); } catch (_) {} }
  static void pauseMusic() { try { FlameAudio.bgm.pause(); } catch (_) {} }
  static void resumeMusic() { if (!music) return; try { FlameAudio.bgm.resume(); } catch (_) {} }
  static void click() { play('click', volume: 0.45); haptic(); }
  static void haptic([int ms = 10]) { if (!vibration) return; ms > 25 ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact(); }
}
