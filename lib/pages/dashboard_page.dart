import 'package:flutter/material.dart';
import '../models/traffic_models.dart';
import '../services/settings_service.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {super.key,
      required this.stats,
      required this.service,
      required this.settings,
      required this.onSettingsChanged});
  final TrafficStats stats;
  final TrafficService service;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Трафик в реальном времени',
      action: const LivePill(),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: _trafficCard(
                  'ЗАГРУЗКА',
                  formatRate(stats.downloadRate),
                  AppColors.green,
                  Icons.arrow_downward_rounded,
                  service.samples.map((e) => e.download).toList())),
          const SizedBox(width: 16),
          Expanded(
              child: _trafficCard(
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
                  label: 'Сессия · входящий',
                  value: formatData(stats.downloadTotal),
                  color: AppColors.green,
                  icon: Icons.download_rounded,
                  subtitle: '↑ ${formatData(stats.uploadTotal)} исходящего')),
        ]),
        const SizedBox(height: 18),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _interfaces()),
          const SizedBox(width: 16),
          Expanded(child: _processes())
        ]),
        const SizedBox(height: 4),
      ]));
  Widget _trafficCard(String label, String rate, Color color, IconData icon,
          List<double> values) =>
      Card(
          child: Container(
              height: 195,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                      colors: [AppColors.card, color.withOpacity(.10)])),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: color.withOpacity(.14),
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
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    SizedBox(
                        height: 42,
                        child: CustomPaint(
                            painter: SparklinePainter(values, color)))
                  ])));
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
  Widget _processes() {
    final rows = <Widget>[];
    for (var index = 0; index < service.processes.length; index += 2) {
      rows.add(Row(children: [
        Expanded(child: _processTile(service.processes[index])),
        const SizedBox(width: 12),
        Expanded(
            child: index + 1 < service.processes.length
                ? _processTile(service.processes[index + 1])
                : const SizedBox()),
      ]));
    }
    return SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Приложения',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ...rows,
    ]));
  }

  Widget _processTile(ProcessTraffic process) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
          radius: 16,
          backgroundColor: Color(process.color),
          child: Text(process.name[0].toUpperCase())),
      title: Text(process.name,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('PID ${process.pid}',
          style: const TextStyle(color: AppColors.muted)),
      trailing: Text(
          '↓ ${formatRate(process.download)} ↑ ${formatRate(process.upload)}',
          style: const TextStyle(color: AppColors.red, fontSize: 11)));
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
