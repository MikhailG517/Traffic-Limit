import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/traffic_models.dart';
import 'rate_math.dart';
import 'limit_validation.dart';
import 'logger_service.dart';

class TrafficService {
  TrafficService(this._logger, this._preferences);
  final LoggerService _logger;
  final SharedPreferences _preferences;
  Timer? _timer;
  bool _busy = false;
  TrafficTotals? _previous;
  DateTime? _previousAt;
  final history = TrafficHistory();
  DateTime? _lastProcessesAt;
  DateTime? _lastTotalsAt;
  DateTime? _lastUiUpdateAt;
  double _lastDown = 0;
  double _lastUp = 0;
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
  DateTime? _sessionStart;
  DateTime get sessionStart => _sessionStart ?? DateTime.now();
  final Map<String, double> _dailyTotals = {};
  DateTime? _lastStatsSave;
  bool _serviceProbed = false;

  /// Snapshot of all retained samples (bounded). Older layout kept an unbounded
  /// list capped only at 525,600 entries which grew the heap and produced a huge
  /// JSON blob on every persist.
  List<TrafficSample> get samples => history.points;

  /// Only the most recent [count] samples — used by the dashboard sparkline so
  /// it does not copy the whole history on every rebuild.
  List<TrafficSample> recentSamples(int count) => history.recent(count);

  String get _servicePath =>
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}TrafficLimitService.exe';

  Future<String?> _nativeResponse(String command) async {
    if (!Platform.isWindows) return null;
    final service = File(_servicePath);
    if (!service.existsSync()) return null;
    final tmp = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}tl-resp-${DateTime.now().microsecondsSinceEpoch}.json');
    try {
      final result =
          await Process.run(service.path, [command, '--out=${tmp.path}']);
      if (result.exitCode != 0 || !tmp.existsSync()) return null;
      return await tmp.readAsString();
    } catch (_) {
      return null;
    } finally {
      try {
        if (tmp.existsSync()) tmp.delete();
      } catch (_) {}
    }
  }

  Future<String> nativeTelemetryStatus() async {
    if (!Platform.isWindows) return 'Только для Windows';
    final service = File(_servicePath);
    if (!service.existsSync()) return 'Служба не найдена';
    try {
      final text = await _nativeResponse('--get-status');
      if (text == null) return 'Служба не отвечает';
      final status = Map<String, dynamic>.from(jsonDecode(text) as Map);
      final driver = status['driver'] == true;
      if (!driver) return 'Драйвер WinDivert недоступен';
      return 'Активно';
    } catch (e) {
      await _logger.error('Ошибка опроса статуса службы', error: e);
      return 'Ошибка опроса';
    }
  }

  Future<void> ensureService() async {
    if (!Platform.isWindows || _serviceProbed) return;
    _serviceProbed = true;
    try {
      final status = await Process.run(_servicePath, ['--get-status']);
      if (status.exitCode == 0) return;
    } catch (_) {}
    try {
      await Process.run('sc.exe', ['start', 'TrafficLimitService']);
    } catch (_) {}
  }

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
    _sessionStart = DateTime.now();
    _downloadTotal = 0;
    _uploadTotal = 0;
    await _preferences.remove('sessionDownload');
    await _preferences.remove('sessionUpload');
    await _preferences.setDouble('monthlyTotal', _monthlyTotal);
    await _restoreSamples();
    await ensureService();
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
      // Самый тяжёлый источник ЦПУ — запуск powershell.exe ради счётчиков
      // интерфейсов. Считываем его не чаще раза в 2 секунды, а в промежуточные
      // секунды удерживаем последнюю скорость, чтобы виджет оставался плавным.
      const totalsInterval = Duration(seconds: 2);
      final shouldRead = _lastTotalsAt == null ||
          now.difference(_lastTotalsAt!) >= totalsInterval;
      TrafficTotals? actual;
      if (shouldRead) {
        actual = Platform.isWindows ? await _readWindowsTotals() : null;
        _lastTotalsAt = now;
      }
      double down;
      double up;
      if (actual != null) {
        final elapsed = _previousAt == null
            ? totalsInterval
            : now.difference(_previousAt!);
        down = _previous == null
            ? 0
            : rateKbit(
                currentBytes: actual.received,
                previousBytes: _previous!.received,
                elapsed: elapsed);
        up = _previous == null
            ? 0
            : rateKbit(
                currentBytes: actual.sent,
                previousBytes: _previous!.sent,
                elapsed: elapsed);
        _lastDown = down;
        _lastUp = up;
        if (_previous != null) {
          final receivedDelta = max(0, actual.received - _previous!.received);
          final sentDelta = max(0, actual.sent - _previous!.sent);
          _downloadTotal += receivedDelta / 1024 / 1024;
          _uploadTotal += sentDelta / 1024 / 1024;
          final deltaMb = (receivedDelta + sentDelta) / 1024 / 1024;
          _monthlyTotal += deltaMb;
          final key = _dayKey(DateTime.now());
          _dailyTotals[key] = (_dailyTotals[key] ?? 0) + deltaMb;
        }
        _previous = actual;
        _previousAt = now;
      } else {
        down = _lastDown;
        up = _lastUp;
      }
      stats = TrafficStats(
          downloadRate: down,
          uploadRate: up,
          downloadTotal: _downloadTotal,
          uploadTotal: _uploadTotal,
          status: actual == null && !Platform.isWindows
              ? TrafficStatus.unavailable
              : TrafficStatus.active);
      history.add(TrafficSample(time: now, download: down, upload: up));
      if (_lastStatsSave == null ||
          now.difference(_lastStatsSave!).inSeconds >= 60) {
        _lastStatsSave = now;
        await _flushStats();
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
      // Чтение процессов (PowerShell + нативная служба) самое дорогое, поэтому
      // выполняем его реже, чем интерфейсные счётчики, и не чаще раза в 5 секунд.
      if (_lastProcessesAt == null ||
          now.difference(_lastProcessesAt!).inSeconds >= 5) {
        _lastProcessesAt = now;
        processes
          ..clear()
          ..addAll(await _readWindowsProcesses());
      }
      await _logger.debug('Обновление показателей', params: {
        'down_kbit': down.round(),
        'up_kbit': up.round(),
        'processes': processes.length
      });
      // Пересборку интерфейса тоже делаем не чаще раза в 2 секунды: это вторая по
      // стоимости операция на UI-потоке (полная перестройка MaterialApp и графиков).
      if (_lastUiUpdateAt == null ||
          now.difference(_lastUiUpdateAt!) >= const Duration(seconds: 2)) {
        _lastUiUpdateAt = now;
        onUpdate();
      }
    } finally {
      _busy = false;
    }
  }

  Future<List<ProcessTraffic>> _readWindowsProcesses() async {
    if (!Platform.isWindows) return const [];
    try {
      final servicePath = _servicePath;
      return await Isolate.run(() => _readWindowsProcessesIsolate(servicePath));
    } catch (e, st) {
      await _logger.error('Не удалось получить список TCP-соединений',
          error: e, stack: st);
      return const [];
    }
  }

  Future<TrafficTotals?> _readWindowsTotals() async {
    // Only physical adapters are counted so the totals match the provider;
    // native GetIfTable-style counters would also sum virtual VPN / Hyper-V
    // adapters and over-report the session volume.
    try {
      return await Isolate.run(_readWindowsTotalsIsolate);
    } catch (e, st) {
      await _logger.error('Не удалось прочитать счётчики Windows',
          error: e, stack: st);
      return null;
    }
  }

  static const String _totalsScript = r'''$a=Get-NetAdapter -Physical | Where-Object Status -eq 'Up'; $s=$a | Get-NetAdapterStatistics -ErrorAction Stop; $rx=[UInt64](($s | Measure-Object ReceivedBytes -Sum).Sum); $tx=[UInt64](($s | Measure-Object SentBytes -Sum).Sum); Write-Output ("RX=$rx"); Write-Output ("TX=$tx")''';

  static const String _processesScript = r'''$connections=@(); $connections += Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue; $connections += Get-NetUDPEndpoint -ErrorAction SilentlyContinue; $connections | Group-Object OwningProcess | ForEach-Object { $id=[int]$_.Name; try { $name=(Get-Process -Id $id -ErrorAction Stop).ProcessName + '.exe' } catch { $name='PID ' + $id }; Write-Output ("$id|$name|$($_.Count)") }''';

  /// Reads interface totals inside a short-lived background isolate so the heavy
  /// PowerShell spawn and output parsing do not allocate on the UI isolate.
  static Future<TrafficTotals?> _readWindowsTotalsIsolate() async {
    final result = await Process.run('powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', _totalsScript]);
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
  }

  /// Reads per-process connection + byte counters inside a background isolate.
  static Future<List<ProcessTraffic>> _readWindowsProcessesIsolate(
      String servicePath) async {
    final result = await Process.run('powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', _processesScript]);
    if (result.exitCode != 0) return const [];
    final counters = await _readProcessCountersIsolate(servicePath);
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
  }

  static Future<Map<int, Map<String, dynamic>>> _readProcessCountersIsolate(
      String servicePath) async {
    final service = File(servicePath);
    if (!service.existsSync()) return {};
    try {
      var text = await _nativeResponseIsolate(servicePath, '--get-processes');
      if (text == null || text.isEmpty) {
        try {
          await Process.run('sc.exe', ['start', 'TrafficLimitService']);
        } catch (_) {}
        text = await _nativeResponseIsolate(servicePath, '--get-processes');
      }
      if (text == null || text.isEmpty) return {};
      final decoded = jsonDecode(text) as List<dynamic>;
      return {
        for (final item in decoded)
          (item['pid'] as num).toInt(): Map<String, dynamic>.from(item as Map)
      };
    } catch (_) {
      return {};
    }
  }

  static Future<String?> _nativeResponseIsolate(
      String servicePath, String command) async {
    final service = File(servicePath);
    if (!service.existsSync()) return null;
    final tmp = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}tl-resp-${DateTime.now().microsecondsSinceEpoch}.json');
    try {
      final result =
          await Process.run(service.path, [command, '--out=${tmp.path}']);
      if (result.exitCode != 0 || !tmp.existsSync()) return null;
      return await tmp.readAsString();
    } catch (_) {
      return null;
    } finally {
      try {
        if (tmp.existsSync()) tmp.delete();
      } catch (_) {}
    }
  }

  double peakFor(HistoryPeriod period, {required bool download}) {
    final window = switch (period) {
      HistoryPeriod.hour => const Duration(hours: 1),
      HistoryPeriod.week => const Duration(days: 7),
      HistoryPeriod.month => const Duration(days: 30),
      HistoryPeriod.year => const Duration(days: 365),
    };
    final since = DateTime.now().subtract(window);
    return peakFromSamples(
        samples.where((sample) => sample.time.isAfter(since)).toList(),
        download: download);
  }

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
    history.clear();
    _previous = null;
    _sessionStart = DateTime.now();
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

  Future<void> _restoreSamples() async {
    final savedSamples = _preferences.getString('trafficSamples');
    if (savedSamples == null) return;
    // Очень большой (старый) blob сам по себе занимает десятки МБ в памяти
    // SharedPreferences; при превышении порога отбрасываем его целиком.
    if (savedSamples.length > 4 * 1024 * 1024) {
      await _preferences.remove('trafficSamples');
      await _logger.warn('История графиков слишком велика, сброшена');
      return;
    }
    try {
      history.addAll((jsonDecode(savedSamples) as List<dynamic>).map((item) =>
          TrafficSample(
              time: DateTime.parse(item['time'] as String),
              download: (item['download'] as num).toDouble(),
              upload: (item['upload'] as num).toDouble())));
    } catch (_) {
      await _logger.error('Не удалось восстановить историю графиков');
    }
  }

  Future<void> _flushStats() async {
    _pruneDailyTotals();
    await _preferences.setDouble('sessionDownload', _downloadTotal);
    await _preferences.setDouble('sessionUpload', _uploadTotal);
    await _preferences.setDouble('monthlyTotal', _monthlyTotal);
    await _preferences.setString('dailyTotals', jsonEncode(_dailyTotals));
    await _preferences.setString(
        'trafficSamples',
        jsonEncode(history.points
            .map((item) => {
                  'time': item.time.toIso8601String(),
                  'download': item.download,
                  'upload': item.upload
                })
            .toList()));
  }

  /// Держит суточный журнал ограниченным: выбрасывает записи старше ~400 дней,
  /// чтобы карта не росла бесконечно и её JSON оставался маленьким.
  void _pruneDailyTotals() {
    final cutoff = DateTime.now().subtract(const Duration(days: 400));
    final stale = <String>[];
    _dailyTotals.forEach((key, _) {
      final parts = key.split('-').map(int.parse).toList();
      if (parts.length != 3) return;
      final date = DateTime(parts[0], parts[1], parts[2]);
      if (date.isBefore(cutoff)) stale.add(key);
    });
    for (final key in stale) {
      _dailyTotals.remove(key);
    }
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_flushStats());
  }

  Future<bool> setLimitsEnabled(
      bool enabled, double download, double upload) async {
    await _logger.info('Переключение ограничения',
        params: {'enabled': enabled, 'download': download, 'upload': upload});
    if (enabled) return applyLimit(download, upload);
    if (!Platform.isWindows) return false;
    final service = File(_servicePath);
    if (!service.existsSync()) return false;
    final result = await Process.run(service.path, ['--disable']);
    await _logger.info('Ограничения ${enabled ? 'включены' : 'отключены'}');
    return result.exitCode == 0;
  }

  Future<bool> applyLimit(double download, double upload) async {
    await _logger.info('Применение ограничения',
        params: {'download_mbps': download, 'upload_mbps': upload});
    if (!Platform.isWindows) return false;
    final service = File(_servicePath);
    if (!service.existsSync()) return false;
    final text = await _nativeResponse(
        '--set-limit --download=${mbpsToBitsPerSecond(download)} --upload=${mbpsToBitsPerSecond(upload)}');
    var ok = false;
    if (text != null) {
      try {
        final status = Map<String, dynamic>.from(jsonDecode(text) as Map);
        ok = status['limiter'] == true;
      } catch (_) {
        ok = text.contains('"limiter":true');
      }
    }
    await _logger.info('Результат применения ограничения',
        params: {'ok': ok, 'response': text});
    return ok;
  }
}

class TrafficTotals {
  const TrafficTotals(
      {required this.received, required this.sent, required this.linkKbit});
  final int received;
  final int sent;
  final double linkKbit;
}
