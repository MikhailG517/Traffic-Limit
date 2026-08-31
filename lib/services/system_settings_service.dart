import 'dart:io';

class SystemSettingsService {
  Future<bool> setAutostart(bool enabled) async {
    if (!Platform.isWindows) return false;
    const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
    try {
      final result = enabled
          ? await Process.run('reg.exe', [
              'ADD',
              key,
              '/v',
              'TrafficLimit',
              '/t',
              'REG_SZ',
              '/d',
              Platform.resolvedExecutable,
              '/f'
            ])
          : await Process.run(
              'reg.exe', ['DELETE', key, '/v', 'TrafficLimit', '/f']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
