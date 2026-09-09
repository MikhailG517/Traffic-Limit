import 'dart:convert';
import 'dart:io';
import 'package:traffic_limit/models/traffic_models.dart';

/// Measures the before/after resource impact of the bounded traffic-history
/// change. The history models are pure Dart, so this runs on any host.
///
/// Usage:
///   dart run tool/resource_benchmark.dart old   # unbounded List (previous)
///   dart run tool/resource_benchmark.dart new   # TrafficHistory (current)
///
/// Simulates a full year of 1-second samples (525,600 points) — the old cap.
void main(List<String> args) {
  final mode = args.isNotEmpty ? args[0] : 'new';
  const seconds = 525600; // 365 days at 1 sample/second
  final start = DateTime(2020, 1, 1);
  if (mode == 'old') {
    _runOld(seconds, start);
  } else {
    _runNew(seconds, start);
  }
}

void _runOld(int seconds, DateTime start) {
  final baseRss = ProcessInfo.currentRss;
  final samples = <TrafficSample>[];
  final sw = Stopwatch()..start();
  for (var i = 0; i < seconds; i++) {
    samples.add(TrafficSample(
        time: start.add(Duration(seconds: i)),
        download: i.toDouble(),
        upload: i.toDouble() * 2));
    if (samples.length > 525600) samples.removeAt(0);
  }
  sw.stop();
  final rssSteady = ProcessInfo.currentRss;

  // The dashboard previously mapped the whole list to doubles twice per rebuild.
  const reps = 5;
  final spark = Stopwatch()..start();
  for (var k = 0; k < reps; k++) {
    samples.map((e) => e.download).toList();
    samples.map((e) => e.upload).toList();
  }
  spark.stop();

  final blob = utf8.encode(jsonEncode(samples
      .map((e) => {'t': e.time.toIso8601String(), 'd': e.download, 'u': e.upload})
      .toList())).length;

  stdout.writeln(
      'OLD | samples=${samples.length} | rssDelta=${_mb(rssSteady - baseRss)}MB '
      '| addMs=${sw.elapsedMilliseconds} | perRebuildMs=${(spark.elapsedMicroseconds / reps / 1000).toStringAsFixed(3)} '
      '| blobBytes=$blob');
}

void _runNew(int seconds, DateTime start) {
  final baseRss = ProcessInfo.currentRss;
  final history = TrafficHistory();
  final sw = Stopwatch()..start();
  for (var i = 0; i < seconds; i++) {
    history.add(TrafficSample(
        time: start.add(Duration(seconds: i)),
        download: i.toDouble(),
        upload: i.toDouble() * 2));
  }
  sw.stop();
  final rssSteady = ProcessInfo.currentRss;

  // The dashboard now only maps the trailing 120 points per rebuild.
  const reps = 5;
  final spark = Stopwatch()..start();
  for (var k = 0; k < reps; k++) {
    history.recent(120).map((e) => e.download).toList();
    history.recent(120).map((e) => e.upload).toList();
  }
  spark.stop();

  final pts = history.points;
  final blob = utf8.encode(jsonEncode(pts
      .map((e) => {'t': e.time.toIso8601String(), 'd': e.download, 'u': e.upload})
      .toList())).length;

  stdout.writeln(
      'NEW | samples=${history.length} | rssDelta=${_mb(rssSteady - baseRss)}MB '
      '| addMs=${sw.elapsedMilliseconds} | perRebuildMs=${(spark.elapsedMicroseconds / reps / 1000).toStringAsFixed(3)} '
      '| blobBytes=$blob');
}

String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);
