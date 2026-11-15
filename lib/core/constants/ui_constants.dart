/// Display settings of the dashboard and charts (not health thresholds —
/// those live in thresholds.dart).
class UiConstants {
  UiConstants._();

  // --- Dashboard ---------------------------------------------------------------

  /// Sparklines on the vital cards show the same 12 readings the engine uses.
  static const int sparklineReadings = 12;

  /// Height of the small sparkline chart inside a vital card.
  static const double sparklineHeight = 36;

  /// Diameter of the risk gauge.
  static const double gaugeSize = 200;

  /// Thickness of the gauge arc.
  static const double gaugeStroke = 14;

  /// The gauge needle moves smoothly to a new score instead of jumping.
  static const Duration gaugeAnimation = Duration(milliseconds: 900);

  // --- Trend arrows on the vital cards ----------------------------------------
  // The arrow shows the direction of the NUMBER over the last 12 readings
  // (first 3 vs last 3 average). Changes smaller than these "dead bands" are
  // shown as flat, so normal sensor noise does not make the arrow flicker.
  static const double trendBandHeartRate = 2; // bpm
  static const double trendBandHrv = 2; // ms
  static const double trendBandSpo2 = 0.6; // %
  static const double trendBandTemperature = 0.1; // °C
  static const double trendBandActivity = 0.5; // levels (0 low … 2 high)

  /// Readings averaged at each end of the window to decide the trend.
  static const int trendEdgeReadings = 3;

  // --- Vitals charts ------------------------------------------------------------

  /// Height of one chart on the Vitals tab.
  static const double chartHeight = 150;

  /// Short animation when a new reading arrives: the line slides instead of
  /// jumping (no flicker).
  static const Duration chartAnimation = Duration(milliseconds: 300);

  /// Empty space above / below the data so lines never touch the edges
  /// (fraction of the visible value range).
  static const double chartPaddingFraction = 0.12;

  /// Minimum visible value range per vital, so a flat line is not zoomed in
  /// until noise looks like a big swing.
  static const double minSpanHeartRate = 20;
  static const double minSpanHrv = 20;
  static const double minSpanSpo2 = 6;
  static const double minSpanTemperature = 1.0;

  /// Range options of the Vitals tab. null = whole session.
  static const Duration range2Min = Duration(minutes: 2);
  static const Duration range10Min = Duration(minutes: 10);
}
