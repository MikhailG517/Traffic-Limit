import 'dart:math';

const maxDisplayRateKbit = 500000.0;

double rateKbit({
  required int currentBytes,
  required int previousBytes,
  required Duration elapsed,
}) {
  if (currentBytes <= previousBytes || elapsed.inMicroseconds <= 0) return 0;
  final seconds =
      max(0.25, elapsed.inMicroseconds / Duration.microsecondsPerSecond);
  return min(maxDisplayRateKbit,
          (currentBytes - previousBytes) * 8 / seconds / 1000)
      .toDouble();
}
