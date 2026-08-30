import 'package:flutter/material.dart';
import '../models/traffic_models.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GraphsPage extends StatefulWidget {
  const GraphsPage({super.key, required this.traffic, required this.stats});
  final TrafficService traffic;
  final TrafficStats stats;
  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage> {
  HistoryPeriod period = HistoryPeriod.hour;
  String title(HistoryPeriod value) => switch (value) {
        HistoryPeriod.hour => '1 час',
        HistoryPeriod.week => 'Неделя',
        HistoryPeriod.month => 'Месяц',
        HistoryPeriod.year => 'Год'
      };
  Future<void> reset() async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Сбросить статистику?'),
                    content: const Text(
                        'История трафика и объёмы текущей сессии будут удалены. Это действие нельзя отменить.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Сбросить'))
                    ])) ??
        false;
    if (!confirmed || !mounted) return;
    widget.traffic.resetStatistics();
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Статистика сброшена')));
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.traffic.samplesFor(period);
    return PageShell(
        title: 'Графики',
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final value in HistoryPeriod.values)
            Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                    label: Text(title(value)),
                    selected: period == value,
                    onSelected: (_) => setState(() => period = value))),
          const SizedBox(width: 10),
          IconButton(
              tooltip: 'Сбросить статистику',
              onPressed: reset,
              icon: const Icon(Icons.restart_alt_rounded))
        ]),
        child: Column(children: [
          Expanded(
              child: SectionCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text('История: ${title(period)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Expanded(
                    child: CustomPaint(
                        painter: TrafficChartPainter(
                            values.map((e) => e.download).toList(),
                            values.map((e) => e.upload).toList()),
                        child: const SizedBox.expand())),
                const SizedBox(height: 10),
                const Row(children: [
                  LegendDot(color: AppColors.green, text: 'Загрузка'),
                  SizedBox(width: 20),
                  LegendDot(color: AppColors.red, text: 'Отдача')
                ])
              ]))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: StatCard(
                    label: 'Пик загрузки',
                    value: formatRate(widget.stats.downloadRate),
                    color: AppColors.green,
                    icon: Icons.arrow_downward_rounded)),
            const SizedBox(width: 16),
            Expanded(
                child: StatCard(
                    label: 'Пик отдачи',
                    value: formatRate(widget.stats.uploadRate),
                    color: AppColors.red,
                    icon: Icons.arrow_upward_rounded))
          ]),
        ]));
  }
}

class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(color: AppColors.muted))
      ]);
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
