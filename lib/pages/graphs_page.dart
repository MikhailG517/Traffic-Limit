import 'package:flutter/material.dart';
import '../models/traffic_models.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GraphsPage extends StatelessWidget {
  const GraphsPage({super.key, required this.traffic, required this.stats});
  final TrafficService traffic;
  final TrafficStats stats;
  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Графики',
      action: const Chip(label: Text('1 час')),
      child: Column(children: [
        SectionCard(
            child: SizedBox(
                height: 340,
                child: CustomPaint(
                    painter: TrafficChartPainter(
                        traffic.samples.map((e) => e.download).toList(),
                        traffic.samples.map((e) => e.upload).toList()),
                    child: const SizedBox.expand()))),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: StatCard(
                  label: 'Пик загрузки',
                  value: formatRate(stats.downloadRate),
                  color: AppColors.green,
                  icon: Icons.arrow_downward_rounded)),
          const SizedBox(width: 16),
          Expanded(
              child: StatCard(
                  label: 'Пик отдачи',
                  value: formatRate(stats.uploadRate),
                  color: AppColors.red,
                  icon: Icons.arrow_upward_rounded))
        ]),
      ]));
}

class TrafficChartPainter extends CustomPainter {
  TrafficChartPainter(this.download, this.upload);
  final List<double> download;
  final List<double> upload;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _line(canvas, size, download, AppColors.green);
    _line(canvas, size, upload, AppColors.red);
  }

  void _line(Canvas canvas, Size size, List<double> values, Color color) {
    if (values.length < 2) return;
    final maxValue =
        [...download, ...upload].fold<double>(1, (a, b) => a > b ? a : b);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - values[i] / maxValue * size.height * .85;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(covariant TrafficChartPainter old) =>
      old.download != download || old.upload != upload;
}
