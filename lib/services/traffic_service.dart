import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/traffic_models.dart';
import 'rate_math.dart';
import 'logger_service.dart';

class TrafficService {
  TrafficService(this._logger, this._preferences);
  final LoggerService _logger;
  final SharedPreferences _preferences;
  Timer? _timer;
  bool _busy = false;
  TrafficTotals? _previous;
  DateTime? _previousAt;
  final samples = <TrafficSample>[];
  TrafficStats stats = const TrafficStats();
  final interfaces = <NetworkInterfaceInfo>[];
  final processes = <ProcessTraffic>[];
  double _downloadTotal = 0;
  double _uploadTotal = 0;
  double _monthlyTotal = 0;
  static const _dataVersion = 3;
  double get monthlyTotal => _monthlyTotal;
  double get todayTotal => _periodTotal(const Duration(days: 1));
  double get weekTotal => _periodTotal(const Duration(days: 7));
  double get monthTotal => _monthlyTotal;
  final Map<String, double> _dailyTotals = {};
  DateTime? _lastHistorySave;
  String _dayKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  double _periodTotal(Duration period) {
    final since = DateTime.now().subtract(period);
    return _dailyTotals.entries.fold(0, (sum, item) {
      final parts = item.key.split('-').map(int.parse).toList();
      final date = DateTime(parts[0], parts[1], parts[2]);
      return sum +
          (date.isAfter(since.subtract(const Duration(days: 1)))
              ? item.value
              : 0);
    });
  }

  Future<void> start(void Function() onUpdate) async {
    if ((_preferences.getInt('trafficDataVersion') ?? 0) != _dataVersion) {
      await _preferences.remove('dailyTotals');
      await _preferences.remove('trafficSamples');
      await _preferences.remove('monthlyTotal');
      await _preferences.remove('sessionDownload');
      await _preferences.remove('sessionUpload');
      await _preferences.setInt('trafficDataVersion', _dataVersion);
    }
    final encoded = _preferences.getString('dailyTotals');
    if (encoded != null) {
      for (final entry
          in (jsonDecode(encoded) as Map<String, dynamic>).entries) {
        _dailyTotals[entry.key] = (entry.value as num).toDouble();
      }
    }
    _monthlyTotal = _dailyTotals.entries
        .where((entry) => entry.key.startsWith(
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}'))
        .fold<double>(0, (sum, entry) => sum + entry.value);
    // Сессия относится к текущему запуску приложения; суточный журнал хранится отдельно.
    _downloadTotal = 0;
    _uploadTotal = 0;
    await _preferences.remove('sessionDownload');
    await _preferences.remove('sessionUpload');
    await _preferences.setDouble('monthlyTotal', _monthlyTotal);
    final savedSamples = _preferences.getString('trafficSamples');
    if (savedSamples != null) {
      try {
        samples.addAll((jsonDecode(savedSamples) as List<dynamic>).map((item) =>
            TrafficSample(
                time: DateTime.parse(item['time'] as String),
                download: (item['download'] as num).toDouble(),
                upload: (item['upload'] as num).toDouble())));
      } catch (_) {
        await _logger.error('Не удалось восстановить историю графиков');
      }
    }
    _logger.info('Запуск мониторинга сетевых интерфейсов');
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _sample(onUpdate));
    onUpdate();
  }

  Future<void> _sample(void Function() onUpdate) async {
    if (_busy) return;
    _busy = true;
    try {
      final now = DateTime.now();
      final actual = Platform.isWindows ? await _readWindowsTotals() : null;
      final elapsed = _previousAt == null
          ? const Duration(seconds: 1)
          : now.difference(_previousAt!);
      final double down = actual == null || _previous == null
          ? 0
          : rateKbit(
              currentBytes: actual.received,
              previousBytes: _previous!.received,
              elapsed: elapsed);
      final double up = actual == null || _previous == null
          ? 0
          : rateKbit(
              currentBytes: actual.sent,
              previousBytes: _previous!.sent,
              elapsed: elapsed);
      if (actual != null) {
        if (_previous != null) {
          final receivedDelta = max(0, actual.received - _previous!.received);
          final sentDelta = max(0, actual.sent - _previous!.sent);
          _downloadTotal += receivedDelta / 1024 / 1024;
          _uploadTotal += sentDelta / 1024 / 1024;
          await _preferences.setDouble('sessionDownload', _downloadTotal);
          await _preferences.setDouble('sessionUpload', _uploadTotal);
          final deltaMb = (receivedDelta + sentDelta) / 1024 / 1024;
          _monthlyTotal += deltaMb;
          final key = _dayKey(DateTime.now());
          _dailyTotals[key] = (_dailyTotals[key] ?? 0) + deltaMb;
          await _preferences.setDouble('monthlyTotal', _monthlyTotal);
          await _preferences.setString('dailyTotals', jsonEncode(_dailyTotals));
        }
        _previous = actual;
        _previousAt = now;
      }
      stats = TrafficStats(
          downloadRate: down,
          uploadRate: up,
          downloadTotal: _downloadTotal,
          uploadTotal: _uploadTotal,
          status: actual == null && !Platform.isWindows
              ? TrafficStatus.unavailable
              : TrafficStatus.active);
      samples.add(TrafficSample(time: now, download: down, upload: up));
      if (samples.length > 525600) samples.removeAt(0);
      if (_lastHistorySave == null ||
          now.difference(_lastHistorySave!).inSeconds >= 10) {
        _lastHistorySave = now;
        await _preferences.setString(
            'trafficSamples',
            jsonEncode(samples
                .map((item) => {
                      'time': item.time.toIso8601String(),
                      'download': item.download,
                      'upload': item.upload
                    })
                .toList()));
      }
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
        ..addAll(await _readWindowsProcesses());
      onUpdate();
    } finally {
      _busy = false;
    }
  }

  Future<List<ProcessTraffic>> _readWindowsProcesses() async {
    if (!Platform.isWindows) return const [];
    try {
      const script =
          r'''$connections=@(); $connections += Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue; $connections += Get-NetUDPEndpoint -ErrorAction SilentlyContinue; $connections | Group-Object OwningProcess | ForEach-Object { $id=[int]$_.Name; try { $name=(Get-Process -Id $id -ErrorAction Stop).ProcessName + '.exe' } catch { $name='PID ' + $id }; Write-Output ("$id|$name|$($_.Count)") }''';
      final result = await Process.run('powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', script]);
      if (result.exitCode != 0) return const [];
      final counters = await _readProcessCounters();
      final rows = <ProcessTraffic>[];
      for (final line in result.stdout.toString().split(RegExp(r'\r?\n'))) {
        final fields = line.trim().split('|');
        if (fields.length != 3) continue;
        final pid = int.tryParse(fields[0]);
        final count = int.tryParse(fields[2]);
        if (pid == null || count == null) continue;
        final data = counters[pid];
        rows.add(ProcessTraffic(
            name: fields[1],
            pid: pid,
            connections: count,
            hasByteCounters: data != null,
            download: (data?['receivedRate'] as num?)?.toDouble() ?? 0,
            upload: (data?['sentRate'] as num?)?.toDouble() ?? 0,
            downloadTotal:
                ((data?['received'] as num?)?.toDouble() ?? 0) / 1024 / 1024,
            uploadTotal:
                ((data?['sent'] as num?)?.toDouble() ?? 0) / 1024 / 1024));
      }
      rows.sort((a, b) => b.connections.compareTo(a.connections));
      return rows;
    } catch (_) {
      await _logger.error('Не удалось получить список TCP-соединений');
      return const [];
    }
  }

  Future<Map<int, Map<String, dynamic>>> _readProcessCounters() async {
    final service = File(
        '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}TrafficLimitService.exe');
    if (!service.existsSync()) return {};
    try {
      final result = await Process.run(service.path, ['--get-processes']);
      if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
        return {};
      }
      final decoded = jsonDecode(result.stdout.toString()) as List<dynamic>;
      return {
        for (final item in decoded)
          (item['pid'] as num).toInt(): Map<String, dynamic>.from(item as Map)
      };
    } catch (_) {
      return {};
    }
  }

  Future<TrafficTotals?> _readWindowsTotals() async {
    try {
      const script =
          r'''$a=Get-NetAdapter -Physical | Where-Object Status -eq 'Up'; $s=$a | Get-NetAdapterStatistics -ErrorAction Stop; $rx=[UInt64](($s | Measure-Object ReceivedBytes -Sum).Sum); $tx=[UInt64](($s | Measure-Object SentBytes -Sum).Sum); Write-Output ("RX=$rx"); Write-Output ("TX=$tx")''';
      final result = await Process.run('powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', script]);
      final lines = result.stdout
          .toString()
          .trim()
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      if (result.exitCode != 0 || lines.length < 2) return null;
      final received = int.tryParse(lines
          .firstWhere((line) => line.startsWith('RX='), orElse: () => 'RX=0')
          .substring(3));
      final sent = int.tryParse(lines
          .firstWhere((line) => line.startsWith('TX='), orElse: () => 'TX=0')
          .substring(3));
      if (received == null || sent == null) return null;
      return TrafficTotals(received: received, sent: sent, linkKbit: 500000);
    } catch (_) {
      await _logger.error('Не удалось прочитать счётчики Windows');
      return null;
    }
  }

  double peakFor(HistoryPeriod period, {required bool download}) =>
      peakFromSamples(samplesFor(period), download: download);

  static double peakFromSamples(List<TrafficSample> points,
      {required bool download}) {
    if (points.isEmpty) return 0;
    return points.fold<double>(
        0,
        (peak, sample) =>
            max(peak, download ? sample.download : sample.upload));
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
    _monthlyTotal = 0;
    _dailyTotals.clear();
    _preferences.setDouble('monthlyTotal', 0);
    _preferences.remove('sessionDownload');
    _preferences.remove('sessionUpload');
    _preferences.remove('dailyTotals');
    _preferences.remove('trafficSamples');
    stats = const TrafficStats();
    _logger.info('Статистика сброшена пользователем');
  }

  void dispose() => _timer?.cancel();
  Future<bool> setLimitsEnabled(
      bool enabled, double download, double upload) async {
    if (enabled) return applyLimit(download, upload);
    if (!Platform.isWindows) return false;
    final service = File(
        '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}TrafficLimitService.exe');
    if (!service.existsSync()) return false;
    final result = await Process.run(service.path, ['--disable']);
    await _logger.info('Ограничения ${enabled ? 'включены' : 'отключены'}');
    return result.exitCode == 0;
  }

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
  const TrafficTotals(
      {required this.received, required this.sent, required this.linkKbit});
  final int received;
  final int sent;
  final double linkKbit;
}
