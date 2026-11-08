import 'package:flutter/material.dart';

import '../models/traffic_models.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/traffic_charts.dart';

const _months = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', //
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
];
const _monthsShort = [
  'янв', 'фев', 'мар', 'апр', 'май', 'июн', //
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
];
const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String _two(int v) => v.toString().padLeft(2, '0');
String _date(DateTime t) => '${_two(t.day)}.${_two(t.month)}';

class GraphsPage extends StatefulWidget {
  const GraphsPage({super.key, required this.traffic, required this.stats});
  final TrafficService traffic;
  final TrafficStats stats;

  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage> {
  SpeedWindow window = SpeedWindow.fiveMinutes;
  VolumePeriod period = VolumePeriod.day;

  Duration get _window => switch (window) {
        SpeedWindow.fiveMinutes => const Duration(minutes: 5),
        SpeedWindow.hour => const Duration(hours: 1),
      };

  Future<void> reset() async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Сбросить статистику?'),
                    content: const Text(
                        'Журнал объёмов по часам и дням, история скорости и счётчики сессии будут удалены. Это действие нельзя отменить.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена')),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.red),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Сбросить'))
                    ])) ??
        false;
    if (!confirmed || !mounted) return;
    await widget.traffic.resetStatistics();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Статистика сброшена')));
  }

  @override
  Widget build(BuildContext context) {
    final traffic = widget.traffic;
    final now = traffic.clock();
    final samples = traffic.speedSamples(_window);
    final peakDown = TrafficService.peakFromSamples(samples, download: true);
    final peakUp = TrafficService.peakFromSamples(samples, download: false);
    final volume = _volume(now);
    final total =
        volume.buckets.fold<Usage>(const Usage(), (s, b) => s + b.usage);
    return PageShell(
        title: 'Графики',
        subtitle: 'Скорость — с реальной шкалой времени, объём — по календарю',
        action: IconButton.outlined(
            tooltip: 'Сбросить статистику',
            onPressed: reset,
            icon: const Icon(Icons.restart_alt_rounded)),
        child: Column(children: [
          Expanded(
              child: GlassCard(
                  accent: AppColors.cyan,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle('Скорость',
                            trailing: PillTabs<SpeedWindow>(
                                values: SpeedWindow.values,
                                selected: window,
                                label: (v) => switch (v) {
                                      SpeedWindow.fiveMinutes => '5 минут',
                                      SpeedWindow.hour => '1 час',
                                    },
                                onChanged: (v) => setState(() => window = v))),
                        const SizedBox(height: 8),
                        Row(children: [
                          _figure(
                              'Сейчас ↓',
                              formatRate(widget.stats.downloadRate),
                              AppColors.download),
                          _figure(
                              'Сейчас ↑',
                              formatRate(widget.stats.uploadRate),
                              AppColors.upload),
                          _figure('Пик ↓', formatRate(peakDown),
                              AppColors.download),
                          _figure(
                              'Пик ↑', formatRate(peakUp), AppColors.upload),
                        ]),
                        const SizedBox(height: 10),
                        Expanded(
                            child: samples.length < 2
                                ? _empty('Скорость появится через пару секунд')
                                : SpeedLineChart(
                                    samples: samples,
                                    window: _window,
                                    now: now)),
                      ]))),
          const SizedBox(height: 16),
          Expanded(
              child: GlassCard(
                  accent: AppColors.violet,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle('Объём трафика · ${volume.title}',
                            trailing: PillTabs<VolumePeriod>(
                                values: VolumePeriod.values,
                                selected: period,
                                label: (v) => switch (v) {
                                      VolumePeriod.day => 'Сутки',
                                      VolumePeriod.week => 'Неделя',
                                      VolumePeriod.month => 'Месяц',
                                      VolumePeriod.year => 'Год',
                                    },
                                onChanged: (v) => setState(() => period = v))),
                        const SizedBox(height: 8),
                        Row(children: [
                          _figure('Всего', formatData(total.total),
                              AppColors.violet),
                          _figure('Загрузка', formatData(total.download),
                              AppColors.download),
                          _figure('Отдача', formatData(total.upload),
                              AppColors.upload),
                          const Spacer(),
                          const LegendDot(
                              color: AppColors.download, text: 'Загрузка'),
                          const SizedBox(width: 16),
                          const LegendDot(
                              color: AppColors.upload, text: 'Отдача'),
                        ]),
                        const SizedBox(height: 10),
                        Expanded(
                            child: total.total <= 0
                                ? _empty('За этот период трафик ещё не учтён')
                                : VolumeBarChart(
                                    buckets: volume.buckets,
                                    highlight: volume.current,
                                    labelEvery: volume.labelEvery,
                                    label: volume.label,
                                    tooltipTitle: volume.tooltip)),
                      ]))),
        ]));
  }

  _Volume _volume(DateTime now) {
    final ledger = widget.traffic.ledger;
    return switch (period) {
      VolumePeriod.day => _Volume(
          'сегодня по часам',
          ledger.hoursOf(now),
          now.hour,
          3,
          (t) => _two(t.hour),
          (t) =>
              '${_date(t)}, ${_two(t.hour)}:00–${_two((t.hour + 1) % 24)}:00'),
      VolumePeriod.week => _Volume(
          'с ${_date(TrafficLedger.startOfWeek(now))}',
          ledger.daysOfWeek(now),
          now.weekday - 1,
          1,
          (t) => _weekdays[t.weekday - 1],
          (t) => '${_weekdays[t.weekday - 1]}, ${_date(t)}'),
      VolumePeriod.month => _Volume(
          '${_months[now.month - 1].toLowerCase()} ${now.year}',
          ledger.daysOfMonth(now),
          now.day - 1,
          3,
          (t) => '${t.day}',
          (t) => '${t.day} ${_monthsShort[t.month - 1]}'),
      VolumePeriod.year => _Volume(
          '${now.year} год',
          ledger.monthsOfYear(now),
          now.month - 1,
          1,
          (t) => _monthsShort[t.month - 1],
          (t) => '${_months[t.month - 1]} ${t.year}'),
    };
  }

  Widget _figure(String label, String value, Color color) => Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                color: Palette.of(context).muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]));

  Widget _empty(String text) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.insights_rounded,
            size: 36, color: Palette.of(context).border),
        const SizedBox(height: 8),
        Text(text, style: TextStyle(color: Palette.of(context).muted)),
      ]));
}

class _Volume {
  const _Volume(this.title, this.buckets, this.current, this.labelEvery,
      this.label, this.tooltip);
  final String title;
  final List<UsageBucket> buckets;
  final int current;
  final int labelEvery;
  final String Function(DateTime) label;
  final String Function(DateTime) tooltip;
}
