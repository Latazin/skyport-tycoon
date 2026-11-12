import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Anúncios premiados do AdMob (Android e iOS).
class AdsImpl {
  static RewardedAd? _ad;
  static bool _loading = false, _ok = false;
  static int _fails = 0;
  static bool get supported => _ok;
  static bool get ready => _ad != null;
  static String get _unit => Platform.isIOS ? AdsConfig.rewardedIos : AdsConfig.rewardedAndroid;

  static Future<void> init() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try { await MobileAds.instance.initialize(); _ok = true; _load(); } catch (_) {}
  }

  static void _load() {
    if (!_ok || _loading || _ad != null) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _ad = ad; _loading = false; _fails = 0; },
        onAdFailedToLoad: (_) { _loading = false; _fails++; Timer(Duration(seconds: _fails > 4 ? 120 : 15 * _fails), _load); },
      ),
    );
  }

  /// Mostra o anúncio; devolve true se a pessoa assistiu até ganhar a recompensa.
  static Future<bool> show() async {
    final ad = _ad;
    if (ad == null) { _load(); return false; }
    _ad = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) { a.dispose(); _load(); if (!done.isCompleted) done.complete(earned); },
      onAdFailedToShowFullScreenContent: (a, _) { a.dispose(); _load(); if (!done.isCompleted) done.complete(false); },
    );
    try { await ad.show(onUserEarnedReward: (_, __) { earned = true; }); } catch (_) { if (!done.isCompleted) done.complete(false); }
    return done.future;
  }
}
