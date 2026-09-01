import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'models/traffic_models.dart';
import 'pages/dashboard_page.dart';
import 'pages/graphs_page.dart';
import 'pages/applications_page.dart';
import 'pages/limits_page.dart';
import 'pages/settings_page.dart';
import 'services/logger_service.dart';
import 'services/settings_service.dart';
import 'services/system_settings_service.dart';
import 'services/traffic_service.dart';
import 'services/tray_service.dart';
import 'theme.dart';

class TrafficLimitApp extends StatefulWidget {
  const TrafficLimitApp(
      {super.key,
      required this.settings,
      required this.logger,
      required this.system,
      required this.traffic,
      required this.tray,
      required this.startHidden});
  final SettingsService settings;
  final LoggerService logger;
  final SystemSettingsService system;
  final TrafficService traffic;
  final TrayService tray;
  final bool startHidden;
  @override
  State<TrafficLimitApp> createState() => _TrafficLimitAppState();
}

const int kOverviewIndex = 0;
const int kGraphsIndex = 1;
const int kApplicationsIndex = 2;
const int kLimitsIndex = 3;
const int kSettingsIndex = 4;

class _TrafficLimitAppState extends State<TrafficLimitApp> with WindowListener {
  late AppSettings appSettings;
  TrafficStats stats = const TrafficStats();
  int selected = 0;
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    appSettings = widget.settings.load();
    unawaited(_initializeTray());
    _syncAutostart();
    widget.traffic.start(() {
      if (!mounted) return;
      final current = widget.traffic.stats;
      setState(() => stats = current);
      widget.tray.update(current.downloadRate, current.uploadRate,
          showSpeed: appSettings.traySpeed);
      if (appSettings.limitsEnabled &&
          appSettings.autoPauseAtLimit &&
          widget.traffic.monthlyTotal >= appSettings.monthlyLimit * 1024) {
        unawaited(_setLimitsFromTray(false));
      }
    });
    if (appSettings.limitsEnabled) _restoreLimit();
  }

  Future<void> _initializeTray() async {
    await widget.tray.initialize(
        onEnableLimits: () => _setLimitsFromTray(true),
        onDisableLimits: () => _setLimitsFromTray(false),
        onQuit: _exitApp);
    await widget.tray.setLimitsEnabled(appSettings.limitsEnabled);
  }

  Future<void> _restoreLimit() async {
    var applied = false;
    for (var attempt = 0; attempt < 5 && !applied; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      applied = await widget.traffic
          .applyLimit(appSettings.downloadLimit, appSettings.uploadLimit);
    }
    if (!mounted || applied) return;
    await updateSettings(appSettings.copyWith(limitsEnabled: false));
  }

  Future<void> _syncAutostart() async {
    final enabled = await widget.system.isAutostartEnabled();
    if (!mounted || enabled == null) return;
    if (appSettings.autostart && enabled) {
      await widget.system.setAutostart(true);
      return;
    }
    if (enabled != appSettings.autostart) {
      await updateSettings(appSettings.copyWith(autostart: enabled));
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.traffic.dispose();
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
  }

  Future<void> _exitApp() async {
    widget.traffic.dispose();
    await widget.tray.dispose();
    await windowManager.destroy();
    exit(0);
  }

  Future<void> _setLimitsFromTray(bool enabled) async {
    if (appSettings.limitsEnabled == enabled) return;
    final applied = await widget.traffic.setLimitsEnabled(
        enabled, appSettings.downloadLimit, appSettings.uploadLimit);
    if (applied) {
      await updateSettings(appSettings.copyWith(limitsEnabled: enabled));
    }
  }

  Future<void> updateSettings(AppSettings value) async {
    final changed = value.limitsEnabled != appSettings.limitsEnabled;
    setState(() => appSettings = value);
    await widget.settings.save(value);
    if (changed) await widget.tray.setLimitsEnabled(value.limitsEnabled);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Traffic Limit',
      theme: lightTheme,
      darkTheme: appTheme,
      themeMode:
          appSettings.themeMode == 'light' ? ThemeMode.light : ThemeMode.dark,
      home: Scaffold(
          body: SafeArea(
              child: Column(children: [
        const WindowTitleBar(),
        Expanded(
            child: Row(children: [
          NavigationRailPanel(
              selected: selected,
              used: widget.traffic.monthlyTotal,
              monthlyLimit: appSettings.monthlyLimit,
              onSelected: (value) => setState(() => selected = value)),
          Expanded(child: _page())
        ]))
      ]))));
  Widget _page() {
    switch (selected) {
      case 1:
        return GraphsPage(traffic: widget.traffic, stats: stats);
      case 2:
        return ApplicationsPage(traffic: widget.traffic);
      case 3:
        return LimitsPage(
            settings: appSettings,
            onChanged: updateSettings,
            traffic: widget.traffic);
      case 4:
        return SettingsPage(
            settings: appSettings,
            onChanged: updateSettings,
            system: widget.system,
            onExit: _exitApp);
      default:
        return DashboardPage(stats: stats, service: widget.traffic);
    }
  }
}

class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key});

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> {
  bool maximized = false;

  Future<void> _toggleMaximize() async {
    maximized = await windowManager.isMaximized();
    if (maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    if (mounted) setState(() => maximized = !maximized);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
        height: 42,
        child: Row(children: [
          Expanded(
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _toggleMaximize,
                  onPanStart: (_) => windowManager.startDragging(),
                  child: Row(children: [
                    const SizedBox(width: 16),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset('assets/traffic_limit.png',
                            width: 22, height: 22, fit: BoxFit.cover)),
                    const SizedBox(width: 10),
                    Text('Traffic Limit',
                        style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700))
                  ]))),
          _WindowButton(icon: Icons.remove, onPressed: windowManager.minimize),
          _WindowButton(
              icon: maximized ? Icons.filter_none : Icons.crop_square,
              onPressed: _toggleMaximize),
          _WindowButton(
              icon: Icons.close,
              onPressed: windowManager.hide,
              hoverColor: Colors.red),
          const SizedBox(width: 8)
        ]));
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton(
      {required this.icon, required this.onPressed, this.hoverColor});
  final IconData icon;
  final Future<void> Function() onPressed;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) => IconButton(
      splashRadius: 18,
      tooltip: icon == Icons.close ? 'Скрыть' : 'Управление окном',
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .62),
      hoverColor: (hoverColor ?? Theme.of(context).colorScheme.primary)
          .withValues(alpha: .16));
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
        width: 242,
        color: scheme.surface,
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 42),
          ...['Обзор', 'Графики', 'Приложения', 'Ограничения', 'Настройки']
              .asMap()
              .entries
              .map((entry) => _item(context, entry.key, entry.value)),
          const Spacer(),
          MonthlyUsage(
              used: used,
              limit: monthlyLimit,
              onTap: () => onSelected(kLimitsIndex)),
        ]));
  }

  Widget _item(BuildContext context, int index, String label) => InkWell(
      onTap: () => onSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: selected == index
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
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
                  Icons.apps_rounded,
                  Icons.speed_rounded,
                  Icons.tune_rounded
                ][index],
                size: 19,
                color: selected == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .58)),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: selected == index
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .68),
                    fontWeight:
                        selected == index ? FontWeight.w700 : FontWeight.w500))
          ])));
}

class MonthlyUsage extends StatelessWidget {
  const MonthlyUsage(
      {super.key,
      required this.used,
      required this.limit,
      required this.onTap});
  final double used;
  final double limit;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final progress = limit <= 0 ? 0.0 : (used / (limit * 1024)).clamp(0.0, 1.0);
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ЛИМИТ МЕСЯЦА',
                  style: TextStyle(
                      color: AppColors.lightBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 13),
              LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: const AlwaysStoppedAnimation(AppColors.cyan)),
              const SizedBox(height: 11),
              Text.rich(TextSpan(
                  text: formatData(used),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700),
                  children: [
                    TextSpan(
                        text: ' из ${limit.toStringAsFixed(0)} ГБ',
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w400))
                  ])),
            ])));
  }
}
