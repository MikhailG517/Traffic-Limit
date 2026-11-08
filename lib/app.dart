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
import 'widgets/ambient_clock.dart';
import 'widgets/animated_brand.dart';
import 'widgets/common.dart';

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
    // The app starts hidden in the tray; the window events turn the
    // decorative animations on when it is shown.
    AmbientClock.instance.setWindowState(visible: !widget.startHidden);
    appSettings = widget.settings.load();
    widget.logger.setDiagnostics(appSettings.diagnostics);
    widget.logger.info('Приложение запущено', params: {
      'startHidden': widget.startHidden,
      'diagnostics': appSettings.diagnostics
    });
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
        onQuit: _exitApp,
        onToggleDiagnostics: _toggleDiagnostics,
        onOpenLogs: widget.logger.openLogFolder);
    await widget.tray.setLimitsEnabled(appSettings.limitsEnabled);
    widget.tray.setDiagnostics(appSettings.diagnostics);
  }

  Future<void> _toggleDiagnostics() async {
    final value = !appSettings.diagnostics;
    await updateSettings(appSettings.copyWith(diagnostics: value));
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
    unawaited(widget.traffic.dispose());
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onWindowEvent(String eventName) {
    final clock = AmbientClock.instance;
    switch (eventName) {
      case 'show' || 'restore':
        clock.setWindowState(visible: true);
      case 'hide' || 'minimize':
        clock.setWindowState(visible: false);
      case 'focus':
        clock.setWindowState(focused: true);
      case 'blur':
        clock.setWindowState(focused: false);
    }
  }

  Future<void> _exitApp() async {
    await widget.traffic.dispose();
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
    final diagChanged = value.diagnostics != appSettings.diagnostics;
    setState(() => appSettings = value);
    await widget.settings.save(value);
    if (diagChanged) {
      widget.logger.setDiagnostics(value.diagnostics);
      await widget.logger
          .info('Диагностика ${value.diagnostics ? 'включена' : 'выключена'}');
    }
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
          backgroundColor: Colors.transparent,
          body: AuroraBackground(
              child: Row(children: [
            NavigationRailPanel(
                selected: selected,
                used: widget.traffic.monthlyTotal,
                monthlyLimit: appSettings.monthlyLimit,
                limitsEnabled: appSettings.limitsEnabled,
                onSelected: (value) => setState(() => selected = value)),
            Expanded(
                child: Column(children: [
              const WindowTitleBar(),
              Expanded(
                  child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                              position: Tween(
                                      begin: const Offset(.015, 0),
                                      end: Offset.zero)
                                  .animate(animation),
                              child: child)),
                      child: KeyedSubtree(
                          key: ValueKey(selected), child: _page())))
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
            logger: widget.logger,
            onExit: _exitApp);
      default:
        return DashboardPage(
            stats: stats,
            service: widget.traffic,
            monthlyLimitGb: appSettings.monthlyLimit,
            onOpenLimits: () => setState(() => selected = kLimitsIndex));
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
  Widget build(BuildContext context) => SizedBox(
      height: 40,
      child: Row(children: [
        Expanded(
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _toggleMaximize,
                onPanStart: (_) => windowManager.startDragging())),
        _WindowButton(
            icon: Icons.remove_rounded,
            tooltip: 'Свернуть',
            onPressed: windowManager.minimize),
        _WindowButton(
            icon: maximized
                ? Icons.filter_none_rounded
                : Icons.crop_square_rounded,
            tooltip: maximized ? 'Восстановить' : 'Развернуть',
            onPressed: _toggleMaximize),
        _WindowButton(
            icon: Icons.close_rounded,
            tooltip: 'Скрыть в трей',
            onPressed: windowManager.hide,
            hoverColor: AppColors.red),
        const SizedBox(width: 6)
      ]));
}

class _WindowButton extends StatelessWidget {
  const _WindowButton(
      {required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.hoverColor});
  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      color: Palette.of(context).muted,
      hoverColor: (hoverColor ?? AppColors.blue).withValues(alpha: .18));
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _navItems = [
  _NavItem('Обзор', Icons.space_dashboard_rounded),
  _NavItem('Графики', Icons.insights_rounded),
  _NavItem('Приложения', Icons.apps_rounded),
  _NavItem('Ограничения', Icons.speed_rounded),
  _NavItem('Настройки', Icons.tune_rounded),
];

class NavigationRailPanel extends StatelessWidget {
  const NavigationRailPanel(
      {super.key,
      required this.selected,
      required this.onSelected,
      required this.used,
      required this.monthlyLimit,
      required this.limitsEnabled});
  final int selected;
  final double used, monthlyLimit;
  final bool limitsEnabled;
  final ValueChanged<int> onSelected;

  static const _itemHeight = 48.0;
  static const _itemGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Container(
        width: 236,
        decoration: BoxDecoration(
            color: palette.card.withValues(alpha: .55),
            border: Border(right: BorderSide(color: palette.border))),
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => windowManager.startDragging(),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 26),
                  child: Row(children: [
                    const AnimatedLogo(size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          ShaderMask(
                              shaderCallback: (rect) =>
                                  AppColors.brandGradient.createShader(rect),
                              child: const Text('Traffic Limit',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.3))),
                          Text(limitsEnabled ? 'лимит активен' : 'мониторинг',
                              style: TextStyle(
                                  color: limitsEnabled
                                      ? AppColors.amber
                                      : palette.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ])),
                  ]))),
          SizedBox(
              height: _navItems.length * (_itemHeight + _itemGap),
              child: Stack(children: [
                AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    top: selected * (_itemHeight + _itemGap),
                    left: 0,
                    right: 0,
                    height: _itemHeight,
                    child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(colors: [
                              AppColors.blue.withValues(alpha: .28),
                              AppColors.violet.withValues(alpha: .10),
                            ]),
                            border: Border.all(
                                color: AppColors.blue.withValues(alpha: .35)),
                            boxShadow: [
                          BoxShadow(
                              color: AppColors.blue
                                  .withValues(alpha: .25 * palette.glow),
                              blurRadius: 18)
                        ]))),
                Column(children: [
                  for (var i = 0; i < _navItems.length; i++)
                    _item(context, i, _navItems[i]),
                ]),
              ])),
          const Spacer(),
          MonthlyUsage(
              used: used,
              limit: monthlyLimit,
              onTap: () => onSelected(kLimitsIndex)),
        ]));
  }

  Widget _item(BuildContext context, int index, _NavItem item) {
    final palette = Palette.of(context);
    final active = selected == index;
    return Padding(
        padding: const EdgeInsets.only(bottom: _itemGap),
        child: InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
                height: _itemHeight,
                child: Row(children: [
                  const SizedBox(width: 14),
                  Icon(item.icon,
                      size: 20, color: active ? AppColors.cyan : palette.muted),
                  const SizedBox(width: 14),
                  AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          color: active ? palette.text : palette.muted,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600),
                      child: Text(item.label)),
                ]))));
  }
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
    final palette = Palette.of(context);
    final progress = limit <= 0 ? 0.0 : (used / (limit * 1024)).clamp(0.0, 1.0);
    final color = progress >= 1
        ? AppColors.red
        : progress >= .8
            ? AppColors.amber
            : AppColors.cyan;
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: GlassCard(
            accent: color,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: palette.cardHigh,
                        valueColor: AlwaysStoppedAnimation(color)),
                    Text('${(progress * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                  ])),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('ЛИМИТ МЕСЯЦА',
                        style: TextStyle(
                            color: palette.muted,
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(formatData(used),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('из ${limit.toStringAsFixed(0)} ГБ',
                        style: TextStyle(color: palette.muted, fontSize: 11)),
                  ])),
            ])));
  }
}
