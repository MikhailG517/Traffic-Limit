import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/traffic_models.dart';
import '../theme.dart';

/// Rounds [value] up to 1/2/5 × 10ⁿ so axis labels are readable.
double niceCeil(double value) {
  if (value <= 0) return 1;
  final exponent =
      math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  for (final step in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (value <= step * exponent) return step * exponent;
  }
  return 10 * exponent;
}

String _two(int v) => v.toString().padLeft(2, '0');
String hhmm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
String hhmmss(DateTime t) => '${hhmm(t)}:${_two(t.second)}';

/// Keeps the highest sample of each time bucket so short peaks stay visible
/// after reducing ~1800 points of an hour to [buckets] points.
List<TrafficSample> downsample(
    List<TrafficSample> samples, DateTime from, Duration window, int buckets) {
  if (samples.length <= buckets) return samples;
  final width = window.inMicroseconds / buckets;
  final result = <TrafficSample>[];
  var index = -1;
  for (final s in samples) {
    final bucket = (s.time.difference(from).inMicroseconds / width).floor();
    if (bucket != index) {
      result.add(s);
      index = bucket;
      continue;
    }
    final last = result.last;
    result[result.length - 1] = TrafficSample(
        time: s.time,
        download: math.max(last.download, s.download),
        upload: math.max(last.upload, s.upload));
  }
  return result;
}

/// Live speed over a real time axis. X is seconds before [now], so the axis
/// shows clock time and gaps (sleep, failed reads) break the line instead of
/// being stretched over.
class SpeedLineChart extends StatelessWidget {
  const SpeedLineChart(
      {super.key,
      required this.samples,
      required this.window,
      required this.now});
  final List<TrafficSample> samples;
  final Duration window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final from = now.subtract(window);
    final points = downsample(samples, from, window, 300);
    final gap = math.max(6, window.inSeconds / 300 * 3);
    final peak = points.fold<double>(
        0, (m, s) => math.max(m, math.max(s.download, s.upload)));
    final maxY = niceCeil(math.max(peak * 1.1, 100));
    final span = window.inSeconds.toDouble();
    final labelStep = span <= 300 ? 60.0 : 600.0;
    // Seconds from `now` back to the previous whole tick, so grid lines and
    // labels sit on 14:36, 14:37 … instead of on "now − 60 s".
    final sinceTick =
        (now.minute * 60 + now.second) % labelStep + now.millisecond / 1000;

    List<FlSpot> spots(bool download) {
      final result = <FlSpot>[];
      DateTime? previous;
      for (final s in points) {
        if (previous != null && s.time.difference(previous).inSeconds > gap) {
          result.add(FlSpot.nullSpot);
        }
        result.add(FlSpot(-now.difference(s.time).inMilliseconds / 1000,
            download ? s.download : s.upload));
        previous = s.time;
      }
      return result;
    }

    LineChartBarData line(bool download) {
      final color = download ? AppColors.download : AppColors.upload;
      return LineChartBarData(
          spots: spots(download),
          isCurved: true,
          curveSmoothness: .18,
          preventCurveOverShooting: true,
          barWidth: 2.4,
          color: color,
          shadow: Shadow(color: color.withValues(alpha: .6), blurRadius: 10),
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: .28 * palette.glow + .05),
                    color.withValues(alpha: 0)
                  ])));
    }

    return LineChart(
        duration: Duration.zero,
        LineChartData(
          minX: -span,
          maxX: 0,
          baselineX: -sinceTick,
          minY: 0,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
              drawVerticalLine: true,
              horizontalInterval: maxY / 4,
              verticalInterval: labelStep,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: palette.border.withValues(alpha: .7),
                  strokeWidth: 1,
                  dashArray: const [4, 4]),
              getDrawingVerticalLine: (_) => FlLine(
                  color: palette.border.withValues(alpha: .35),
                  strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 78,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) =>
                          value == meta.max || value == 0
                              ? const SizedBox.shrink()
                              : Text(formatRate(value),
                                  style: TextStyle(
                                      color: palette.muted, fontSize: 10)))),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: labelStep,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
                        final t = now.add(
                            Duration(milliseconds: (value * 1000).round()));
                        return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(hhmm(t),
                                style: TextStyle(
                                    color: palette.muted, fontSize: 10)));
                      }))),
          lineTouchData: LineTouchData(
              getTouchedSpotIndicator: (bar, indexes) => [
                    for (final _ in indexes)
                      TouchedSpotIndicatorData(
                          FlLine(color: palette.muted, strokeWidth: 1),
                          FlDotData(
                              getDotPainter: (spot, _, bar, __) =>
                                  FlDotCirclePainter(
                                      radius: 4,
                                      color: Colors.white,
                                      strokeWidth: 2,
                                      strokeColor: bar.color!)))
                  ],
              touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => palette.cardHigh,
                  tooltipBorder: BorderSide(color: palette.border),
                  tooltipRoundedRadius: 12,
                  maxContentWidth: 220,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                              spot.barIndex == 0
                                  ? '${hhmmss(now.add(Duration(milliseconds: (spot.x * 1000).round())))}\n↓ ${formatRate(spot.y)}'
                                  : '↑ ${formatRate(spot.y)}',
                              TextStyle(
                                  color: spot.barIndex == 0
                                      ? AppColors.download
                                      : AppColors.upload,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12))
                      ])),
          lineBarsData: [line(true), line(false)],
        ));
  }
}

/// Stacked download/upload volume per bucket (hour, day or month).
class VolumeBarChart extends StatelessWidget {
  const VolumeBarChart(
      {super.key,
      required this.buckets,
      required this.label,
      required this.tooltipTitle,
      this.highlight,
      this.labelEvery = 1});
  final List<UsageBucket> buckets;
  final String Function(DateTime) label;
  final String Function(DateTime) tooltipTitle;
  final int? highlight;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final peak = buckets.fold<double>(0, (m, b) => math.max(m, b.usage.total));
    final maxY = niceCeil(math.max(peak * 1.1, 1));
    return LayoutBuilder(builder: (context, constraints) {
      final slot = (constraints.maxWidth - 70) / math.max(buckets.length, 1);
      final width = (slot * .62).clamp(3.0, 34.0);
      return BarChart(
          swapAnimationDuration: const Duration(milliseconds: 500),
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: palette.border.withValues(alpha: .7),
                    strokeWidth: 1,
                    dashArray: const [4, 4])),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 62,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) => value == meta.max
                            ? const SizedBox.shrink()
                            : Text(value == 0 ? '0' : formatData(value),
                                style: TextStyle(
                                    color: palette.muted, fontSize: 10)))),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 ||
                              i >= buckets.length ||
                              (i % labelEvery != 0 && i != highlight)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(label(buckets[i].start),
                                  style: TextStyle(
                                      color: i == highlight
                                          ? palette.text
                                          : palette.muted,
                                      fontWeight: i == highlight
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      fontSize: 10)));
                        }))),
            barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => palette.cardHigh,
                    tooltipBorder: BorderSide(color: palette.border),
                    tooltipRoundedRadius: 12,
                    maxContentWidth: 220,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, _, __, ___) {
                      final b = buckets[group.x];
                      return BarTooltipItem(
                          '${tooltipTitle(b.start)}\n',
                          TextStyle(
                              color: palette.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                          children: [
                            TextSpan(
                                text: '↓ ${formatData(b.usage.download)}\n',
                                style: const TextStyle(
                                    color: AppColors.download,
                                    fontWeight: FontWeight.w700)),
                            TextSpan(
                                text: '↑ ${formatData(b.usage.upload)}\n',
                                style: const TextStyle(
                                    color: AppColors.upload,
                                    fontWeight: FontWeight.w700)),
                            TextSpan(
                                text: 'Всего ${formatData(b.usage.total)}',
                                style: TextStyle(
                                    color: palette.muted,
                                    fontWeight: FontWeight.w600)),
                          ]);
                    })),
            barGroups: [
              for (var i = 0; i < buckets.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: buckets[i].usage.total,
                      width: width,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(width / 3)),
                      color: Colors.transparent,
                      backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: i == highlight
                              ? AppColors.blue.withValues(alpha: .08)
                              : Colors.transparent),
                      rodStackItems: [
                        BarChartRodStackItem(
                            0, buckets[i].usage.download, AppColors.download),
                        BarChartRodStackItem(buckets[i].usage.download,
                            buckets[i].usage.total, AppColors.upload),
                      ])
                ])
            ],
          ));
    });
  }
}
