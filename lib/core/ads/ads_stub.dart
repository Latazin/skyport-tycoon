/// Versão web / sem SDK: não há anúncio de verdade.
class AdsImpl {
  static Future<void> init() async {}
  static bool get ready => false;
  static bool get supported => false;
  static Future<bool> show() async => false;
}
