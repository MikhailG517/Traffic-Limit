import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traffic_limit/app.dart';
import 'package:traffic_limit/models/traffic_models.dart';
import 'package:traffic_limit/pages/dashboard_page.dart';
import 'package:traffic_limit/services/logger_service.dart';
import 'package:traffic_limit/services/rate_math.dart';
import 'package:traffic_limit/services/traffic_service.dart';
import 'package:traffic_limit/theme.dart';
import 'package:traffic_limit/widgets/ambient_clock.dart';
import 'package:traffic_limit/widgets/animated_brand.dart';

/// Rebuilds the dashboard once per second with new numbers, like the app.
class _Host extends StatefulWidget {
  const _Host(this.traffic);
  final TrafficService traffic;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int tick = 0;
  void next() => setState(() {
        tick++;
        widget.traffic.stats = TrafficStats(
            downloadRate: 9000 + tick * 370.0,
            uploadRate: 1200 + tick * 110.0,
            status: TrafficStatus.active);
      });

  @override
  Widget build(BuildContext context) => MaterialApp(
      theme: appTheme,
      home: Scaffold(
          backgroundColor: Colors.transparent,
          body: AuroraBackground(
              child: Row(children: [
            NavigationRailPanel(
                selected: 0,
                used: widget.traffic.monthlyTotal,
                monthlyLimit: 300,
                limitsEnabled: false,
                onSelected: (_) {}),
            Expanded(
                child: DashboardPage(
                    stats: widget.traffic.stats,
                    service: widget.traffic,
                    monthlyLimitGb: 300,
                    onOpenLimits: () {})),
          ]))));
}

void Function(Duration)? _active;

void main() {
  testWidgets('dashboard frame rate follows window state', (tester) async {
    tester.view.physicalSize = const Size(1360, 860);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 11, 8, 14);
    final traffic =
        TrafficService(LoggerService(), await SharedPreferences.getInstance())
          ..clock = () => now;
    traffic.recordCounters({'eth': const AdapterCounters(0, 0)}, now);
    final clock = AmbientClock.instance
      ..setWindowState(visible: true, focused: true);
    SchedulerBinding.instance
        .addPersistentFrameCallback((t) => _active?.call(t));
    await tester.pumpWidget(_Host(traffic));
    await tester.pump(const Duration(seconds: 2));
    final host = tester.state<_HostState>(find.byType(_Host));

    // Counts frames that would reach the GPU during 10 s of simulated time
    // with a data update every second.
    Future<double> fps() async {
      const step = Duration(microseconds: 4167); // 240 Hz, finer than vsync
      var frames = 0;
      _active = (_) => frames++;
      var elapsed = Duration.zero;
      var nextUpdate = const Duration(seconds: 1);
      while (elapsed < const Duration(seconds: 10)) {
        if (elapsed >= nextUpdate) {
          host.next();
          nextUpdate += const Duration(seconds: 1);
        }
        await tester.pump(step);
        elapsed += step;
      }
      _active = null;
      return frames / 10;
    }

    final focused = await fps();
    clock.setWindowState(focused: false);
    final blurred = await fps();
    clock.setWindowState(visible: false);
    final hidden = await fps();

    // Data updates add a few frames per second on top of the clock rate.
    expect(focused, lessThanOrEqualTo(AmbientClock.focusedFps + 6));
    expect(blurred, lessThanOrEqualTo(AmbientClock.backgroundFps + 6));
    expect(hidden, lessThanOrEqualTo(6));
    expect(clock.fps, 0);

    await tester.pumpWidget(const SizedBox());
    clock.setWindowState(visible: true, focused: true);
  });
}
