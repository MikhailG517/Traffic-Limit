import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/traffic_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LimitsPage extends StatefulWidget {
  const LimitsPage(
      {super.key,
      required this.settings,
      required this.onChanged,
      required this.traffic});
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final TrafficService traffic;
  @override
  State<LimitsPage> createState() => _LimitsPageState();
}

class _LimitsPageState extends State<LimitsPage> {
  late double download;
  late double upload;
  bool applying = false;
  bool enabled = false;
  @override
  void initState() {
    super.initState();
    download = widget.settings.downloadLimit;
    upload = widget.settings.uploadLimit;
    enabled = widget.settings.limitsEnabled;
  }

  Future<void> apply() async {
    setState(() => applying = true);
    final available =
        await widget.traffic.setLimitsEnabled(enabled, download, upload);
    if (available) {
      widget.onChanged(widget.settings.copyWith(
          limitsEnabled: enabled,
          downloadLimit: download,
          uploadLimit: upload));
    } else {
      setState(() => enabled = false);
    }
    if (mounted) {
      setState(() => applying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(available
              ? (enabled ? 'Ограничения включены.' : 'Ограничения отключены.')
              : 'Не удалось изменить состояние: нужна служба и подписанный WinDivert-драйвер.')));
    }
  }

  Future<void> toggle(bool value) async {
    setState(() => enabled = value);
    await apply();
  }

  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Ограничения',
      child: Column(children: [
        SectionCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Скорость соединения',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            FilledButton.icon(
                onPressed: applying ? null : () => toggle(!enabled),
                icon: Icon(enabled
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded),
                label: Text(enabled ? 'Отключить' : 'Включить')),
          ]),
          const SizedBox(height: 18),
          _speed(
              'Входящая скорость',
              download,
              AppColors.green,
              (v) => setState(() => download = v),
              Icons.arrow_downward_rounded),
          const SizedBox(height: 12),
          _speed('Исходящая скорость', upload, AppColors.red,
              (v) => setState(() => upload = v), Icons.arrow_upward_rounded),
          const SizedBox(height: 10),
        ])),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
              child: _limitCard(
                  'Дневной лимит',
                  widget.settings.dailyLimit,
                  (v) => widget
                      .onChanged(widget.settings.copyWith(dailyLimit: v)))),
          const SizedBox(width: 16),
          Expanded(
              child: _limitCard(
                  'Месячный лимит',
                  widget.settings.monthlyLimit,
                  (v) => widget
                      .onChanged(widget.settings.copyWith(monthlyLimit: v))))
        ]),
        const SizedBox(height: 18),
        SectionCard(
            child: ToggleRow(
                title: 'Автопауза при достижении лимита',
                description:
                    'Остановить ограничение при достижении месячного лимита',
                value: widget.settings.autoPauseAtLimit,
                onChanged: (value) => widget.onChanged(
                    widget.settings.copyWith(autoPauseAtLimit: value))))
      ]));
  Widget _speed(String title, double value, Color color,
          ValueChanged<double> onChanged, IconData icon) =>
      Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        SizedBox(
            width: 150,
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
            child: Slider(
                value: value,
                min: 0.1,
                max: 500,
                divisions: 999,
                onChanged: onChanged,
                onChangeEnd: (_) {
                  if (enabled) apply();
                })),
        SizedBox(
            width: 92,
            child: Text('${value.toStringAsFixed(1)} Мбит/с',
                style: TextStyle(color: color, fontWeight: FontWeight.w700)))
      ]);
  Widget _limitCard(
          String title, double value, ValueChanged<double> onChange) =>
      SectionCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Text('${value.toStringAsFixed(0)} ГБ',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        Slider(
            value: value.clamp(1, 100),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: onChange)
      ]));
}
