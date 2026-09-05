class LaunchOptions {
  const LaunchOptions(this.arguments);
  final List<String> arguments;

  bool get diagnostics => arguments.contains('--diagnostics');
  // Allows forcing the window to be shown (e.g. manual CLI launch).
  bool get showWindow => arguments.contains('--show');
}
