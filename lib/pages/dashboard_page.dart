import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/traffic_models.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {super.key,
      required this.stats,
      required this.service,
      required this.onOpenLimits});
  final TrafficStats stats;
  final TrafficService service;
  final VoidCallback onOpenLimits;
  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Трафик в реальном времени',
      action: Row(mainAxisSize: MainAxisSize.min, children: [
        const LivePill(),
        const SizedBox(width: 12),
        FilledButton.icon(
            onPressed: onOpenLimits,
            icon: const Icon(Icons.speed_rounded, size: 18),
            label: const Text('Ограничения'))
      ]),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: _trafficCard(
                  context,
                  'ЗАГРУЗКА',
                  formatRate(stats.downloadRate),
                  AppColors.green,
                  Icons.arrow_downward_rounded,
                  service.samples.map((e) => e.download).toList())),
          const SizedBox(width: 16),
          Expanded(
              child: _trafficCard(
                  context,
                  'ОТДАЧА',
                  formatRate(stats.uploadRate),
                  AppColors.red,
                  Icons.arrow_upward_rounded,
                  service.samples.map((e) => e.upload).toList()))
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: StatCard(
                  label: 'Сессия',
                  value: formatData(stats.downloadTotal + stats.uploadTotal),
                  color: AppColors.green,
                  icon: Icons.download_rounded,
                  subtitle:
                      '↓ ${formatData(stats.downloadTotal)} · ↑ ${formatData(stats.uploadTotal)} · с ${_hm(service.sessionStart)}')),
          const SizedBox(width: 16),
          Expanded(
              child: StatCard(
                  label: 'Сегодня',
                  value: formatData(service.todayTotal),
                  color: AppColors.green,
                  icon: Icons.today_rounded)),
          const SizedBox(width: 16),
          Expanded(
              child: StatCard(
                  label: 'Неделя',
                  value: formatData(service.weekTotal),
                  color: AppColors.green,
                  icon: Icons.date_range_rounded)),
          const SizedBox(width: 16),
          Expanded(
              child: StatCard(
                  label: 'Месяц',
                  value: formatData(service.monthTotal),
                  color: AppColors.green,
                  icon: Icons.calendar_month_rounded)),
        ]),
        const SizedBox(height: 18),
        Expanded(child: _interfaces()),
        const SizedBox(height: 4),
      ]));
  Widget _trafficCard(BuildContext context, String label, String rate,
          Color color, IconData icon, List<double> values) =>
      Card(
          child: Container(
              height: 195,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [
                    Theme.of(context).colorScheme.surface,
                    color.withValues(alpha: .10)
                  ])),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: color)),
                      const SizedBox(width: 12),
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700))
                    ]),
                    const SizedBox(height: 9),
                    Text(rate,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    SizedBox(
                        height: 42,
                        child: SpeedSparkline(values: values, color: color))
                  ])));
  String _hm(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Widget _interfaces() => SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Сетевые интерфейсы',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...service.interfaces.map((i) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.circle,
                size: 10,
                color: i.connected ? AppColors.green : AppColors.muted),
            title: Text(i.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle:
                Text(i.type, style: const TextStyle(color: AppColors.muted)),
            trailing: Text(
                '↓ ${formatRate(i.download)}  ↑ ${formatRate(i.upload)}',
                style: const TextStyle(color: AppColors.green, fontSize: 12))))
      ]));
}

class SpeedSparkline extends StatelessWidget {
  const SpeedSparkline({super.key, required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final points = values.isEmpty
        ? [const FlSpot(0, 0)]
        : [
            for (var i = 0; i < values.length; i++)
              FlSpot(i.toDouble(), values[i])
          ];
    final maximum =
        points.fold<double>(1, (max, point) => point.y > max ? point.y : max);
    return LineChart(LineChartData(
      minY: 0,
      maxY: maximum * 1.15,
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: points,
          isCurved: true,
          curveSmoothness: .25,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData:
              BarAreaData(show: true, color: color.withValues(alpha: .12)),
        )
      ],
    ));
  }
}

class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height -
          (values[i] - minValue) /
              (maxValue - minValue + 1) *
              size.height *
              .75 -
          size.height * .1;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter old) => old.values != values;
}
