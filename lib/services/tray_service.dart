import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  Future<void> initialize(
      {required void Function() onShow,
      required void Function() onPause}) async {
    trayManager.addListener(this);
    final icon = File(
        '${Platform.resolvedExecutable.split(Platform.pathSeparator).sublist(0, Platform.resolvedExecutable.split(Platform.pathSeparator).length - 1).join(Platform.pathSeparator)}${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}traffic_limit.png');
    if (icon.existsSync()) await trayManager.setIcon(icon.path);
    await trayManager
        .setToolTip('Traffic Limit · загрузка 0 Кбит/с · отдача 0 Кбит/с');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Открыть Traffic Limit'),
      MenuItem.separator(),
      MenuItem(key: 'pause', label: 'Пауза ограничений'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Выход')
    ]));
  }

  Future<void> update(double download, double upload) => trayManager.setToolTip(
      'Traffic Limit · ↓ ${download.toStringAsFixed(1)} Кбит/с · ↑ ${upload.toStringAsFixed(1)} Кбит/с');
  @override
  void onTrayIconMouseDown() => windowManager.show();
  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (item.key == 'show') windowManager.show();
    if (item.key == 'pause') onPauseCallback?.call();
    if (item.key == 'quit') exit(0);
  }

  void Function()? onPauseCallback;
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
