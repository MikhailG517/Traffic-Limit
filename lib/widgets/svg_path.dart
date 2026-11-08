import 'dart:typed_data';
import 'dart:ui';

import 'package:path_parsing/path_parsing.dart';

/// SVG path data of the brand mark, authored in a 64×64 viewBox. The same
/// strings are used by `assets/brand/traffic_limit_animated.svg`.
class BrandPaths {
  static const viewBox = 64.0;
  static const gauge = 'M16.44 49.56 A22 22 0 1 1 47.56 49.56';
  static const download = 'M26 21 V42 M21 37 L26 42 L31 37';
  static const upload = 'M38 45 V24 M33 29 L38 24 L43 29';
  static const limitMark = 'M51.05 23 m-3 0 a3 3 0 1 0 6 0 a3 3 0 1 0 -6 0';
}

/// Flowing data streams for the live speed panel, viewBox 400×60.
class StreamPaths {
  static const width = 400.0;
  static const height = 60.0;
  static const streams = [
    'M0 34 C60 10 110 54 170 32 S290 8 340 30 S390 44 400 36',
    'M0 26 C50 46 120 14 180 30 S280 50 330 26 S380 18 400 24',
    'M0 40 C70 30 130 46 200 38 S300 22 350 38 S385 40 400 42',
  ];
}

class _PathBuilder extends PathProxy {
  final path = Path();
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(
          double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

final _cache = <String, Path>{};

/// Parses SVG path data once; callers scale the result with [scaledSvgPath].
Path svgPath(String data) => _cache.putIfAbsent(data, () {
      final builder = _PathBuilder();
      writeSvgPathDataToPath(data, builder);
      return builder.path;
    });

Path scaledSvgPath(String data, double sx, [double? sy]) {
  final matrix = Float64List(16)
    ..[0] = sx
    ..[5] = sy ?? sx
    ..[10] = 1
    ..[15] = 1;
  return svgPath(data).transform(matrix);
}
