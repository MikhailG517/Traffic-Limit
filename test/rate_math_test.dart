import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/services/rate_math.dart';

void main() {
  test('calculates kbit per second from byte delta and interval', () {
    expect(
        rateKbit(
            currentBytes: 125000,
            previousBytes: 0,
            elapsed: const Duration(seconds: 1)),
        1000);
    expect(
        rateKbit(
            currentBytes: 250000,
            previousBytes: 0,
            elapsed: const Duration(seconds: 2)),
        1000);
  });

  test('handles no traffic and counter resets as zero', () {
    expect(
        rateKbit(
            currentBytes: 40,
            previousBytes: 40,
            elapsed: const Duration(seconds: 1)),
        0);
    expect(
        rateKbit(
            currentBytes: 10,
            previousBytes: 40,
            elapsed: const Duration(seconds: 1)),
        0);
  });

  test('uses a 250 millisecond floor and caps invalid display spikes', () {
    expect(
        rateKbit(
            currentBytes: 31250,
            previousBytes: 0,
            elapsed: const Duration(milliseconds: 10)),
        1000);
    expect(
        rateKbit(
            currentBytes: 1000000000,
            previousBytes: 0,
            elapsed: const Duration(seconds: 1)),
        maxDisplayRateKbit);
  });
}
