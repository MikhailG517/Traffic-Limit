import 'package:fl_chart/fl_chart.dart';
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
    final peakDownload = widget.traffic.peakFor(period, download: true);
    final peakUpload = widget.traffic.peakFor(period, download: false);
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
                    child: values.length < 2
                        ? const Center(
                            child: Text(
                                'Недостаточно накопленной истории для этого периода',
                                style: TextStyle(color: AppColors.muted)))
                        : SpeedChart(values: values)),
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
                    value: formatRate(peakDownload),
                    color: AppColors.green,
                    icon: Icons.arrow_downward_rounded,
                    subtitle: title(period))),
            const SizedBox(width: 16),
            Expanded(
                child: StatCard(
                    label: 'Пик отдачи',
                    value: formatRate(peakUpload),
                    color: AppColors.red,
                    icon: Icons.arrow_upward_rounded,
                    subtitle: title(period)))
          ])
        ]));
  }
}

class SpeedChart extends StatelessWidget {
  const SpeedChart({super.key, required this.values});
  final List<TrafficSample> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(
        1,
        (peak, value) => [peak, value.download, value.upload]
            .reduce((a, b) => a > b ? a : b));
    final axisColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: .62);
    final gridColor = Theme.of(context).dividerColor.withValues(alpha: .5);
    return LineChart(LineChartData(
      minX: 0,
      maxX: (values.length - 1).toDouble(),
      minY: 0,
      maxY: maxValue * 1.15,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
              axisNameWidget: const Text('Скорость, кбит/с'),
              axisNameSize: 30,
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  interval: maxValue / 4,
                  getTitlesWidget: (value, _) => Text(formatRate(value),
                      style: TextStyle(color: axisColor, fontSize: 10)))),
          bottomTitles: AxisTitles(
              axisNameWidget: const Text('Время'),
              axisNameSize: 24,
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: _bottomInterval,
                  getTitlesWidget: (value, _) {
                    final index = value.round().clamp(0, values.length - 1);
                    return Text(_time(values[index].time),
                        style: TextStyle(color: axisColor, fontSize: 10));
                  }))),
      lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                    final sample = values[spot.spotIndex];
                    final isDownload = spot.barIndex == 0;
                    return LineTooltipItem(
                        '${_time(sample.time)}\n${isDownload ? 'Загрузка' : 'Отдача'}: ${formatRate(spot.y)}',
                        TextStyle(
                            color: isDownload ? AppColors.green : AppColors.red,
                            fontWeight: FontWeight.w700));
                  }).toList())),
      lineBarsData: [
        _line(values, true, AppColors.green),
        _line(values, false, AppColors.red)
      ],
    ));
  }

  double get _bottomInterval =>
      values.length <= 6 ? 1 : (values.length / 5).ceilToDouble();

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  LineChartBarData _line(
          List<TrafficSample> data, bool download, Color color) =>
      LineChartBarData(
          spots: [
            for (var i = 0; i < data.length; i++)
              FlSpot(i.toDouble(), download ? data[i].download : data[i].upload)
          ],
          isCurved: true,
          curveSmoothness: .22,
          color: color,
          barWidth: 2.4,
          dotData: const FlDotData(show: false),
          belowBarData:
              BarAreaData(show: true, color: color.withValues(alpha: .08)));
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
        Text(text,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .65)))
      ]);
}
