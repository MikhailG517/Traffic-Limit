import 'package:flutter/material.dart';
import '../models/traffic_models.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ApplicationsPage extends StatelessWidget {
  const ApplicationsPage({super.key, required this.traffic});
  final TrafficService traffic;
  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Приложения',
      action: const LivePill(),
      child: SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(
              child: Text('Активные сетевые соединения',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Text('Обновляется каждую секунду',
              style: TextStyle(color: AppColors.muted, fontSize: 12))
        ]),
        const SizedBox(height: 14),
        Expanded(
            child: traffic.processes.isEmpty
                ? const Center(
                    child: Text('Активных соединений нет',
                        style: TextStyle(color: AppColors.muted)))
                : ListView.separated(
                    itemCount: traffic.processes.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (_, index) => _row(traffic.processes[index]))),
      ])));
  Widget _row(ProcessTraffic process) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        CircleAvatar(
            radius: 18,
            backgroundColor: Color(process.color),
            child: Text(process.name[0].toUpperCase())),
        const SizedBox(width: 12),
        SizedBox(
            width: 145,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(process.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('PID ${process.pid} · ${process.connections} соединений',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12))
            ])),
        Expanded(
            child: _metric(
                '↓ Загрузка',
                process.hasByteCounters
                    ? formatRate(process.download)
                    : 'нет данных',
                AppColors.green)),
        Expanded(
            child: _metric(
                '↑ Отдача',
                process.hasByteCounters
                    ? formatRate(process.upload)
                    : 'нет данных',
                AppColors.red)),
        Expanded(
            child: _metric(
                'Входящий',
                process.hasByteCounters
                    ? formatData(process.downloadTotal)
                    : 'нет данных',
                AppColors.green)),
        Expanded(
            child: _metric(
                'Исходящий',
                process.hasByteCounters
                    ? formatData(process.uploadTotal)
                    : 'нет данных',
                AppColors.red)),
        Expanded(
            child: _metric(
                'Всего',
                process.hasByteCounters
                    ? formatData(process.downloadTotal + process.uploadTotal)
                    : 'нет данных',
                AppColors.text))
      ]));
  Widget _metric(String label, String value, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12))
      ]);
}
