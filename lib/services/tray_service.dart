import 'dart:async';
import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../models/traffic_models.dart';

class TrayService with TrayListener {
  Future<void> initialize(
      {required void Function() onShow,
      required void Function() onPause,
      required Future<void> Function() onQuit}) async {
    onPauseCallback = onPause;
    onQuitCallback = onQuit;
    trayManager.addListener(this);
    final base = File(Platform.resolvedExecutable).parent.path;
    final icons = [
      File(
          '$base${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}traffic_limit.ico'),
      File(
          '$base${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}traffic_limit.png'),
    ];
    for (final icon in icons) {
      if (icon.existsSync()) {
        await trayManager.setIcon(icon.path);
        break;
      }
    }
    await trayManager
        .setToolTip('Traffic Limit · загрузка 0 Кбит/с · отдача 0 Кбит/с');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Открыть Traffic Limit'),
      MenuItem.separator(),
      MenuItem(key: 'pause', label: 'Пауза ограничений'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Завершить приложение')
    ]));
  }

  Future<void> update(double download, double upload,
          {required bool showSpeed}) =>
      trayManager.setToolTip(showSpeed
          ? 'Traffic Limit · ↓ ${formatRate(download)} · ↑ ${formatRate(upload)}'
          : 'Traffic Limit');
  @override
  void onTrayIconMouseDown() => windowManager.show();
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') unawaited(windowManager.show());
    if (menuItem.key == 'pause') onPauseCallback?.call();
    if (menuItem.key == 'quit') unawaited(onQuitCallback?.call());
  }

  void Function()? onPauseCallback;
  Future<void> Function()? onQuitCallback;
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
