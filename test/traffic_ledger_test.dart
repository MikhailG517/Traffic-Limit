import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/models/traffic_models.dart';
import 'package:traffic_limit/services/rate_math.dart';
import 'package:traffic_limit/widgets/traffic_charts.dart';

void main() {
  // Sunday, 8 November 2026.
  final now = DateTime(2026, 11, 8, 14, 30);

  TrafficLedger filled() => TrafficLedger()
    ..add(DateTime(2026, 11, 8, 0, 5), download: 10, upload: 1)
    ..add(DateTime(2026, 11, 8, 14, 1), download: 5, upload: 2)
    ..add(DateTime(2026, 11, 7, 23, 59), download: 7, upload: 0)
    ..add(DateTime(2026, 11, 2, 9), download: 3, upload: 3)
    ..add(DateTime(2026, 11, 1, 9), download: 100, upload: 0)
    ..add(DateTime(2026, 10, 31, 9), download: 1000, upload: 0);

  test('today and yesterday split at local midnight', () {
    final l = filled();
    expect(l.today(now).total, 18);
    expect(l.yesterday(now).total, 7);
  });

  test('week starts on Monday and month on the 1st', () {
    final l = filled();
    expect(TrafficLedger.startOfWeek(now), DateTime(2026, 11, 2));
    expect(l.week(now).total, 18 + 7 + 6);
    expect(l.month(now).total, 18 + 7 + 6 + 100);
  });

  test('on Monday the week holds only Monday', () {
    final monday = DateTime(2026, 11, 2, 10);
    expect(filled().week(monday).total, 6);
  });

  test('hourly, weekly, monthly and yearly buckets', () {
    final l = filled();
    final hours = l.hoursOf(now);
    expect(hours.length, 24);
    expect(hours[0].usage.total, 11);
    expect(hours[14].usage.total, 7);
    final week = l.daysOfWeek(now);
    expect(week.length, 7);
    expect(week.first.start, DateTime(2026, 11, 2));
    expect(week.last.usage.total, 18);
    expect(l.daysOfMonth(now).length, 30);
    final year = l.monthsOfYear(now);
    expect(year[9].usage.total, 1000);
    expect(year[10].usage.total, 131);
    expect(year[11].usage.total, 0);
  });

  test('prune drops old hours but keeps days', () {
    final l = filled()..prune(DateTime(2026, 11, 20));
    expect(l.hour(DateTime(2026, 11, 8, 14)).total, 0);
    expect(l.day(DateTime(2026, 11, 8)).total, 18);
  });

  test('json round trip keeps direction split', () {
    final copy = TrafficLedger()..loadJson(filled().toJson());
    expect(copy.today(now).download, 15);
    expect(copy.today(now).upload, 3);
  });

  test('counter delta handles resets and parses adapter names with pipes', () {
    final parsed = parseAdapterCounters(
        'Intel(R) Ethernet|100|20\r\nVPN | A|5|x\r\nWi|Fi|7|3\n');
    expect(parsed.keys, ['Intel(R) Ethernet', 'Wi|Fi']);
    final delta = counterDelta({'a': const AdapterCounters(100, 50)},
        {'a': const AdapterCounters(30, 60)});
    expect(delta.received, 30);
    expect(delta.sent, 10);
  });

  test('downsample keeps peaks of each bucket', () {
    final from = DateTime(2026, 1, 1);
    final samples = [
      for (var i = 0; i < 600; i++)
        TrafficSample(
            time: from.add(Duration(seconds: i)),
            download: i == 301 ? 999 : 1,
            upload: 0)
    ];
    final result = downsample(samples, from, const Duration(seconds: 600), 60);
    expect(result.length, 60);
    expect(result.map((s) => s.download).reduce((a, b) => a > b ? a : b), 999);
  });

  test('niceCeil rounds to readable steps', () {
    expect(niceCeil(730), 1000);
    expect(niceCeil(1300), 2000);
    expect(niceCeil(2100), 2500);
  });
}
