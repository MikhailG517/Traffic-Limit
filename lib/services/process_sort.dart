import '../models/traffic_models.dart';

enum ProcessSortColumn {
  name,
  download,
  upload,
  downloadTotal,
  uploadTotal,
  total
}

List<ProcessTraffic> sortProcesses(
    List<ProcessTraffic> input, ProcessSortColumn column,
    {required bool ascending}) {
  final result = [...input];
  int compare(ProcessTraffic a, ProcessTraffic b) => switch (column) {
        ProcessSortColumn.name => a.name.compareTo(b.name),
        ProcessSortColumn.download => a.download.compareTo(b.download),
        ProcessSortColumn.upload => a.upload.compareTo(b.upload),
        ProcessSortColumn.downloadTotal =>
          a.downloadTotal.compareTo(b.downloadTotal),
        ProcessSortColumn.uploadTotal => a.uploadTotal.compareTo(b.uploadTotal),
        ProcessSortColumn.total => (a.downloadTotal + a.uploadTotal)
            .compareTo(b.downloadTotal + b.uploadTotal),
      };
  int compareAll(ProcessTraffic a, ProcessTraffic b) {
    final c = compare(a, b);
    if (c != 0) return c;
    return a.name.compareTo(b.name);
  }

  result.sort((a, b) => ascending ? compareAll(a, b) : -compareAll(a, b));
  return result;
}
