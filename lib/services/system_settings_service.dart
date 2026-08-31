import 'dart:io';

class SystemSettingsService {
  static const _key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'TrafficLimit';

  Future<bool?> isAutostartEnabled() async {
    if (!Platform.isWindows) return null;
    try {
      final result =
          await Process.run('reg.exe', ['QUERY', _key, '/v', _valueName]);
      return result.exitCode == 0;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setAutostart(bool enabled) async {
    if (!Platform.isWindows) return false;
    const key = _key;
    try {
      final result = enabled
          ? await Process.run('reg.exe', [
              'ADD',
              key,
              '/v',
              _valueName,
              '/t',
              'REG_SZ',
              '/d',
              '"${Platform.resolvedExecutable}" --autostart',
              '/f'
            ])
          : await Process.run(
              'reg.exe', ['DELETE', key, '/v', _valueName, '/f']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
