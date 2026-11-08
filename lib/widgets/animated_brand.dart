import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/traffic_models.dart';
import '../theme.dart';
import 'svg_path.dart';

/// Repeating animation clock shared by the decorative painters.
mixin _Loop<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  late final AnimationController loop;
  Duration get period;

  @override
  void initState() {
    super.initState();
    loop = AnimationController(vsync: this, duration: period)..repeat();
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

/// Animated brand mark rendered from the SVG path data in [BrandPaths]: the
/// gauge draws itself, a spark runs along it and the arrows pulse.
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({super.key, this.size = 28, this.animate = true});
  final double size;
  final bool animate;
  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin, _Loop {
  @override
  Duration get period => const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    if (!widget.animate) loop.value = .6;
    if (!widget.animate) loop.stop();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoPainter(loop, Palette.of(context))));
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t, this.palette) : super(repaint: t);
  final Animation<double> t;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / BrandPaths.viewBox;
    final v = t.value;
    final rect = Offset.zero & size;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.deflate(size.width * .03), Radius.circular(size.width * .25)),
        Paint()..color = const Color(0xff0b101b));

    final gauge = scaledSvgPath(BrandPaths.gauge, s);
    final stroke = 4.5 * s;
    canvas.drawPath(
        gauge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = AppColors.border);

    // 0→.45 draw, .45→.8 hold, .8→1 retract (mirrors the SVG keyTimes).
    final progress = v < .45
        ? Curves.easeOutCubic.transform(v / .45)
        : v < .8
            ? 1.0
            : 1 - Curves.easeInCubic.transform((v - .8) / .2);
    final metric = gauge.computeMetrics().first;
    final length = metric.length * progress;
    if (length > .5) {
      final shader = SweepGradient(colors: const [
        AppColors.cyan,
        AppColors.blue,
        AppColors.violet,
        AppColors.cyan
      ], transform: GradientRotation(v * 2 * math.pi))
          .createShader(rect);
      final arc = metric.extractPath(0, length);
      canvas.drawPath(
          arc,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 1.8
            ..strokeCap = StrokeCap.round
            ..shader = shader
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.4 * s));
      canvas.drawPath(
          arc,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..shader = shader);
      final tip = metric.getTangentForOffset(length)!.position;
      canvas.drawCircle(tip, 2.4 * s, Paint()..color = Colors.white);
    }

    final bob = math.sin(v * 2 * math.pi * 2.5) * 2 * s;
    _arrow(canvas, BrandPaths.download, s, AppColors.cyan, Offset(0, bob));
    _arrow(canvas, BrandPaths.upload, s, AppColors.red, Offset(0, -bob));
    final blink = .35 + .65 * (0.5 + 0.5 * math.cos(v * 2 * math.pi * 3.3));
    canvas.drawPath(scaledSvgPath(BrandPaths.limitMark, s),
        Paint()..color = AppColors.amber.withValues(alpha: blink));
  }

  void _arrow(Canvas canvas, String data, double s, Color color, Offset by) {
    final path = scaledSvgPath(data, s).shift(by);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.palette != palette;
}

/// Hero panel of the dashboard: a dual speed gauge with glowing arcs whose
/// sweep follows the current rate, and SVG data streams with particles whose
/// speed and density follow the traffic.
class SpeedCore extends StatefulWidget {
  const SpeedCore(
      {super.key,
      required this.download,
      required this.upload,
      required this.peak});
  final double download, upload, peak;
  @override
  State<SpeedCore> createState() => _SpeedCoreState();
}

class _SpeedCoreState extends State<SpeedCore>
    with TickerProviderStateMixin, _Loop {
  @override
  Duration get period => const Duration(seconds: 12);

  late final AnimationController _value = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  double _fromDown = 0, _fromUp = 0, _fromScale = 1000;

  double get _scale => _niceScale(math.max(widget.peak, 1000));

  @override
  void initState() {
    super.initState();
    _value.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant SpeedCore old) {
    super.didUpdateWidget(old);
    if (old.download == widget.download &&
        old.upload == widget.upload &&
        old.peak == widget.peak) {
      return;
    }
    final k = Curves.easeOutCubic.transform(_value.value);
    _fromDown = lerpDouble(_fromDown, old.download, k)!;
    _fromUp = lerpDouble(_fromUp, old.upload, k)!;
    _fromScale =
        lerpDouble(_fromScale, _niceScale(math.max(old.peak, 1000)), k)!;
    _value.forward(from: 0);
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return AnimatedBuilder(
        animation: _value,
        builder: (context, _) {
          final k = Curves.easeOutCubic.transform(_value.value);
          final down = lerpDouble(_fromDown, widget.download, k)!;
          final up = lerpDouble(_fromUp, widget.upload, k)!;
          final scale = lerpDouble(_fromScale, _scale, k)!;
          return RepaintBoundary(
              child: CustomPaint(
                  painter: _CorePainter(
                      loop, palette, down / scale, up / scale, down, up),
                  child: Center(child: _readout(context, down, up, scale))));
        });
  }

  Widget _readout(BuildContext context, double down, double up, double scale) {
    final palette = Palette.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _rate(down, AppColors.download, Icons.south_rounded, 'Загрузка'),
      const SizedBox(height: 10),
      Container(width: 120, height: 1, color: palette.border),
      const SizedBox(height: 10),
      _rate(up, AppColors.upload, Icons.north_rounded, 'Отдача'),
      const SizedBox(height: 10),
      Text('шкала ${formatRate(scale)}',
          style: TextStyle(color: palette.muted, fontSize: 11)),
    ]);
  }

  Widget _rate(double value, Color color, IconData icon, String label) {
    final parts = formatRate(value).split(' ');
    return Column(children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4)),
      ]),
      Text.rich(TextSpan(children: [
        TextSpan(
            text: parts.first,
            style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.1,
                fontFeatures: [FontFeature.tabularFigures()])),
        TextSpan(
            text: ' ${parts.last}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Palette.of(context).muted)),
      ])),
    ]);
  }
}

/// Rounds the gauge scale up to 1/2/5 × 10ⁿ kbit/s.
double _niceScale(double value) {
  final exponent = math.pow(10, (math.log(value) / math.ln10).floor());
  for (final step in const [1, 2, 5, 10]) {
    if (value <= step * exponent) return step * exponent.toDouble();
  }
  return 10 * exponent.toDouble();
}

class _CorePainter extends CustomPainter {
  _CorePainter(
      this.t, this.palette, this.downRatio, this.upRatio, this.down, this.up)
      : super(repaint: t);
  final Animation<double> t;
  final Palette palette;
  final double downRatio, upRatio, down, up;

  static const _sweep = math.pi * 1.5;
  static const _start = math.pi * .75;

  @override
  void paint(Canvas canvas, Size size) {
    _streams(canvas, size);
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 18;
    _ring(canvas, center, radius, downRatio, AppColors.download, 12);
    _ring(canvas, center, radius - 22, upRatio, AppColors.upload, 8);
    _ticks(canvas, center, radius + 10);
    _orbit(canvas, center, radius - 40);
  }

  void _ring(Canvas canvas, Offset c, double r, double ratio, Color color,
      double width) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
        rect,
        _start,
        _sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = palette.cardHigh);
    final value = ratio.clamp(0.0, 1.0) * _sweep;
    if (value < .002) return;
    final shader = SweepGradient(
            startAngle: _start,
            endAngle: _start + _sweep,
            colors: [color.withValues(alpha: .35), color, Colors.white],
            stops: const [0, .8, 1],
            tileMode: TileMode.clamp)
        .createShader(rect);
    canvas.drawArc(
        rect,
        _start,
        value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2.2
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: .35 * palette.glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawArc(
        rect,
        _start,
        value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..shader = shader);
    final angle = _start + value;
    final tip = c + Offset(math.cos(angle), math.sin(angle)) * r;
    final pulse = .6 + .4 * math.sin(t.value * 2 * math.pi * 12);
    canvas.drawCircle(
        tip,
        width * .9 + 3 * pulse,
        Paint()
          ..color = color.withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(tip, width * .45, Paint()..color = Colors.white);
  }

  void _ticks(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 40; i++) {
      final a = _start + _sweep * i / 40;
      final major = i % 10 == 0;
      paint.color = palette.muted.withValues(alpha: major ? .7 : .25);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * r, c + dir * (r + (major ? 8 : 4)), paint);
    }
  }

  void _orbit(Canvas canvas, Offset c, double r) {
    final spin = t.value * 2 * math.pi;
    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.border;
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
          rect, spin + i * 2 * math.pi / 3, math.pi / 2, false, paint);
    }
    final dot = c + Offset(math.cos(-spin * 2), math.sin(-spin * 2)) * r;
    canvas.drawCircle(dot, 2.5, Paint()..color = AppColors.violet);
  }

  /// SVG streams across the panel; particles travel faster with more traffic.
  void _streams(Canvas canvas, Size size) {
    final sx = size.width / StreamPaths.width;
    final sy = size.height * .5 / StreamPaths.height;
    final activity = (math.max(downRatio, upRatio)).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(0, size.height * .25);
    for (var i = 0; i < StreamPaths.streams.length; i++) {
      final path = scaledSvgPath(StreamPaths.streams[i], sx, sy);
      final color = i == 1 ? AppColors.upload : AppColors.download;
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = color.withValues(alpha: .10 + .12 * activity));
      final metric = path.computeMetrics().first;
      final count = 3 + (activity * 6).round();
      final speed = (i == 1 ? -1 : 1) * (1 + activity * 5);
      for (var p = 0; p < count; p++) {
        final phase = (t.value * speed + p / count + i * .17) % 1;
        final offset = metric.length * (phase < 0 ? phase + 1 : phase);
        final tangent = metric.getTangentForOffset(offset);
        if (tangent == null) continue;
        final fade = math.sin(((phase < 0 ? phase + 1 : phase)) * math.pi);
        canvas.drawCircle(
            tangent.position,
            2.2,
            Paint()
              ..color = color.withValues(alpha: .25 + .6 * fade * palette.glow)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CorePainter old) =>
      old.downRatio != downRatio ||
      old.upRatio != upRatio ||
      old.palette != palette;
}

/// Slowly drifting colour blobs behind the whole window.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;
  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin, _Loop {
  @override
  Duration get period => const Duration(seconds: 30);

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
            child: RepaintBoundary(
                child: CustomPaint(
                    painter: _AuroraPainter(loop, Palette.of(context))))),
        widget.child,
      ]);
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.palette) : super(repaint: t);
  final Animation<double> t;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    final a = t.value * 2 * math.pi;
    void blob(Color color, double x, double y, double r) {
      final c = Offset(size.width * x, size.height * y);
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: .16 * palette.glow),
              color.withValues(alpha: 0)
            ]).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    final r = size.shortestSide * .55;
    blob(AppColors.blue, .78 + .08 * math.cos(a), .12 + .06 * math.sin(a), r);
    blob(AppColors.violet, .15 + .06 * math.sin(a), .9 + .05 * math.cos(a), r);
    blob(AppColors.cyan, .45 + .1 * math.sin(a + 1), .5 + .08 * math.cos(a),
        r * .7);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.palette != palette;
}
