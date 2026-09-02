import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_limit/models/traffic_models.dart';
import 'package:traffic_limit/services/process_sort.dart';

void main() {
  final sample = [
    const ProcessTraffic(
        name: 'a.exe',
        pid: 1,
        connections: 1,
        downloadTotal: 50,
        uploadTotal: 10),
    const ProcessTraffic(
        name: 'b.exe',
        pid: 2,
        connections: 2,
        downloadTotal: 10,
        uploadTotal: 90),
    const ProcessTraffic(
        name: 'c.exe',
        pid: 3,
        connections: 3,
        downloadTotal: 30,
        uploadTotal: 30),
  ];

  test('default total descending puts highest volume first', () {
    final r = sortProcesses(sample, ProcessSortColumn.total, ascending: false);
    expect(r.map((e) => e.name).toList(), ['b.exe', 'c.exe', 'a.exe']);
  });

  test('total ascending reverses order', () {
    final r = sortProcesses(sample, ProcessSortColumn.total, ascending: true);
    expect(r.first.name, 'a.exe');
    expect(r.last.name, 'b.exe');
  });

  test('download column sorts by download volume', () {
    final r = sortProcesses(sample, ProcessSortColumn.downloadTotal,
        ascending: false);
    expect(r.first.name, 'a.exe');
  });

  test('name column sorts alphabetically', () {
    final r = sortProcesses(sample, ProcessSortColumn.name, ascending: true);
    expect(r.map((e) => e.name).toList(), ['a.exe', 'b.exe', 'c.exe']);
  });
}
