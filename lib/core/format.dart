const _suffixes = ['', 'K', 'M', 'B', 'T', 'aa', 'ab', 'ac', 'ad', 'ae', 'af', 'ag', 'ah'];

/// Formata números grandes no estilo idle: 1.25K, 3.4M, 12B...
String fmt(num value) {
  double v = value.toDouble();
  if (v.isNaN || v.isInfinite) return '0';
  final neg = v < 0;
  v = v.abs();
  if (v < 1000) return '${neg ? '-' : ''}${v.floor()}';
  int i = 0;
  while (v >= 1000 && i < _suffixes.length - 1) {
    v /= 1000;
    i++;
  }
  final s = v >= 100
      ? v.toStringAsFixed(0)
      : v >= 10
          ? v.toStringAsFixed(1)
          : v.toStringAsFixed(2);
  return '${neg ? '-' : ''}$s${_suffixes[i]}';
}

String fmtTime(double seconds) {
  final s = seconds.round();
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  if (m < 60) return '${m}m ${s % 60}s';
  final h = m ~/ 60;
  return '${h}h ${m % 60}m';
}
