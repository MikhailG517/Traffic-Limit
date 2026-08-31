class LaunchOptions {
  const LaunchOptions(this.arguments);
  final List<String> arguments;

  bool get startHidden => arguments.contains('--autostart');
}
