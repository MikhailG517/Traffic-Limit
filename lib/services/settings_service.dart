import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings(
      {this.autostart = false,
      this.traySpeed = true,
      this.limitNotifications = false,
      this.paused = false,
      this.limitsEnabled = false,
      this.autoPauseAtLimit = true,
      this.themeMode = 'dark',
      this.downloadLimit = 10,
      this.uploadLimit = 10,
      this.dailyLimit = 10,
      this.monthlyLimit = 10});
  final bool autostart;
  final bool traySpeed;
  final bool limitNotifications;
  final bool paused;
  final bool limitsEnabled;
  final bool autoPauseAtLimit;
  final String themeMode;
  final double downloadLimit;
  final double uploadLimit;
  final double dailyLimit;
  final double monthlyLimit;

  AppSettings copyWith(
          {bool? autostart,
          bool? traySpeed,
          bool? limitNotifications,
          bool? paused,
          bool? limitsEnabled,
          bool? autoPauseAtLimit,
          String? themeMode,
          double? downloadLimit,
          double? uploadLimit,
          double? dailyLimit,
          double? monthlyLimit}) =>
      AppSettings(
        autostart: autostart ?? this.autostart,
        traySpeed: traySpeed ?? this.traySpeed,
        limitNotifications: limitNotifications ?? this.limitNotifications,
        paused: paused ?? this.paused,
        limitsEnabled: limitsEnabled ?? this.limitsEnabled,
        autoPauseAtLimit: autoPauseAtLimit ?? this.autoPauseAtLimit,
        themeMode: themeMode ?? this.themeMode,
        downloadLimit: downloadLimit ?? this.downloadLimit,
        uploadLimit: uploadLimit ?? this.uploadLimit,
        dailyLimit: dailyLimit ?? this.dailyLimit,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      );
}

class SettingsService {
  SettingsService(this._preferences);
  final SharedPreferences _preferences;

  AppSettings load() => AppSettings(
        autostart: _preferences.getBool('autostart') ?? false,
        traySpeed: _preferences.getBool('traySpeed') ?? true,
        limitNotifications: _preferences.getBool('limitNotifications') ?? false,
        paused: _preferences.getBool('paused') ?? false,
        limitsEnabled: _preferences.getBool('limitsEnabled') ?? false,
        autoPauseAtLimit: _preferences.getBool('autoPauseAtLimit') ?? true,
        themeMode: _preferences.getString('themeMode') ?? 'dark',
        downloadLimit: _preferences.getDouble('downloadLimit') ?? 10,
        uploadLimit: _preferences.getDouble('uploadLimit') ?? 10,
        dailyLimit: _preferences.getDouble('dailyLimit') ?? 10,
        monthlyLimit: _preferences.getDouble('monthlyLimit') ?? 10,
      );

  Future<void> save(AppSettings value) async {
    await Future.wait([
      _preferences.setBool('autostart', value.autostart),
      _preferences.setBool('traySpeed', value.traySpeed),
      _preferences.setBool('limitNotifications', value.limitNotifications),
      _preferences.setBool('paused', value.paused),
      _preferences.setBool('limitsEnabled', value.limitsEnabled),
      _preferences.setBool('autoPauseAtLimit', value.autoPauseAtLimit),
      _preferences.setString('themeMode', value.themeMode),
      _preferences.setDouble('downloadLimit', value.downloadLimit),
      _preferences.setDouble('uploadLimit', value.uploadLimit),
      _preferences.setDouble('dailyLimit', value.dailyLimit),
      _preferences.setDouble('monthlyLimit', value.monthlyLimit),
    ]);
  }
}
