import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traffic_limit/models/traffic_models.dart';
import 'package:traffic_limit/services/logger_service.dart';
import 'package:traffic_limit/services/rate_math.dart';
import 'package:traffic_limit/services/settings_service.dart';
import 'package:traffic_limit/services/traffic_service.dart';

const mb = 1024 * 1024;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TrafficService> service(
      Map<String, Object> prefs, DateTime now) async {
    SharedPreferences.setMockInitialValues(prefs);
    final result =
        TrafficService(LoggerService(), await SharedPreferences.getInstance())
          ..clock = () => now;
    await result.start(() {});
    return result;
  }

  test('legacy daily totals are imported and the session starts at zero',
      () async {
    final now = DateTime(2026, 11, 8, 12);
    final s = await service({
      'trafficDataVersion': 3,
      'dailyTotals': '{"2026-11-08": 12.5, "2026-11-07": 3.0}',
      'sessionDownload': 900.0,
    }, now);
    expect(s.stats.downloadTotal, 0);
    expect(s.today.total, 12.5);
    expect(s.yesterday.total, 3.0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('sessionDownload'), isFalse);
    expect(prefs.containsKey('dailyTotals'), isFalse);
    await s.dispose();
  });

  test('first reading is only a baseline, later deltas are booked', () async {
    final now = DateTime(2026, 11, 8, 12);
    final s = await service({}, now);
    s.recordCounters(
        {'eth': const AdapterCounters(50000 * mb, 9000 * mb)}, now);
    expect(s.today.total, 0, reason: 'bytes since boot must not be booked');
    s.recordCounters({'eth': const AdapterCounters(50010 * mb, 9002 * mb)},
        now.add(const Duration(seconds: 2)));
    expect(s.today.download, closeTo(10, 1e-9));
    expect(s.today.upload, closeTo(2, 1e-9));
    expect(s.stats.downloadTotal, 0, reason: 'stats refresh in _sample');
    await s.dispose();
  });

  test('an adapter that comes up later does not inflate today', () async {
    final now = DateTime(2026, 11, 8, 12);
    final s = await service({}, now);
    s.recordCounters({'eth': const AdapterCounters(100 * mb, 10 * mb)}, now);
    s.recordCounters({
      'eth': const AdapterCounters(101 * mb, 10 * mb),
      'wifi': const AdapterCounters(80000 * mb, 7000 * mb),
    }, now.add(const Duration(seconds: 2)));
    expect(s.today.total, closeTo(1, 1e-9));
    await s.dispose();
  });

  test('ledger survives restart in the new format', () async {
    final now = DateTime(2026, 11, 8, 12);
    final s = await service({}, now);
    s.recordCounters({'eth': const AdapterCounters(0, 0)}, now);
    s.recordCounters({'eth': const AdapterCounters(5 * mb, 1 * mb)},
        now.add(const Duration(seconds: 2)));
    await s.dispose();
    final prefs = await SharedPreferences.getInstance();
    final restored = TrafficService(LoggerService(), prefs)..clock = () => now;
    await restored.start(() {});
    expect(restored.today.download, closeTo(5, 1e-9));
    expect(restored.ledger.hour(now).upload, closeTo(1, 1e-9));
    await restored.dispose();
  });

  test('settings survive reload including autostart and limits', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsService(preferences);
    const value = AppSettings(
        autostart: true,
        limitsEnabled: true,
        downloadLimit: 25,
        uploadLimit: 12);
    await settings.save(value);
    final restored = settings.load();
    expect(restored.autostart, isTrue);
    expect(restored.limitsEnabled, isTrue);
    expect(restored.downloadLimit, 25);
    expect(restored.uploadLimit, 12);
  });

  test('traffic peak follows the largest selected direction sample', () {
    final samples = <TrafficSample>[
      TrafficSample(time: DateTime.now(), download: 30, upload: 12),
      TrafficSample(time: DateTime.now(), download: 80, upload: 140),
    ];
    expect(TrafficService.peakFromSamples(samples, download: true), 80);
    expect(TrafficService.peakFromSamples(samples, download: false), 140);
  });
}
