import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traffic_limit/services/logger_service.dart';
import 'package:traffic_limit/services/settings_service.dart';
import 'package:traffic_limit/services/traffic_service.dart';
import 'package:traffic_limit/models/traffic_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new monitoring session starts at zero while daily totals persist',
      () async {
    final now = DateTime.now();
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'trafficDataVersion': 3,
      'dailyTotals': '{"$dayKey": 12.5}',
      'sessionDownload': 900.0,
      'sessionUpload': 300.0,
    });
    final preferences = await SharedPreferences.getInstance();
    final service = TrafficService(LoggerService(), preferences);

    await service.start(() {});

    expect(service.stats.downloadTotal, 0);
    expect(service.stats.uploadTotal, 0);
    expect(service.todayTotal, 12.5);
    expect(preferences.containsKey('sessionDownload'), isFalse);
    expect(preferences.containsKey('sessionUpload'), isFalse);
    service.dispose();
  });

  test('settings survive reload including autostart and limits', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = SettingsService(preferences);
    const value = AppSettings(
      autostart: true,
      limitsEnabled: true,
      downloadLimit: 25,
      uploadLimit: 12,
    );

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
