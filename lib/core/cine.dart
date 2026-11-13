/// Modo "filmagem" (só na build web, via parâmetros da URL): esconde a interface
/// e move a câmera de um ponto a outro. Usado para gravar vídeos de divulgação.
class Cine {
  static bool clean = false;
  static List<double>? a, b; // x, z, zoom
  static double dur = 6;
  static List<double>? parse(String? v) => v == null ? null : v.split(',').map(double.parse).toList();
}
