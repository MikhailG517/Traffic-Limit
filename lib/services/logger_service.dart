import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warn, error }

class LoggerService {
  LoggerService({bool diagnostics = false}) : _diagnostics = diagnostics;

  bool _diagnostics;
  File? _file;
  final List<String> _buffer = [];
  static const _maxBuffer = 4000;

  bool get diagnostics => _diagnostics;
  void setDiagnostics(bool value) => _diagnostics = value;

  Future<File> _logFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    _file = File('${directory.path}${Platform.pathSeparator}traffic-limit.log');
    return _file!;
  }

  Future<Directory> logDirectory() async => (await _logFile()).parent;

  String _format(LogLevel level, String message, Map<String, Object?>? params,
      Object? error, StackTrace? stack) {
    final buffer = StringBuffer();
    buffer.writeln('${_timestamp()} [${_tag(level)}] $message');
    if (params != null && params.isNotEmpty) {
      buffer.writeln('    params: ${_safe(params)}');
    }
    if (error != null) buffer.writeln('    error: $error');
    if (stack != null) {
      buffer
          .writeln('    stack: ${stack.toString().replaceAll('\n', '\n    ')}');
    }
    return buffer.toString().trimRight();
  }

  String _timestamp() {
    final now = DateTime.now();
    String pad(int v) => v.toString().padLeft(2, '0');
    String ms(int v) => v.toString().padLeft(3, '0');
    return '${now.year}-${pad(now.month)}-${pad(now.day)} '
        '${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)}.${ms(now.millisecond)}';
  }

  String _tag(LogLevel level) => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO ',
        LogLevel.warn => 'WARN ',
        LogLevel.error => 'ERROR',
      };

  String _safe(Map<String, Object?> params) {
    const secrets = [
      'password',
      'token',
      'secret',
      'key',
      'credential',
      'auth',
      'apikey'
    ];
    final safe = <String, Object?>{};
    params.forEach((key, value) {
      final k = key.toLowerCase();
      safe[key] = secrets.any((s) => k.contains(s)) ? '<filtered>' : value;
    });
    return safe.toString();
  }

  Future<void> log(LogLevel level, String message,
      {Map<String, Object?>? params,
      Object? error,
      StackTrace? stack,
      bool force = false}) async {
    final line = _format(level, message, params, error, stack);
    if (_buffer.length >= _maxBuffer) _buffer.removeAt(0);
    _buffer.add(line);
    if (level == LogLevel.debug && !_diagnostics && !force) return;
    await _write(line);
  }

  Future<void> debug(String message,
          {Map<String, Object?>? params, bool force = false}) =>
      log(LogLevel.debug, message, params: params, force: force);
  Future<void> info(String message, {Map<String, Object?>? params}) =>
      log(LogLevel.info, message, params: params);
  Future<void> warn(String message,
          {Map<String, Object?>? params, Object? error, StackTrace? stack}) =>
      log(LogLevel.warn, message, params: params, error: error, stack: stack);
  Future<void> error(String message,
          {Map<String, Object?>? params, Object? error, StackTrace? stack}) =>
      log(LogLevel.error, message, params: params, error: error, stack: stack);

  Future<void> _write(String line) async {
    try {
      await (await _logFile()).writeAsString('$line\n', mode: FileMode.append);
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
    final content = await read();
    final downloads = Directory(
        '${Platform.environment['USERPROFILE'] ?? '.'}${Platform.pathSeparator}Downloads');
    await downloads.create(recursive: true);
    final target = File(
        '${downloads.path}${Platform.pathSeparator}traffic-limit-${DateTime.now().millisecondsSinceEpoch}.log');
    await target.writeAsString(content);
    return target.path;
  }

  Future<void> openLogFolder() async {
    if (!Platform.isWindows) return;
    try {
      await Process.start('explorer.exe', [(await logDirectory()).path]);
    } catch (_) {}
  }
}
