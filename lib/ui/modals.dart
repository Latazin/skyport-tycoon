import 'package:flutter/material.dart';

import '../core/format.dart';
import 'kit.dart';

/// Janela central genérica (título, conteúdo e botões).
class GameModal extends StatelessWidget {
  final String title;
  final String? icon;
  final Widget child;
  final List<Widget> actions;
  final Color color;
  const GameModal({super.key, required this.title, this.icon, required this.child, this.actions = const [], this.color = K.blue});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1), duration: const Duration(milliseconds: 380), curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 30)]),
          padding: const EdgeInsets.all(3.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: Material(
              color: K.cream,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.25)!, color]), border: const Border(bottom: BorderSide(color: K.navy, width: 3.5))),
                  child: Text(title, textAlign: TextAlign.center, style: display(26)),
                ),
                Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Ico(icon!, size: 84)),
                  child,
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 16), child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: actions)),
              ]),
            ),
          ),
        ),
      );
}

class OfflineModal extends StatelessWidget {
  final double secs, amount;
  final int gems;
  final void Function(bool triple) onClaim;
  const OfflineModal({super.key, required this.secs, required this.amount, required this.gems, required this.onClaim});
  @override
  Widget build(BuildContext context) => GameModal(
        title: 'Bem-vindo de volta!', icon: 'cash', color: K.green,
        actions: [
          GBtn(color: K.blue, onTap: () => onClaim(false), child: Text('PEGAR', style: display(18))),
          GBtn(color: K.purple, enabled: gems >= 15, onTap: () => onClaim(true), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('PEGAR x3  ', style: display(18)), const Price('15', icon: 'gem', size: 16)])),
        ],
        child: Column(children: [
          Text('Seu aeroporto operou por ${fmtTime(secs)} enquanto você estava fora e faturou:', textAlign: TextAlign.center, style: body(15)),
          const SizedBox(height: 8),
          Price('\$${fmt(amount)}', size: 30),
        ]),
      );
}
