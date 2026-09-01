import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/services/limit_validation.dart';

void main() {
  test('accepts decimal limits with comma or dot notation', () {
    expect(parseLimit('30'), 30);
    expect(parseLimit('30,5'), 30.5);
  });

  test('rejects zero, invalid and out-of-range limits', () {
    expect(parseLimit('0'), isNull);
    expect(parseLimit('-1'), isNull);
    expect(parseLimit('abc'), isNull);
    expect(parseLimit('500001'), isNull);
  });
}
