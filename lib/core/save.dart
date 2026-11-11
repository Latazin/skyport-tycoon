import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'state.dart';

/// Salvamento local com cópia de segurança.
class Save {
  static const _main = 'skyport_save_v1', _backup = 'skyport_save_v1_bak';
  static int _n = 0;
  static bool _wiped = false;

  static Future<GameState> load() async {
    final s = GameState();
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in [_main, _backup]) {
        final raw = p.getString(k); if (raw == null) continue;
        try { s.loadJson(jsonDecode(raw) as Map<String, dynamic>); return s; } catch (_) {}
      }
    } catch (_) {}
    s.estimate();
    return s;
  }

  static Future<void> save(GameState s) async {
    if (_wiped) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonEncode(s.toJson());
      await p.setString(_main, raw);
      if (_n++ % 4 == 0) await p.setString(_backup, raw);
    } catch (_) {}
  }

  static Future<void> wipe() async {
    _wiped = true;
    final p = await SharedPreferences.getInstance();
    await p.remove(_main); await p.remove(_backup);
  }
}
