import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/services/launch_options.dart';

void main() {
  test('autostart argument starts the application hidden', () {
    expect(const LaunchOptions(['--autostart']).startHidden, isTrue);
  });

  test('ordinary launch shows the application window', () {
    expect(const LaunchOptions([]).startHidden, isFalse);
  });
}
