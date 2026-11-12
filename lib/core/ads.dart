import 'ads/ads_config.dart';
import 'ads/ads_stub.dart' if (dart.library.io) 'ads/ads_mobile.dart';

/// Porta única para anúncios premiados. No navegador (prévia e iPhone pelo
/// artefato) não existe SDK, então a recompensa é liberada como demonstração.
class Ads {
  static Future<void> init() async { if (AdsConfig.enabled) await AdsImpl.init(); }
  /// Existe SDK de anúncio nesta plataforma?
  static bool get real => AdsConfig.enabled && AdsImpl.supported;
  static bool get ready => AdsImpl.ready;
  /// Resultado: 'ok' (ganhou), 'demo' (sem SDK: liberado para teste), 'none' (sem anúncio agora), 'skip' (fechou antes).
  static Future<String> show() async {
    if (!real) return 'demo';
    if (!AdsImpl.ready) { AdsImpl.show(); return 'none'; }
    return await AdsImpl.show() ? 'ok' : 'skip';
  }
}
