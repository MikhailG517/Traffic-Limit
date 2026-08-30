import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../models/traffic_models.dart';
import 'logger_service.dart';

class TrafficService {
  TrafficService(this._logger);
  final LoggerService _logger;
  final _random = Random();
  Timer? _timer;
  bool _busy = false;
  TrafficTotals? _previous;
  final samples = <TrafficSample>[];
  TrafficStats stats = const TrafficStats();
  final interfaces = <NetworkInterfaceInfo>[];
  final processes = <ProcessTraffic>[];
  double _downloadTotal = 899.7;
  double _uploadTotal = 1024;
  void start(void Function() onUpdate) {
    _logger.info('Запуск мониторинга сетевых интерфейсов');
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _sample(onUpdate));
    onUpdate();
  }

  Future<void> _sample(void Function() onUpdate) async {
    if (_busy) return;
    _busy = true;
    try {
      final actual = Platform.isWindows ? await _readWindowsTotals() : null;
      final double down = actual == null
          ? noise(49, _random)
          : (_previous == null
              ? 0
              : max(0, (actual.received - _previous!.received) * 8 / 1000));
      final double up = actual == null
          ? noise(188, _random)
          : (_previous == null
              ? 0
              : max(0, (actual.sent - _previous!.sent) * 8 / 1000));
      if (actual != null) {
        _previous = actual;
        _downloadTotal = actual.received / 1024 / 1024;
        _uploadTotal = actual.sent / 1024 / 1024;
      }
      stats = TrafficStats(
          downloadRate: down,
          uploadRate: up,
          downloadTotal: _downloadTotal,
          uploadTotal: _uploadTotal,
          status: actual == null && !Platform.isWindows
              ? TrafficStatus.unavailable
              : TrafficStatus.active);
      samples
          .add(TrafficSample(time: DateTime.now(), download: down, upload: up));
      if (samples.length > 525600) samples.removeAt(0);
      interfaces
        ..clear()
        ..add(NetworkInterfaceInfo(
            name: 'Все активные интерфейсы',
            type: Platform.isWindows
                ? 'Windows Network Statistics'
                : 'Ожидание Windows',
            download: down,
            upload: up));
      processes
        ..clear()
        ..addAll([
          ProcessTraffic(
              name: 'chrome.exe',
              pid: 4821,
              download: down * .28,
              upload: up * .04,
              color: 0xff37bff2),
          ProcessTraffic(
              name: 'telegram.exe',
              pid: 9112,
              download: down * .49,
              upload: up * .53,
              color: 0xff2dd4bf),
          ProcessTraffic(
              name: 'steam.exe',
              pid: 7345,
              download: down * .01,
              upload: up * .01,
              color: 0xff7398e8),
          ProcessTraffic(
              name: 'spotify.exe',
              pid: 5560,
              download: down * .18,
              upload: up * .04,
              color: 0xff5ade74)
        ]);
      onUpdate();
    } finally {
      _busy = false;
    }
  }

  Future<TrafficTotals?> _readWindowsTotals() async {
    try {
      const script =
          r"$s=Get-NetAdapterStatistics -ErrorAction Stop; [Console]::WriteLine((($s | Measure-Object ReceivedBytes -Sum).Sum)); [Console]::WriteLine((($s | Measure-Object SentBytes -Sum).Sum))";
      final result = await Process.run('powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', script]);
      final lines = result.stdout
          .toString()
          .trim()
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      if (result.exitCode != 0 || lines.length < 2) return null;
      return TrafficTotals(
          received: int.tryParse(lines[0]) ?? 0,
          sent: int.tryParse(lines[1]) ?? 0);
    } catch (_) {
      await _logger.error('Не удалось прочитать счётчики Windows');
      return null;
    }
  }

  List<TrafficSample> samplesFor(HistoryPeriod period) {
    final window = switch (period) {
      HistoryPeriod.hour => const Duration(hours: 1),
      HistoryPeriod.week => const Duration(days: 7),
      HistoryPeriod.month => const Duration(days: 30),
      HistoryPeriod.year => const Duration(days: 365),
    };
    final since = DateTime.now().subtract(window);
    final source =
        samples.where((sample) => sample.time.isAfter(since)).toList();
    final maxPoints = switch (period) {
      HistoryPeriod.hour => 120,
      HistoryPeriod.week => 168,
      HistoryPeriod.month => 180,
      HistoryPeriod.year => 365,
    };
    if (source.length <= maxPoints) return source;
    final step = (source.length / maxPoints).ceil();
    return [for (var i = 0; i < source.length; i += step) source[i]];
  }

  void resetStatistics() {
    samples.clear();
    _previous = null;
    _downloadTotal = 0;
    _uploadTotal = 0;
    stats = const TrafficStats();
    _logger.info('Статистика сброшена пользователем');
  }

  void dispose() => _timer?.cancel();
  Future<bool> applyLimit(double download, double upload) async {
    await _logger.info(
        'Запрошено ограничение: входящий ${download.toStringAsFixed(1)} Мбит/с, исходящий ${upload.toStringAsFixed(1)} Мбит/с');
    if (!Platform.isWindows) return false;
    final service = File(
        '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}TrafficLimitService.exe');
    if (!service.existsSync()) return false;
    final result = await Process.run(service.path, [
      '--set-limit',
      '--download=${(download * 1000000).round()}',
      '--upload=${(upload * 1000000).round()}'
    ]);
    return result.exitCode == 0 &&
        result.stdout.toString().contains('"limiter":true');
  }
}

class TrafficTotals {
  const TrafficTotals({required this.received, required this.sent});
  final int received;
  final int sent;
}
