import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/app.dart';

void main() {
  test('limits block navigates to the Limits tab index', () {
    expect(kLimitsIndex, 3);
    expect(kOverviewIndex, 0);
    expect(kGraphsIndex, 1);
    expect(kApplicationsIndex, 2);
    expect(kSettingsIndex, 4);
  });

  test('tab indices are unique navigation targets', () {
    final indices = {
      kOverviewIndex,
      kGraphsIndex,
      kApplicationsIndex,
      kLimitsIndex,
      kSettingsIndex
    };
    expect(indices.length, 5);
  });
}
