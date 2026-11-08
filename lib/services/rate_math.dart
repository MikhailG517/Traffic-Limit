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

class AdapterCounters {
  const AdapterCounters(this.received, this.sent);
  final int received;
  final int sent;
}

class CounterDelta {
  const CounterDelta(this.received, this.sent);
  final int received;
  final int sent;
}

/// Bytes moved between two snapshots of per-adapter counters.
///
/// An adapter that appears between snapshots only sets a baseline: its
/// counters hold everything since boot, and summing them would book gigabytes
/// that were transferred before. A counter that went backwards was reset (the
/// adapter was re-enabled), so its current value is the traffic since reset.
CounterDelta counterDelta(Map<String, AdapterCounters> previous,
    Map<String, AdapterCounters> current) {
  var received = 0;
  var sent = 0;
  current.forEach((name, now) {
    final before = previous[name];
    if (before == null) return;
    received += now.received >= before.received
        ? now.received - before.received
        : now.received;
    sent += now.sent >= before.sent ? now.sent - before.sent : now.sent;
  });
  return CounterDelta(received, sent);
}

/// Parses `name|received|sent` lines; the adapter name may itself contain `|`.
Map<String, AdapterCounters> parseAdapterCounters(String output) {
  final result = <String, AdapterCounters>{};
  for (final line in output.split(RegExp(r'\r?\n'))) {
    final fields = line.trim().split('|');
    if (fields.length < 3) continue;
    final received = int.tryParse(fields[fields.length - 2]);
    final sent = int.tryParse(fields[fields.length - 1]);
    if (received == null || sent == null) continue;
    result[fields.sublist(0, fields.length - 2).join('|')] =
        AdapterCounters(received, sent);
  }
  return result;
}
