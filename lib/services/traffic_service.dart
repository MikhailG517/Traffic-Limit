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
  final Map<String, AdapterCounters> _baseline = {};
  DateTime? _previousAt;
  final history = TrafficHistory();
  final ledger = TrafficLedger();
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
  static const _dataVersion = 4;
  static const _ledgerKey = 'trafficLedger';
  DateTime Function() clock = DateTime.now;

  Usage get today => ledger.today(clock());
  Usage get yesterday => ledger.yesterday(clock());
  Usage get week => ledger.week(clock());
  Usage get month => ledger.month(clock());
  double get monthlyTotal => month.total;
  DateTime? _sessionStart;
  DateTime get sessionStart => _sessionStart ?? clock();
  DateTime? _lastStatsSave;
  bool _serviceProbed = false;

  /// Speed samples of the last [window], oldest first.
  List<TrafficSample> speedSamples(Duration window) {
    final since = clock().subtract(window);
    return history
        .recent(window.inSeconds + 1)
        .where((sample) => sample.time.isAfter(since))
        .toList();
  }

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

  Future<void> start(void Function() onUpdate) async {
    _loadLedger();
    _sessionStart = clock();
    _downloadTotal = 0;
    _uploadTotal = 0;
    await ensureService();
    _logger.info('Запуск мониторинга сетевых интерфейсов');
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _sample(onUpdate));
    onUpdate();
  }

  void _loadLedger() {
    final version = _preferences.getInt('trafficDataVersion') ?? 0;
    final encoded = _preferences.getString(_ledgerKey);
    try {
      if (version == _dataVersion && encoded != null) {
        ledger.loadJson(jsonDecode(encoded) as Map<String, dynamic>);
      } else if (version == 3) {
        final legacy = _preferences.getString('dailyTotals');
        if (legacy != null) {
          ledger.importLegacyDaily(jsonDecode(legacy) as Map<String, dynamic>);
        }
      }
    } catch (e) {
      ledger.clear();
      _logger.error('Журнал трафика повреждён, начат заново', error: e);
    }
    for (final key in const [
      'dailyTotals',
      'trafficSamples',
      'monthlyTotal',
      'sessionDownload',
      'sessionUpload'
    ]) {
      _preferences.remove(key);
    }
    _preferences.setInt('trafficDataVersion', _dataVersion);
  }

  /// Books one counter reading: updates the session, the calendar ledger and
  /// the speed history. Exposed for tests.
  void recordCounters(Map<String, AdapterCounters> current, DateTime now) {
    final delta = counterDelta(_baseline, current);
    _baseline.addAll(current);
    final previousAt = _previousAt;
    _previousAt = now;
    if (previousAt == null) return;
    final elapsed = now.difference(previousAt);
    _lastDown = rateKbit(
        currentBytes: delta.received, previousBytes: 0, elapsed: elapsed);
    _lastUp =
        rateKbit(currentBytes: delta.sent, previousBytes: 0, elapsed: elapsed);
    final downMb = delta.received / 1024 / 1024;
    final upMb = delta.sent / 1024 / 1024;
    _downloadTotal += downMb;
    _uploadTotal += upMb;
    ledger.add(now, download: downMb, upload: upMb);
  }

  Future<void> _sample(void Function() onUpdate) async {
    if (_busy) return;
    _busy = true;
    try {
      final now = clock();
      // Самый тяжёлый источник ЦПУ — запуск powershell.exe ради счётчиков
      // интерфейсов, поэтому он выполняется не чаще раза в 2 секунды.
      final shouldRead = _lastTotalsAt == null ||
          now.difference(_lastTotalsAt!) >= const Duration(seconds: 2);
      Map<String, AdapterCounters>? actual;
      if (shouldRead) {
        actual = Platform.isWindows ? await _readWindowsCounters() : null;
        _lastTotalsAt = now;
        if (actual != null) recordCounters(actual, now);
      }
      stats = TrafficStats(
          downloadRate: _lastDown,
          uploadRate: _lastUp,
          downloadTotal: _downloadTotal,
          uploadTotal: _uploadTotal,
          status: Platform.isWindows
              ? TrafficStatus.active
              : TrafficStatus.unavailable);
      history
          .add(TrafficSample(time: now, download: _lastDown, upload: _lastUp));
      if (_lastStatsSave == null ||
          now.difference(_lastStatsSave!).inSeconds >= 60) {
        _lastStatsSave = now;
        await _flushStats();
      }
      interfaces
        ..clear()
        ..add(NetworkInterfaceInfo(
            name: 'Физические адаптеры',
            type: _baseline.isEmpty
                ? (Platform.isWindows
                    ? 'Нет активных адаптеров'
                    : 'Ожидание Windows')
                : _baseline.keys.join(', '),
            download: _lastDown,
            upload: _lastUp));
      // Чтение процессов (PowerShell + нативная служба) самое дорогое, поэтому
      // выполняем его не чаще раза в 5 секунд.
      if (_lastProcessesAt == null ||
          now.difference(_lastProcessesAt!).inSeconds >= 5) {
        _lastProcessesAt = now;
        processes
          ..clear()
          ..addAll(await _readWindowsProcesses());
      }
      await _logger.debug('Обновление показателей', params: {
        'down_kbit': _lastDown.round(),
        'up_kbit': _lastUp.round(),
        'processes': processes.length
      });
      if (_lastUiUpdateAt == null ||
          now.difference(_lastUiUpdateAt!) >= const Duration(seconds: 1)) {
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

  Future<Map<String, AdapterCounters>?> _readWindowsCounters() async {
    // Only physical adapters are counted so the totals match the provider;
    // virtual VPN / Hyper-V adapters would count the same bytes twice.
    try {
      return await Isolate.run(_readWindowsCountersIsolate);
    } catch (e, st) {
      await _logger.error('Не удалось прочитать счётчики Windows',
          error: e, stack: st);
      return null;
    }
  }

  static const String _countersScript =
      r'''Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Get-NetAdapterStatistics -ErrorAction Stop | ForEach-Object { Write-Output ("$($_.InterfaceDescription)|$($_.ReceivedBytes)|$($_.SentBytes)") }''';

  static const String _processesScript =
      r'''$connections=@(); $connections += Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue; $connections += Get-NetUDPEndpoint -ErrorAction SilentlyContinue; $connections | Group-Object OwningProcess | ForEach-Object { $id=[int]$_.Name; try { $name=(Get-Process -Id $id -ErrorAction Stop).ProcessName + '.exe' } catch { $name='PID ' + $id }; Write-Output ("$id|$name|$($_.Count)") }''';

  static Future<Map<String, AdapterCounters>?>
      _readWindowsCountersIsolate() async {
    final result = await Process.run('powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', _countersScript]);
    if (result.exitCode != 0) return null;
    return parseAdapterCounters(result.stdout.toString());
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

  static double peakFromSamples(List<TrafficSample> points,
      {required bool download}) {
    if (points.isEmpty) return 0;
    return points.fold<double>(
        0,
        (peak, sample) =>
            max(peak, download ? sample.download : sample.upload));
  }

  Future<void> resetStatistics() async {
    history.clear();
    ledger.clear();
    _sessionStart = clock();
    _downloadTotal = 0;
    _uploadTotal = 0;
    _lastDown = 0;
    _lastUp = 0;
    stats = const TrafficStats();
    await _preferences.remove(_ledgerKey);
    await _logger.info('Статистика сброшена пользователем');
  }

  Future<void> _flushStats() async {
    ledger.prune(clock());
    await _preferences.setString(_ledgerKey, jsonEncode(ledger.toJson()));
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _flushStats();
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
