/// Tiny statistics helpers used by the engine. Plain math, no packages.
library;

/// Result of fitting a straight line y = a + slope·x through some points.
class LinearFit {
  const LinearFit(this.slope, this.r2);

  /// Change of y per unit of x (for us: per minute).
  final double slope;

  /// R² in 0–1: how well the straight line explains the points.
  /// 1 = perfect line, 0 = pure noise / flat.
  final double r2;

  static const LinearFit flat = LinearFit(0, 0);
}

/// Least-squares linear regression. Returns [LinearFit.flat] when there is
/// not enough data or no spread in x.
LinearFit linearFit(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2 || ys.length != n) return LinearFit.flat;

  final meanX = mean(xs);
  final meanY = mean(ys);
  var sxx = 0.0, sxy = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    final dy = ys[i] - meanY;
    sxx += dx * dx;
    sxy += dx * dy;
    syy += dy * dy;
  }
  if (sxx == 0) return LinearFit.flat;

  final slope = sxy / sxx;
  final r2 = syy == 0 ? 0.0 : (sxy * sxy) / (sxx * syy);
  return LinearFit(slope, r2);
}

/// Average of the values (0 for an empty list).
double mean(Iterable<double> values) {
  var sum = 0.0;
  var count = 0;
  for (final v in values) {
    sum += v;
    count++;
  }
  return count == 0 ? 0 : sum / count;
}

/// Average of the last [n] values of [values].
double meanOfLast(List<double> values, int n) {
  if (values.isEmpty) return 0;
  final start = values.length > n ? values.length - n : 0;
  return mean(values.sublist(start));
}
