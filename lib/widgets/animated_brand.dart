import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/traffic_models.dart';
import '../theme.dart';
import 'ambient_clock.dart';
import 'svg_path.dart';

/// Phase in `[0, 1)` of a loop with the given [period] on the ambient clock.
double ambientPhase(Duration period) =>
    (AmbientClock.instance.seconds *
        Duration.microsecondsPerSecond /
        period.inMicroseconds) %
    1;

/// Animated brand mark rendered from the SVG path data in [BrandPaths]: the
/// gauge draws itself, a spark runs along it and the arrows pulse.
class AnimatedLogo extends StatelessWidget {
  const AnimatedLogo({super.key, this.size = 28, this.animate = true});
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: CustomPaint(
          size: Size.square(size),
          painter: _LogoPainter(
              animate ? AmbientClock.instance : null, Palette.of(context))));
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.clock, this.palette) : super(repaint: clock);
  final Listenable? clock;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / BrandPaths.viewBox;
    final v = clock == null ? .6 : ambientPhase(const Duration(seconds: 4));
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
            ..strokeWidth = stroke * 1.9
            ..strokeCap = StrokeCap.round
            ..shader = shader
            ..color = Colors.white.withValues(alpha: .25));
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
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.palette != palette || old.clock != clock;
}

/// Hero panel of the dashboard: a dual speed gauge with glowing arcs whose
/// sweep follows the current rate, and SVG data streams with particles whose
/// speed and density follow the traffic.
///
/// Two layers keep the GPU cost low: the gauge (blurred glow) repaints only
/// while the displayed value settles after an update, and the particle layer
/// runs on the [AmbientClock] without any blur.
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

class _SpeedCoreState extends State<SpeedCore> {
  static const _settle = Duration(milliseconds: 120);
  final _clock = AmbientClock.instance;
  double _down = 0, _up = 0, _scale = 1000;
  double _lastSeconds = 0;
  bool _settling = false;

  double get _targetScale => _niceScale(math.max(widget.peak, 1000));

  @override
  void initState() {
    super.initState();
    _startSettling();
  }

  @override
  void didUpdateWidget(covariant SpeedCore old) {
    super.didUpdateWidget(old);
    if (old.download != widget.download ||
        old.upload != widget.upload ||
        old.peak != widget.peak) {
      _startSettling();
    }
  }

  void _startSettling() {
    if (_settling) return;
    _settling = true;
    _lastSeconds = _clock.seconds;
    _clock.addListener(_tick);
  }

  /// Exponential approach to the target; the listener is removed as soon as
  /// the values are within 0.5 %, so an idle gauge costs no frames.
  void _tick() {
    final now = _clock.seconds;
    final dt = now - _lastSeconds;
    _lastSeconds = now;
    final k = 1 - math.exp(-dt * 1000 / _settle.inMilliseconds);
    double step(double from, double to) {
      final next = from + (to - from) * k;
      return (to - next).abs() <= math.max(to.abs(), 1) * .005 ? to : next;
    }

    setState(() {
      _down = step(_down, widget.download);
      _up = step(_up, widget.upload);
      _scale = step(_scale, _targetScale);
    });
    if (_down == widget.download &&
        _up == widget.upload &&
        _scale == _targetScale) {
      _clock.removeListener(_tick);
      _settling = false;
    }
  }

  @override
  void dispose() {
    if (_settling) _clock.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final downRatio = (_down / _scale).clamp(0.0, 1.0);
    final upRatio = (_up / _scale).clamp(0.0, 1.0);
    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(
          child: CustomPaint(
              painter: _FlowPainter(
                  palette, math.max(widget.download, widget.upload) / _scale))),
      RepaintBoundary(
          child: CustomPaint(
              painter: _GaugePainter(palette, downRatio, upRatio),
              child: Center(child: _readout(context)))),
    ]);
  }

  Widget _readout(BuildContext context) {
    final palette = Palette.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _rate(_down, AppColors.download, Icons.south_rounded, 'Загрузка'),
      const SizedBox(height: 10),
      Container(width: 120, height: 1, color: palette.border),
      const SizedBox(height: 10),
      _rate(_up, AppColors.upload, Icons.north_rounded, 'Отдача'),
      const SizedBox(height: 10),
      Text('шкала ${formatRate(_scale)}',
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

const _sweep = math.pi * 1.5;
const _start = math.pi * .75;

double _gaugeRadius(Size size) => math.min(size.width, size.height) / 2 - 18;

/// Static part of the gauge: tracks, value arcs with glow and the scale.
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.palette, this.downRatio, this.upRatio);
  final Palette palette;
  final double downRatio, upRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = _gaugeRadius(size);
    _ring(canvas, center, radius, downRatio, AppColors.download, 12);
    _ring(canvas, center, radius - 22, upRatio, AppColors.upload, 8);
    _ticks(canvas, center, radius + 10);
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
    final value = ratio * _sweep;
    if (value < .002) return;
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
          ..shader = SweepGradient(
                  startAngle: _start,
                  endAngle: _start + _sweep,
                  colors: [color.withValues(alpha: .35), color, Colors.white],
                  stops: const [0, .8, 1],
                  tileMode: TileMode.clamp)
              .createShader(rect));
    final angle = _start + value;
    final tip = c + Offset(math.cos(angle), math.sin(angle)) * r;
    canvas.drawCircle(
        tip,
        width * 1.3,
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

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.downRatio != downRatio ||
      old.upRatio != upRatio ||
      old.palette != palette;
}

/// Animated layer: SVG data streams with particles and a slow orbit. No blur:
/// the soft look comes from a wide low-alpha halo under each particle.
class _FlowPainter extends CustomPainter {
  _FlowPainter(this.palette, double activity)
      : activity = activity.clamp(0.0, 1.0),
        super(repaint: AmbientClock.instance);
  final Palette palette;
  final double activity;

  static Size? _cachedSize;
  static List<(Path, PathMetric)> _cached = const [];

  static List<(Path, PathMetric)> _streams(Size size) {
    if (size == _cachedSize) return _cached;
    final sx = size.width / StreamPaths.width;
    final sy = size.height * .5 / StreamPaths.height;
    _cachedSize = size;
    return _cached = [
      for (final data in StreamPaths.streams)
        () {
          final path =
              scaledSvgPath(data, sx, sy).shift(Offset(0, size.height * .25));
          return (path, path.computeMetrics().first);
        }()
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = ambientPhase(const Duration(seconds: 12));
    final streams = _streams(size);
    for (var i = 0; i < streams.length; i++) {
      final (path, metric) = streams[i];
      final color = i == 1 ? AppColors.upload : AppColors.download;
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = color.withValues(alpha: .10 + .12 * activity));
      final count = 3 + (activity * 6).round();
      final speed = (i == 1 ? -1 : 1) * (1 + activity * 5);
      final halo = Paint();
      final core = Paint();
      for (var p = 0; p < count; p++) {
        final phase = (t * speed + p / count + i * .17) % 1;
        final tangent = metric.getTangentForOffset(metric.length * phase);
        if (tangent == null) continue;
        final fade = math.sin(phase * math.pi);
        halo.color = color.withValues(alpha: .18 * fade * palette.glow);
        core.color = color.withValues(alpha: .35 + .6 * fade * palette.glow);
        canvas.drawCircle(tangent.position, 5, halo);
        canvas.drawCircle(tangent.position, 2, core);
      }
    }
    _orbit(canvas, size.center(Offset.zero), _gaugeRadius(size) - 40, t);
  }

  void _orbit(Canvas canvas, Offset c, double r, double t) {
    final spin = t * 2 * math.pi;
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

  @override
  bool shouldRepaint(covariant _FlowPainter old) =>
      old.activity != activity || old.palette != palette;
}

/// Static colour blobs behind the whole window. Painted once and cached by
/// the raster cache: a full-window gradient redrawn every frame was the
/// largest single GPU cost.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
            child: RepaintBoundary(
                child: CustomPaint(
                    isComplex: true,
                    painter: _AuroraPainter(Palette.of(context))))),
        child,
      ]);
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.palette);
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
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
    blob(AppColors.blue, .84, .14, r);
    blob(AppColors.violet, .15, .93, r);
    blob(AppColors.cyan, .5, .55, r * .7);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.palette != palette;
}
