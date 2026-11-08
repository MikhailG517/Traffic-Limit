import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/traffic_models.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/animated_brand.dart';
import '../widgets/common.dart';
import '../widgets/traffic_charts.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {super.key,
      required this.stats,
      required this.service,
      required this.monthlyLimitGb,
      required this.onOpenLimits});
  final TrafficStats stats;
  final TrafficService service;
  final double monthlyLimitGb;
  final VoidCallback onOpenLimits;

  @override
  Widget build(BuildContext context) {
    final now = service.clock();
    final month = service.month;
    final live = service.speedSamples(const Duration(minutes: 5));
    final peak = math.max(TrafficService.peakFromSamples(live, download: true),
        TrafficService.peakFromSamples(live, download: false));
    final limitMb = monthlyLimitGb * 1024;
    return PageShell(
        title: 'Обзор',
        subtitle: 'Сессия с ${hhmm(service.sessionStart)} · '
            '↓ ${formatData(stats.downloadTotal)} · ↑ ${formatData(stats.uploadTotal)}',
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          LivePill(active: stats.status == TrafficStatus.active),
          const SizedBox(width: 12),
          FilledButton.icon(
              onPressed: onOpenLimits,
              icon: const Icon(Icons.speed_rounded, size: 18),
              label: const Text('Ограничения'))
        ]),
        child: Column(children: [
          Expanded(
              flex: 11,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        width: 330,
                        child: GlassCard(
                            accent: AppColors.cyan,
                            padding: const EdgeInsets.all(8),
                            child: SpeedCore(
                                download: stats.downloadRate,
                                upload: stats.uploadRate,
                                peak: peak))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: GlassCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                          const SectionTitle('Скорость за 5 минут',
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LegendDot(
                                        color: AppColors.download,
                                        text: 'Загрузка'),
                                    SizedBox(width: 16),
                                    LegendDot(
                                        color: AppColors.upload,
                                        text: 'Отдача'),
                                  ])),
                          const SizedBox(height: 14),
                          Expanded(
                              child: SpeedLineChart(
                                  samples: live,
                                  window: const Duration(minutes: 5),
                                  now: now)),
                        ]))),
                  ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _usage('Сегодня', service.today, Icons.today_rounded,
                    AppColors.cyan, 'с 00:00, ${_date(now)}')),
            const SizedBox(width: 16),
            Expanded(
                child: _usage(
                    'Вчера',
                    service.yesterday,
                    Icons.history_rounded,
                    AppColors.lightBlue,
                    _date(DateTime(now.year, now.month, now.day - 1)))),
            const SizedBox(width: 16),
            Expanded(
                child: _usage(
                    'Неделя',
                    service.week,
                    Icons.date_range_rounded,
                    AppColors.violet,
                    'с пн, ${_date(TrafficLedger.startOfWeek(now))}')),
            const SizedBox(width: 16),
            Expanded(
                child: _usage(
                    'Месяц',
                    month,
                    Icons.calendar_month_rounded,
                    limitMb > 0 && month.total >= limitMb
                        ? AppColors.red
                        : AppColors.green,
                    limitMb > 0
                        ? '${(month.total / limitMb * 100).clamp(0, 999).toStringAsFixed(0)}% из ${monthlyLimitGb.toStringAsFixed(0)} ГБ'
                        : 'с 1-го числа')),
          ]),
          const SizedBox(height: 16),
          Expanded(
              flex: 7,
              child: GlassCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    SectionTitle('Сегодня по часам',
                        trailing: Flexible(
                            child: Text(
                                service.interfaces.isEmpty
                                    ? ''
                                    : service.interfaces.first.type,
                                style: TextStyle(
                                    color: Palette.of(context).muted,
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis))),
                    const SizedBox(height: 12),
                    Expanded(
                        child: VolumeBarChart(
                            buckets: service.ledger.hoursOf(now),
                            highlight: now.hour,
                            labelEvery: 3,
                            label: (t) => _two(t.hour),
                            tooltipTitle: (t) =>
                                '${_two(t.hour)}:00–${_two((t.hour + 1) % 24)}:00')),
                  ]))),
        ]));
  }

  Widget _usage(String label, Usage usage, IconData icon, Color color,
          String subtitle) =>
      StatCard(
          label: label,
          value: formatData(usage.total),
          icon: icon,
          color: color,
          subtitle: subtitle,
          footer:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SplitBar(download: usage.download, upload: usage.upload),
            const SizedBox(height: 8),
            Text(
                '↓ ${formatData(usage.download)}   ↑ ${formatData(usage.upload)}',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]));

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _date(DateTime t) => '${_two(t.day)}.${_two(t.month)}';
}
