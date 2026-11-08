enum TrafficStatus { active, unavailable, error }

enum SpeedWindow { fiveMinutes, hour }

enum VolumePeriod { day, week, month, year }

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

/// Volume in megabytes (MiB), split by direction.
class Usage {
  const Usage({this.download = 0, this.upload = 0});
  final double download;
  final double upload;
  double get total => download + upload;

  Usage operator +(Usage other) =>
      Usage(download: download + other.download, upload: upload + other.upload);

  Map<String, double> toJson() => {'d': download, 'u': upload};
  static Usage fromJson(Object? value) {
    final map = value as Map<String, dynamic>;
    return Usage(
        download: (map['d'] as num?)?.toDouble() ?? 0,
        upload: (map['u'] as num?)?.toDouble() ?? 0);
  }
}

/// One bar of a volume chart: [start] of the bucket and its usage.
class UsageBucket {
  const UsageBucket(this.start, this.usage);
  final DateTime start;
  final Usage usage;
}

/// Calendar ledger of transferred volume in local time.
///
/// Hours are kept for [hourRetention] (today/yesterday by hour, recent week),
/// days for [dayRetention] (week, month and year views). Periods are calendar
/// based: "today" starts at local midnight, the week starts on Monday and the
/// month on the 1st, so the numbers match the operator's billing period.
class TrafficLedger {
  TrafficLedger(
      {this.hourRetention = const Duration(days: 8),
      this.dayRetention = const Duration(days: 400)});

  final Duration hourRetention;
  final Duration dayRetention;
  final Map<String, Usage> _hours = {};
  final Map<String, Usage> _days = {};

  bool get isEmpty => _days.isEmpty;

  static String dayKey(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)}';
  static String hourKey(DateTime t) => '${dayKey(t)}T${_two(t.hour)}';
  static String _two(int value) => value.toString().padLeft(2, '0');

  static DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);
  static DateTime startOfWeek(DateTime t) =>
      DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday));
  static DateTime startOfMonth(DateTime t) => DateTime(t.year, t.month);

  void add(DateTime at, {required double download, required double upload}) {
    if (download <= 0 && upload <= 0) return;
    final delta = Usage(download: download, upload: upload);
    _hours.update(hourKey(at), (v) => v + delta, ifAbsent: () => delta);
    _days.update(dayKey(at), (v) => v + delta, ifAbsent: () => delta);
  }

  Usage day(DateTime day) => _days[dayKey(day)] ?? const Usage();
  Usage hour(DateTime hour) => _hours[hourKey(hour)] ?? const Usage();

  /// Sum of whole days in `[from, to]`, both given as calendar days.
  Usage daysBetween(DateTime from, DateTime to) {
    var sum = const Usage();
    for (var d = startOfDay(from);
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day + 1)) {
      sum += day(d);
    }
    return sum;
  }

  Usage today(DateTime now) => day(now);
  Usage yesterday(DateTime now) =>
      day(DateTime(now.year, now.month, now.day - 1));
  Usage week(DateTime now) => daysBetween(startOfWeek(now), now);
  Usage month(DateTime now) => daysBetween(startOfMonth(now), now);

  List<UsageBucket> hoursOf(DateTime day) => [
        for (var h = 0; h < 24; h++)
          UsageBucket(DateTime(day.year, day.month, day.day, h),
              hour(DateTime(day.year, day.month, day.day, h)))
      ];

  List<UsageBucket> daysOfWeek(DateTime now) {
    final start = startOfWeek(now);
    return [
      for (var i = 0; i < 7; i++)
        UsageBucket(DateTime(start.year, start.month, start.day + i),
            day(DateTime(start.year, start.month, start.day + i)))
    ];
  }

  List<UsageBucket> daysOfMonth(DateTime now) {
    final count = DateTime(now.year, now.month + 1, 0).day;
    return [
      for (var i = 1; i <= count; i++)
        UsageBucket(DateTime(now.year, now.month, i),
            day(DateTime(now.year, now.month, i)))
    ];
  }

  List<UsageBucket> monthsOfYear(DateTime now) => [
        for (var m = 1; m <= 12; m++)
          UsageBucket(
              DateTime(now.year, m),
              m > now.month
                  ? const Usage()
                  : daysBetween(DateTime(now.year, m),
                      m == now.month ? now : DateTime(now.year, m + 1, 0)))
      ];

  void prune(DateTime now) {
    final hourCutoff = hourKey(now.subtract(hourRetention));
    final dayCutoff = dayKey(now.subtract(dayRetention));
    _hours.removeWhere((key, _) => key.compareTo(hourCutoff) < 0);
    _days.removeWhere((key, _) => key.compareTo(dayCutoff) < 0);
  }

  void clear() {
    _hours.clear();
    _days.clear();
  }

  Map<String, dynamic> toJson() => {
        'hours': {for (final e in _hours.entries) e.key: e.value.toJson()},
        'days': {for (final e in _days.entries) e.key: e.value.toJson()},
      };

  void loadJson(Map<String, dynamic> json) {
    clear();
    for (final e in (json['hours'] as Map<String, dynamic>? ?? {}).entries) {
      _hours[e.key] = Usage.fromJson(e.value);
    }
    for (final e in (json['days'] as Map<String, dynamic>? ?? {}).entries) {
      _days[e.key] = Usage.fromJson(e.value);
    }
  }

  /// Imports the pre-ledger `dailyTotals` map (total MB per day, no
  /// direction). The split is unknown, so the volume is booked as download.
  void importLegacyDaily(Map<String, dynamic> daily) {
    for (final e in daily.entries) {
      final value = (e.value as num).toDouble();
      if (value > 0) _days[e.key] = Usage(download: value);
    }
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
