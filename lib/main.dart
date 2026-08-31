import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/launch_options.dart';
import 'services/logger_service.dart';
import 'services/settings_service.dart';
import 'services/tray_service.dart';
import 'services/system_settings_service.dart';
import 'services/traffic_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  final launch = LaunchOptions(Platform.executableArguments);
  const options = WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(980, 680),
      center: true,
      title: 'Traffic Limit');
  await windowManager.waitUntilReadyToShow(options, () async {
    if (!launch.startHidden) {
      await windowManager.show();
      await windowManager.focus();
    }
  });
  await windowManager.setPreventClose(true);
  final preferences = await SharedPreferences.getInstance();
  final logger = LoggerService();
  final tray = TrayService();
  runApp(TrafficLimitApp(
      settings: SettingsService(preferences),
      logger: logger,
      system: SystemSettingsService(),
      traffic: TrafficService(logger, preferences),
      tray: tray,
      startHidden: launch.startHidden));
}
