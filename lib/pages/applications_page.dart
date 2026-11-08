import 'dart:math' as math;
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

  Widget _header(String label, ProcessSortColumn column, Alignment alignment,
          {int flex = 1}) =>
      Expanded(
          flex: flex,
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
                        Text(label.toUpperCase(),
                            style: TextStyle(
                                color: _sort == column
                                    ? Palette.of(context).text
                                    : Palette.of(context).muted,
                                letterSpacing: .8,
                                fontWeight: FontWeight.w800,
                                fontSize: 10)),
                        const SizedBox(width: 3),
                        if (_sort == column)
                          Icon(
                              _ascending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 13,
                              color: AppColors.cyan)
                      ]))));

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final rows = _sorted;
    final peak = rows.fold<double>(
        1, (m, p) => math.max(m, p.downloadTotal + p.uploadTotal));
    return PageShell(
        title: 'Приложения',
        subtitle: 'Процессы с активными сетевыми соединениями',
        action: LivePill(
            active: status == 'Активно',
            label: status == 'Активно' ? 'ТЕЛЕМЕТРИЯ' : status.toUpperCase()),
        child: GlassCard(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _header(
                    'Приложение', ProcessSortColumn.name, Alignment.centerLeft,
                    flex: 3),
                _header('↓ Скорость', ProcessSortColumn.download,
                    Alignment.centerRight),
                _header('↑ Скорость', ProcessSortColumn.upload,
                    Alignment.centerRight),
                _header('Входящий', ProcessSortColumn.downloadTotal,
                    Alignment.centerRight),
                _header('Исходящий', ProcessSortColumn.uploadTotal,
                    Alignment.centerRight),
                _header(
                    'Всего', ProcessSortColumn.total, Alignment.centerRight),
              ]),
              Divider(color: palette.border, height: 1),
              Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text('Активных соединений нет',
                              style: TextStyle(color: palette.muted)))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (_, index) =>
                              _row(rows[index], peak, index))),
            ])));
  }

  Widget _row(ProcessTraffic process, double peak, int index) {
    final palette = Palette.of(context);
    final total = process.downloadTotal + process.uploadTotal;
    final hue = _hues[process.name.hashCode.abs() % _hues.length];
    return TweenAnimationBuilder<double>(
        key: ValueKey(process.pid),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 250 + math.min(index, 12) * 40),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, (1 - t) * 10), child: child)),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border))),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Row(children: [
                    Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(colors: [
                              hue,
                              Color.lerp(hue, AppColors.violet, .5)!
                            ])),
                        child: Text(process.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800))),
                    const SizedBox(width: 12),
                    Flexible(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(process.name,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Row(children: [
                            Text(
                                'PID ${process.pid} · ${process.connections} соед.',
                                style: TextStyle(
                                    color: palette.muted, fontSize: 11)),
                            const SizedBox(width: 10),
                            if (process.hasByteCounters)
                              Expanded(
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                          value: total / peak,
                                          minHeight: 4,
                                          backgroundColor: palette.cardHigh,
                                          valueColor:
                                              AlwaysStoppedAnimation(hue)))),
                          ]),
                        ])),
                    const SizedBox(width: 16),
                  ])),
              _metric(formatRate(process.download), AppColors.download),
              _metric(formatRate(process.upload), AppColors.upload),
              _metric(
                  process.hasByteCounters
                      ? formatData(process.downloadTotal)
                      : 'нет данных',
                  AppColors.download),
              _metric(
                  process.hasByteCounters
                      ? formatData(process.uploadTotal)
                      : 'нет данных',
                  AppColors.upload),
              _metric(
                  process.hasByteCounters ? formatData(total) : 'нет данных',
                  palette.text),
            ])));
  }

  static const _hues = [
    AppColors.cyan,
    AppColors.blue,
    AppColors.violet,
    AppColors.green,
    AppColors.amber,
    AppColors.red,
  ];

  Widget _metric(String value, Color color) => Expanded(
      child: Text(value,
          textAlign: TextAlign.right,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()])));
}
