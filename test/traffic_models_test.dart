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
}
