import 'dart:async';

import 'package:flutter/foundation.dart';

/// Low-rate clock shared by all decorative animations.
///
/// An `AnimationController` ticks at the display refresh rate (60–144 Hz),
/// and every tick re-composites the whole window on the GPU. Decorative motion
/// does not need that: this clock notifies its listeners at [focusedFps] while
/// the window is focused, at [backgroundFps] while it is visible but
/// unfocused, and stops completely while the window is hidden in the tray or
/// minimised, or when nothing listens.
class AmbientClock extends ChangeNotifier {
  AmbientClock._();
  static final instance = AmbientClock._();

  static const focusedFps = 30;
  static const backgroundFps = 10;

  final _watch = Stopwatch();
  Timer? _timer;
  int _fps = 0;
  bool _visible = true;
  bool _focused = true;

  /// Seconds of running time; frozen while the clock is stopped.
  double get seconds =>
      _watch.elapsedMicroseconds / Duration.microsecondsPerSecond;

  /// Current tick rate, 0 when stopped.
  int get fps => _fps;

  void setWindowState({bool? visible, bool? focused}) {
    _visible = visible ?? _visible;
    _focused = focused ?? _focused;
    _update();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _update();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _update();
  }

  void _update() {
    final fps = !_visible || !hasListeners
        ? 0
        : _focused
            ? focusedFps
            : backgroundFps;
    if (fps == _fps) return;
    _fps = fps;
    _timer?.cancel();
    _timer = null;
    if (fps == 0) {
      _watch.stop();
      return;
    }
    _watch.start();
    _timer = Timer.periodic(
        Duration(microseconds: Duration.microsecondsPerSecond ~/ fps),
        (_) => notifyListeners());
  }
}
