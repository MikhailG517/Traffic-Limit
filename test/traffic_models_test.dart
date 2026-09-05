import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/models/traffic_models.dart';

void main() {
  test('форматирует скорость с автоматическим переходом в Мбит/с', () {
    expect(formatRate(49.04), '49.0 Кбит/с');
    expect(formatRate(1250), '1.25 Мбит/с');
  });
  test('форматирует объём', () {
    expect(formatData(2048), '2.0 ГБ');
  });
  test('copyWith сохраняет значения', () {
    const stats = TrafficStats(downloadRate: 10, uploadRate: 20);
    expect(stats.copyWith(downloadRate: 30).uploadRate, 20);
  });
  test('процесс хранит независимые скорости входящего и исходящего', () {
    const process = ProcessTraffic(
        name: 'app.exe', pid: 123, connections: 1, download: 2500, upload: 500);
    expect(process.download, 2500);
    expect(process.upload, 500);
    expect(process.download == process.upload, isFalse);
  });
  test('процесс без счётчиков показывает нулевую скорость', () {
    const process = ProcessTraffic(name: 'app.exe', pid: 1, connections: 0);
    expect(process.download, 0);
    expect(process.upload, 0);
    expect(formatRate(0), '0.0 Кбит/с');
  });
}
