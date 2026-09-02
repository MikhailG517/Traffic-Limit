import 'dart:async';
import 'package:flutter/material.dart';
import '../models/traffic_models.dart';
import '../services/traffic_service.dart';
import '../services/process_sort.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key, required this.traffic});
  final TrafficService traffic;
  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  String status = 'Проверка…';
  Timer? _statusTimer;
  ProcessSortColumn _sort = ProcessSortColumn.total;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _statusTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final result = await widget.traffic.nativeTelemetryStatus();
    if (mounted) setState(() => status = result);
  }

  void _toggleSort(ProcessSortColumn column) {
    setState(() {
      if (_sort == column) {
        _ascending = !_ascending;
      } else {
        _sort = column;
        _ascending = column == ProcessSortColumn.name;
      }
    });
  }

  List<ProcessTraffic> get _sorted =>
      sortProcesses(widget.traffic.processes, _sort, ascending: _ascending);

  Widget _header(String label, ProcessSortColumn column, Alignment alignment) =>
      Expanded(
          child: InkWell(
              onTap: () => _toggleSort(column),
              child: Container(
                  alignment: alignment,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                      mainAxisAlignment: alignment == Alignment.centerLeft
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (alignment != Alignment.centerLeft) const Spacer(),
                        Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12)),
                        const SizedBox(width: 3),
                        if (_sort == column)
                          Icon(
                              _ascending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 13,
                              color: AppColors.blue)
                      ]))));

  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Приложения',
      action: const LivePill(),
      child: SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Активные сетевые соединения',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          Text(status,
              style: const TextStyle(color: AppColors.muted, fontSize: 12))
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _header('Приложение', ProcessSortColumn.name, Alignment.centerLeft),
          _header(
              '↓ Загрузка', ProcessSortColumn.download, Alignment.centerRight),
          _header('↑ Отдача', ProcessSortColumn.upload, Alignment.centerRight),
          _header('Входящий', ProcessSortColumn.downloadTotal,
              Alignment.centerRight),
          _header('Исходящий', ProcessSortColumn.uploadTotal,
              Alignment.centerRight),
          _header('Всего', ProcessSortColumn.total, Alignment.centerRight),
        ]),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 4),
        Expanded(
            child: _sorted.isEmpty
                ? const Center(
                    child: Text('Активных соединений нет',
                        style: TextStyle(color: AppColors.muted)))
                : ListView.separated(
                    itemCount: _sorted.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (_, index) => _row(_sorted[index]))),
      ])));

  Widget _row(ProcessTraffic process) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
            child: Row(children: [
          CircleAvatar(
              radius: 15,
              backgroundColor: Color(process.color),
              child: Text(process.name[0].toUpperCase())),
          const SizedBox(width: 10),
          Flexible(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(process.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('PID ${process.pid} · ${process.connections}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11))
              ]))
        ])),
        _metric(formatRate(process.download), AppColors.green),
        _metric(formatRate(process.upload), AppColors.red),
        _metric(
            process.hasByteCounters
                ? formatData(process.downloadTotal)
                : 'нет данных',
            AppColors.green),
        _metric(
            process.hasByteCounters
                ? formatData(process.uploadTotal)
                : 'нет данных',
            AppColors.red),
        _metric(
            process.hasByteCounters
                ? formatData(process.downloadTotal + process.uploadTotal)
                : 'нет данных',
            AppColors.blue),
      ]));

  Widget _metric(String value, Color color) => Expanded(
      child: Text(value,
          textAlign: TextAlign.right,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)));
}
