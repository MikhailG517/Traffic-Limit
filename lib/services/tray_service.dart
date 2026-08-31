import 'dart:async';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../models/traffic_models.dart';

class TrayService with TrayListener {
  bool _limitsEnabled = false;
  Future<void> Function()? onEnableLimitsCallback;
  Future<void> Function()? onDisableLimitsCallback;
  Future<void> Function()? onQuitCallback;

  Future<void> initialize({
    required Future<void> Function() onEnableLimits,
    required Future<void> Function() onDisableLimits,
    required Future<void> Function() onQuit,
  }) async {
    onEnableLimitsCallback = onEnableLimits;
    onDisableLimitsCallback = onDisableLimits;
    onQuitCallback = onQuit;
    trayManager.addListener(this);
    // tray_manager resolves this relative asset to data/flutter_assets itself.
    // Passing an absolute path makes older Windows plugin versions build an
    // invalid nested path and leaves the tray icon invisible.
    await trayManager.setIcon('assets/traffic_limit.ico');
    await trayManager
        .setToolTip('Traffic Limit · загрузка 0 Кбит/с · отдача 0 Кбит/с');
    await _refreshMenu();
  }

  static Menu menuFor(bool limitsEnabled) => Menu(items: [
        MenuItem(key: 'show', label: 'Открыть Traffic Limit'),
        MenuItem.separator(),
        MenuItem(
            key: 'limit-status',
            label: limitsEnabled
                ? 'Ограничение скорости: включено'
                : 'Ограничение скорости: выключено',
            disabled: true),
        MenuItem(
            key: 'enable-limits',
            label: 'Включить ограничение скорости',
            disabled: limitsEnabled),
        MenuItem(
            key: 'disable-limits',
            label: 'Отключить ограничение скорости',
            disabled: !limitsEnabled),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Завершить приложение'),
      ]);

  Future<void> setLimitsEnabled(bool enabled) async {
    if (_limitsEnabled == enabled) return;
    _limitsEnabled = enabled;
    await _refreshMenu();
  }

  Future<void> _refreshMenu() =>
      trayManager.setContextMenu(menuFor(_limitsEnabled));

  Future<void> update(double download, double upload,
          {required bool showSpeed}) =>
      trayManager.setToolTip(showSpeed
          ? 'Traffic Limit · ↓ ${formatRate(download)} · ↑ ${formatRate(upload)}'
          : 'Traffic Limit');

  @override
  void onTrayIconMouseDown() => unawaited(windowManager.show());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(windowManager.show());
      case 'enable-limits':
        unawaited(onEnableLimitsCallback?.call());
      case 'disable-limits':
        unawaited(onDisableLimitsCallback?.call());
      case 'quit':
        unawaited(onQuitCallback?.call());
    }
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
