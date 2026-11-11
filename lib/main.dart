import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio.dart';
import 'core/data.dart';
import 'core/save.dart';
import 'core/state.dart';
import 'game/art.dart';
import 'ui/game_screen.dart';
import 'ui/kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SkyPortApp());
}

class SkyPortApp extends StatelessWidget {
  const SkyPortApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SkyPort Tycoon',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'Fredoka', colorScheme: ColorScheme.fromSeed(seedColor: K.blue)),
        home: const TitleScreen(),
      );
}

/// Abertura: carrega a arte, mostra o logo e o botão JOGAR.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with TickerProviderStateMixin {
  double progress = 0;
  GameState? s;
  double offline = 0;
  String? panel0;
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  late final AnimationController clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final AnimationController intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { a.dispose(); clock.dispose(); intro.dispose(); super.dispose(); }

  Future<void> _load() async {
    final st = await Save.load();
    offline = st.ls > 0 ? (nowMs() - st.ls) / 1000 : 0;
    Sfx.music = st.music; Sfx.sound = st.sound; Sfx.vibration = st.vibration;
    await Art.load((k) { if (mounted) setState(() => progress = k); });
    await Art.loadBg(cityAt(st.city).bg);
    await Sfx.init();
    final q = Uri.base.queryParameters;
    if (q['demo'] == '1') {
      st..money = 2e9..gems = 120..tut = 5..flightsAll = 300..flightsCity = 300..mission = 18..earnedCity = 1.2e9;
      const lv = {'entrada': 80, 'checkin': 76, 'seguranca': 70, 'g0': 82, 'g1': 64, 'g2': 40, 'g3': 26, 'g4': 0, 'g5': 0, 'lojas': 62, 'pista': 45, 'torre': 40, 'vip': 30, 'hangar': 1, 'combustivel': 0};
      st.lv.addAll(lv);
      st.mgr.addAll(['ana', 'bruno', 'carla', 'diego']);
      st.estimate();
    }
    if (q['tut'] != null) st.tut = int.parse(q['tut']!);
    if (mounted) setState(() => s = st);
    panel0 = q['panel'];
    if (q['auto'] == '1') _play();
  }

  void _play() {
    Sfx.play('ding'); if (s!.tut > 0) Sfx.startMusic();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => GameScreen(s: s!, offlineSecs: offline, startPanel: panel0),
      transitionsBuilder: (_, an, __, c) => FadeTransition(opacity: an, child: c),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF1E5AD8),
        body: AnimatedBuilder(
          animation: Listenable.merge([clock, a, intro]),
          builder: (_, __) {
            final t = clock.value * 60, k = intro.value;
            double el(double from, double to) => Curves.elasticOut.transform(((k - from) / (to - from)).clamp(0.0, 1.0));
            double ease(double from, double to) => Curves.easeOutCubic.transform(((k - from) / (to - from)).clamp(0.0, 1.0));
            return Stack(children: [
              Positioned.fill(child: Transform.scale(scale: 1.05 + 0.04 * math.sin(t * 0.12), child: Image.asset('assets/images/keyart.jpg', fit: BoxFit.cover, filterQuality: FilterQuality.medium))),
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [const Color(0xE6103A8A), const Color(0x88103A8A), const Color(0x00103A8A), const Color(0x00103A8A), const Color(0xE60B1A3E)], stops: const [0, 0.26, 0.42, 0.62, 1])))),
              Align(alignment: const Alignment(0, -0.66), child: Opacity(opacity: ease(0, 0.3), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.translate(offset: Offset(-40 + ease(0, 0.8) * 40, -a.value * 6), child: Transform.scale(scale: el(0.05, 0.6), child: const Ico('plane', size: 110))),
                Transform.scale(scale: el(0.12, 0.65), child: Text('SKYPORT', style: display(62))),
                Transform.scale(scale: el(0.2, 0.75), child: Stack(children: [
                  Text('TYCOON', style: display(70)),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF4B0), Color(0xFFFFC531), Color(0xFFFF8F00)]).createShader(r),
                    blendMode: BlendMode.srcIn,
                    child: Text('TYCOON', style: display(70, outline: false)),
                  ),
                ])),
                const SizedBox(height: 6),
                Transform.scale(scale: el(0.3, 0.85), child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF2F7BFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2.5)),
                  child: Text('AEROPORTO IDLE', style: display(18)),
                )),
              ]))),
              Align(alignment: const Alignment(0, 0.8), child: s == null
                  ? SizedBox(width: 240, child: Column(mainAxisSize: MainAxisSize.min, children: [GBar(value: progress, height: 18, color: K.gold), const SizedBox(height: 8), Text('Preparando a pista... ${(progress * 100).round()}%', style: body(14, color: Colors.white))]))
                  : Transform.scale(scale: (1 + a.value * 0.05) * el(0.45, 1), child: GBtn(color: K.green, onTap: _play, padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 16), child: Text('JOGAR', style: display(36))))),
              Positioned(bottom: 10, left: 0, right: 0, child: Text('v1.0', textAlign: TextAlign.center, style: body(11, color: Colors.white38))),
            ]);
          },
        ),
      );
}
