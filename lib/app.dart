import 'package:flutter/material.dart';
import 'models/traffic_models.dart';
import 'pages/dashboard_page.dart';
import 'pages/graphs_page.dart';
import 'pages/limits_page.dart';
import 'pages/settings_page.dart';
import 'services/logger_service.dart';
import 'services/settings_service.dart';
import 'services/traffic_service.dart';
import 'services/tray_service.dart';
import 'theme.dart';

class TrafficLimitApp extends StatefulWidget {
  const TrafficLimitApp(
      {super.key,
      required this.settings,
      required this.logger,
      required this.traffic,
      required this.tray});
  final SettingsService settings;
  final LoggerService logger;
  final TrafficService traffic;
  final TrayService tray;
  @override
  State<TrafficLimitApp> createState() => _TrafficLimitAppState();
}

class _TrafficLimitAppState extends State<TrafficLimitApp> {
  late AppSettings appSettings;
  TrafficStats stats = const TrafficStats();
  int selected = 0;
  @override
  void initState() {
    super.initState();
    appSettings = widget.settings.load();
    widget.traffic.start(() {
      if (mounted) setState(() => stats = widget.traffic.stats);
      widget.tray.update(
          widget.traffic.stats.downloadRate, widget.traffic.stats.uploadRate);
    });
  }

  @override
  void dispose() {
    widget.traffic.dispose();
    super.dispose();
  }

  Future<void> updateSettings(AppSettings value) async {
    setState(() => appSettings = value);
    await widget.settings.save(value);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Traffic Limit',
      theme: appTheme,
      home: Scaffold(
          body: SafeArea(
              child: Row(children: [
        NavigationRailPanel(
            selected: selected,
            used: stats.downloadTotal + stats.uploadTotal,
            monthlyLimit: appSettings.monthlyLimit,
            onSelected: (value) => setState(() => selected = value)),
        Expanded(child: _page())
      ]))));
  Widget _page() {
    switch (selected) {
      case 1:
        return GraphsPage(traffic: widget.traffic, stats: stats);
      case 2:
        return LimitsPage(
            settings: appSettings,
            onChanged: updateSettings,
            traffic: widget.traffic);
      case 3:
        return SettingsPage(
            settings: appSettings,
            onChanged: updateSettings,
            logger: widget.logger);
      default:
        return DashboardPage(
            stats: stats,
            service: widget.traffic,
            settings: appSettings,
            onSettingsChanged: updateSettings);
    }
  }
}

class NavigationRailPanel extends StatelessWidget {
  const NavigationRailPanel(
      {super.key,
      required this.selected,
      required this.onSelected,
      required this.used,
      required this.monthlyLimit});
  final int selected;
  final double used, monthlyLimit;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
      width: 242,
      color: AppColors.panel,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blue,
                  boxShadow: [
                    BoxShadow(color: AppColors.blue, blurRadius: 12)
                  ])),
          const SizedBox(width: 12),
          const Text('Traffic Limit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))
        ]),
        const SizedBox(height: 42),
        ...['Обзор', 'Графики', 'Ограничения', 'Настройки']
            .asMap()
            .entries
            .map((entry) => _item(context, entry.key, entry.value)),
        const Spacer(),
        MonthlyUsage(used: used, limit: monthlyLimit),
      ]));
  Widget _item(BuildContext context, int index, String label) => InkWell(
      onTap: () => onSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color:
                  selected == index ? AppColors.selected : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected == index
                  ? const Border(
                      left: BorderSide(color: AppColors.cyan, width: 3))
                  : null),
          child: Row(children: [
            Icon(
                [
                  Icons.home_outlined,
                  Icons.bar_chart_rounded,
                  Icons.speed_rounded,
                  Icons.tune_rounded
                ][index],
                size: 19,
                color: selected == index ? AppColors.cyan : AppColors.muted),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: selected == index ? Colors.white : AppColors.muted,
                    fontWeight:
                        selected == index ? FontWeight.w700 : FontWeight.w500))
          ])));
}

class MonthlyUsage extends StatelessWidget {
  const MonthlyUsage({super.key, required this.used, required this.limit});
  final double used;
  final double limit;
  @override
  Widget build(BuildContext context) {
    final progress = limit <= 0 ? 0.0 : (used / (limit * 1024)).clamp(0.0, 1.0);
    return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ЛИМИТ МЕСЯЦА',
              style: TextStyle(
                  color: AppColors.lightBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 13),
          LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xff29303d),
              valueColor: const AlwaysStoppedAnimation(AppColors.cyan)),
          const SizedBox(height: 11),
          Text.rich(TextSpan(
              text: formatData(used),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
              children: [
                TextSpan(
                    text: ' из ${limit.toStringAsFixed(0)} ГБ',
                    style: const TextStyle(
                        color: AppColors.muted, fontWeight: FontWeight.w400))
              ])),
        ]));
  }
}
