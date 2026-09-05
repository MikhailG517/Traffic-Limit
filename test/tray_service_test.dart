import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/services/tray_service.dart';

void main() {
  test('tray menu exposes explicit commands when limiting is off', () {
    final items = TrayService.menuFor(false, false).items!;
    expect(
        items.any((item) =>
            item.key == 'limit-status' && item.label!.contains('выключено')),
        isTrue);
    expect(items.singleWhere((item) => item.key == 'enable-limits').disabled,
        isFalse);
    expect(items.singleWhere((item) => item.key == 'disable-limits').disabled,
        isTrue);
    expect(items.singleWhere((item) => item.key == 'diagnostics').checked,
        isFalse);
    expect(items.any((item) => item.key == 'open-logs'), isTrue);
    expect(items.any((item) => item.key == 'quit'), isTrue);
  });

  test('tray menu reports active limiting and enabled diagnostics', () {
    final items = TrayService.menuFor(true, true).items!;
    expect(
        items.any((item) =>
            item.key == 'limit-status' && item.label!.contains('включено')),
        isTrue);
    expect(items.singleWhere((item) => item.key == 'enable-limits').disabled,
        isTrue);
    expect(items.singleWhere((item) => item.key == 'disable-limits').disabled,
        isFalse);
    expect(
        items.singleWhere((item) => item.key == 'diagnostics').checked, isTrue);
  });
}
