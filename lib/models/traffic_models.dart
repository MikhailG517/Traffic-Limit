import 'dart:math';

enum TrafficStatus { active, unavailable, error }

enum HistoryPeriod { hour, week, month, year }

class TrafficSample {
  const TrafficSample(
      {required this.time, required this.download, required this.upload});
  final DateTime time;
  final double download;
  final double upload;
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
      required this.download,
      required this.upload,
      required this.color});
  final String name;
  final int pid;
  final double download;
  final double upload;
  final int color;
}

String formatRate(double value) {
  if (value >= 1000)
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 1 : 2)} Мбит/с';
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} Кбит/с';
}

String formatData(double megabytes) {
  if (megabytes >= 1024) return '${(megabytes / 1024).toStringAsFixed(1)} ГБ';
  return '${megabytes.toStringAsFixed(megabytes >= 100 ? 0 : 1)} МБ';
}

double noise(double base, Random random) =>
    max(0, base + (random.nextDouble() - .5) * base * .28);
