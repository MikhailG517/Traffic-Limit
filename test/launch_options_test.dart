import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/services/launch_options.dart';

void main() {
  test('diagnostics flag enables verbose logging', () {
    expect(const LaunchOptions(['--diagnostics']).diagnostics, isTrue);
  });

  test('ordinary launch disables diagnostics and does not force window', () {
    expect(const LaunchOptions([]).diagnostics, isFalse);
    expect(const LaunchOptions([]).showWindow, isFalse);
  });

  test('show flag forces the window to be shown', () {
    expect(const LaunchOptions(['--show']).showWindow, isTrue);
  });
}
