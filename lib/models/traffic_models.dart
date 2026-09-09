enum TrafficStatus { active, unavailable, error }

enum HistoryPeriod { hour, week, month, year }

class TrafficSample {
  const TrafficSample(
      {required this.time, required this.download, required this.upload});
  final DateTime time;
  final double download;
  final double upload;
}

/// Bounded, multi-resolution history of traffic samples.
///
/// Recent samples are kept at full (1-second) resolution in a ring buffer so the
/// dashboard sparkline and the 1-hour chart stay smooth. Older samples are pushed
/// into a coarse history list that is periodically decimated (keeps every other
/// point), so the total retained count stays bounded instead of growing without
/// limit (previously a raw list capped at 525,600 entries that was re-serialised
/// to SharedPreferences on every flush).
class TrafficHistory {
  TrafficHistory({int recentLimit = 3600, int historyLimit = 4000})
      : _recentLimit = recentLimit,
        _historyLimit = historyLimit;

  final int _recentLimit;
  final int _historyLimit;
  final List<TrafficSample> _recent = <TrafficSample>[];
  final List<TrafficSample> _history = <TrafficSample>[];

  int get length => _recent.length + _history.length;
  bool get isEmpty => _recent.isEmpty && _history.isEmpty;

  /// All retained points, oldest first. Returns a snapshot list.
  List<TrafficSample> get points {
    if (_history.isEmpty) return List<TrafficSample>.of(_recent);
    if (_recent.isEmpty) return List<TrafficSample>.of(_history);
    return <TrafficSample>[..._history, ..._recent];
  }

  /// The most recent [count] points, oldest first.
  List<TrafficSample> recent(int count) {
    if (count <= 0) return const <TrafficSample>[];
    if (_recent.length >= count) {
      return _recent.sublist(_recent.length - count);
    }
    if (_history.isEmpty) return List<TrafficSample>.of(_recent);
    final needOld = count - _recent.length;
    final old = _history.length <= needOld
        ? _history
        : _history.sublist(_history.length - needOld);
    return <TrafficSample>[...old, ..._recent];
  }

  void add(TrafficSample sample) {
    _recent.add(sample);
    _trim();
  }

  void addAll(Iterable<TrafficSample> samples) {
    for (final sample in samples) {
      add(sample);
    }
  }

  void clear() {
    _recent.clear();
    _history.clear();
  }

  void _trim() {
    if (_recent.length > _recentLimit) {
      final excess = _recent.length - _recentLimit;
      final move = _recent.sublist(0, excess);
      _recent.removeRange(0, excess);
      _history.addAll(move);
    }
    while (_history.length > _historyLimit) {
      _coarsen();
    }
  }

  /// Keeps every other history point (preferring the newest side) to halve the
  /// retained count while preserving the covered time span.
  void _coarsen() {
    final kept = <TrafficSample>[];
    for (var i = _history.length - 1; i >= 0; i -= 2) {
      kept.add(_history[i]);
    }
    _history
      ..clear()
      ..addAll(kept.reversed.toList());
  }
}

class TrafficStats {
  const TrafficStats(
      {this.downloadRate = 0,
      this.uploadRate = 0,
      this.downloadTotal = 0,
      this.uploadTotal = 0,
      this.status = TrafficStatus.unavailable});
  final double downloadRate;
  final double uploadRate;
  final double downloadTotal;
  final double uploadTotal;
  final TrafficStatus status;

  TrafficStats copyWith(
          {double? downloadRate,
          double? uploadRate,
          double? downloadTotal,
          double? uploadTotal,
          TrafficStatus? status}) =>
      TrafficStats(
        downloadRate: downloadRate ?? this.downloadRate,
        uploadRate: uploadRate ?? this.uploadRate,
        downloadTotal: downloadTotal ?? this.downloadTotal,
        uploadTotal: uploadTotal ?? this.uploadTotal,
        status: status ?? this.status,
      );
}

class NetworkInterfaceInfo {
  const NetworkInterfaceInfo(
      {required this.name,
      required this.type,
      required this.download,
      required this.upload,
      this.connected = true});
  final String name;
  final String type;
  final double download;
  final double upload;
  final bool connected;
}

class ProcessTraffic {
  const ProcessTraffic(
      {required this.name,
      required this.pid,
      required this.connections,
      this.color = 0xff4f8cff,
      this.hasByteCounters = false,
      this.download = 0,
      this.upload = 0,
      this.downloadTotal = 0,
      this.uploadTotal = 0});
  final String name;
  final int pid;
  final int connections;
  final int color;
  final bool hasByteCounters;
  final double download;
  final double upload;
  final double downloadTotal;
  final double uploadTotal;
}

String formatRate(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 1 : 2)} Мбит/с';
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} Кбит/с';
}

String formatData(double megabytes) {
  if (megabytes >= 1024) return '${(megabytes / 1024).toStringAsFixed(1)} ГБ';
  return '${megabytes.toStringAsFixed(megabytes >= 100 ? 0 : 1)} МБ';
}
