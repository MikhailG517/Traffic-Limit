import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LoggerService {
  File? _file;
  Future<File> _logFile() async {
    if (_file != null) return _file!;
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    _file = File('${directory.path}${Platform.pathSeparator}traffic-limit.log');
    return _file!;
  }

  Future<void> info(String message) => _write('INFO', message);
  Future<void> error(String message) => _write('ERROR', message);
  Future<void> _write(String level, String message) async {
    try {
      await (await _logFile()).writeAsString(
          '${DateTime.now().toIso8601String()} [$level] $message\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  Future<String> read() async {
    try {
      return await (await _logFile()).readAsString();
    } catch (_) {
      return 'Лог пока пуст.';
    }
  }

  Future<String> export() async {
    final downloads = Directory(
        '${Platform.environment['USERPROFILE'] ?? '.'}${Platform.pathSeparator}Downloads');
    await downloads.create(recursive: true);
    final target = File(
        '${downloads.path}${Platform.pathSeparator}traffic-limit-${DateTime.now().millisecondsSinceEpoch}.log');
    await target.writeAsString(await read());
    return target.path;
  }
}
