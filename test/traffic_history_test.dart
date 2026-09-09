import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/models/traffic_models.dart';

void main() {
  TrafficSample sample(int seconds) => TrafficSample(
        time: DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
        download: seconds.toDouble(),
        upload: seconds.toDouble() * 2,
      );

  test('keeps a bounded recent buffer and pushes older samples into history', () {
    final history = TrafficHistory(recentLimit: 10, historyLimit: 20);
    // 100 points, well beyond recentLimit + historyLimit.
    for (var i = 0; i < 100; i++) {
      history.add(sample(i));
    }
    expect(history.length, lessThanOrEqualTo(10 + 20));
    expect(history.length, greaterThan(0));
  });

  test('points are returned oldest first', () {
    final history = TrafficHistory(recentLimit: 5, historyLimit: 10);
    for (var i = 0; i < 30; i++) {
      history.add(sample(i));
    }
    final points = history.points;
    for (var i = 1; i < points.length; i++) {
      expect(points[i].time.isBefore(points[i - 1].time), isFalse);
    }
  });

  test('recent returns only the requested trailing slice', () {
    final history = TrafficHistory(recentLimit: 5, historyLimit: 20);
    for (var i = 0; i < 40; i++) {
      history.add(sample(i));
    }
    final recent = history.recent(6);
    expect(recent.length, 6);
    // The newest sample is the last one added.
    expect(recent.last.time, sample(39).time);
  });

  test('recent falls back to all points when fewer are requested', () {
    final history = TrafficHistory(recentLimit: 5, historyLimit: 20);
    for (var i = 0; i < 8; i++) {
      history.add(sample(i));
    }
    expect(history.recent(50).length, history.length);
  });

  test('after reset the history is empty', () {
    final history = TrafficHistory(recentLimit: 5, historyLimit: 20);
    for (var i = 0; i < 50; i++) {
      history.add(sample(i));
    }
    history.clear();
    expect(history.isEmpty, isTrue);
    expect(history.length, 0);
  });
}
