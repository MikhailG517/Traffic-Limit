import 'package:flutter/material.dart';
import '../models/traffic_models.dart';
import '../services/settings_service.dart';
import '../services/limit_validation.dart';
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
  late final TextEditingController downloadController;
  late final TextEditingController uploadController;
  bool applying = false;
  bool enabled = false;
  @override
  void initState() {
    super.initState();
    download = widget.settings.downloadLimit;
    upload = widget.settings.uploadLimit;
    downloadController = TextEditingController(text: download.toString());
    uploadController = TextEditingController(text: upload.toString());
    enabled = widget.settings.limitsEnabled;
  }

  @override
  void didUpdateWidget(covariant LimitsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.downloadLimit != download ||
        widget.settings.uploadLimit != upload) {
      download = widget.settings.downloadLimit;
      upload = widget.settings.uploadLimit;
      downloadController.text = download.toString();
      uploadController.text = upload.toString();
    }
    enabled = widget.settings.limitsEnabled;
  }

  @override
  void dispose() {
    downloadController.dispose();
    uploadController.dispose();
    super.dispose();
  }

  double? _readLimit(TextEditingController controller) =>
      parseLimit(controller.text);

  void _persist({bool? switchEnabled}) {
    final enteredDownload = _readLimit(downloadController);
    final enteredUpload = _readLimit(uploadController);
    if (enteredDownload == null || enteredUpload == null) return;
    download = enteredDownload;
    upload = enteredUpload;
    widget.onChanged(widget.settings.copyWith(
        limitsEnabled: switchEnabled ?? enabled,
        downloadLimit: download,
        uploadLimit: upload));
  }

  Future<void> _applyAndPersist({bool? switchEnabled}) async {
    final nextEnabled = switchEnabled ?? enabled;
    final enteredDownload = _readLimit(downloadController);
    final enteredUpload = _readLimit(uploadController);
    if (enteredDownload == null || enteredUpload == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Введите положительные значения от 0.1 до 500000 Мбит/с.')));
      }
      return;
    }
    download = enteredDownload;
    upload = enteredUpload;
    setState(() => applying = true);
    final available =
        await widget.traffic.setLimitsEnabled(nextEnabled, download, upload);
    if (available) {
      widget.onChanged(widget.settings.copyWith(
          limitsEnabled: nextEnabled,
          downloadLimit: download,
          uploadLimit: upload));
    } else {
      setState(() => enabled = false);
    }
    if (mounted) {
      setState(() => applying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(available
              ? (nextEnabled
                  ? 'Ограничения включены.'
                  : 'Ограничения отключены.')
              : 'Не удалось изменить состояние: нужна служба и подписанный WinDivert-драйвер.')));
    }
  }

  Future<void> toggle(bool value) async {
    setState(() => enabled = value);
    await _applyAndPersist(switchEnabled: value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return PageShell(
        title: 'Ограничения',
        subtitle: 'Скорость канала и лимиты объёма трафика',
        action: LivePill(
            active: enabled,
            label: enabled ? 'ЛИМИТ ВКЛЮЧЁН' : 'ЛИМИТ ВЫКЛЮЧЕН'),
        child: SingleChildScrollView(
            child: Column(children: [
          GlassCard(
              accent: enabled ? AppColors.amber : AppColors.blue,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconBadge(
                          icon: Icons.speed_rounded,
                          color: enabled ? AppColors.amber : AppColors.blue),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Скорость соединения',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(
                                enabled
                                    ? 'Применяется ко всему трафику через WinDivert'
                                    : 'Ограничение не действует',
                                style: TextStyle(
                                    color: palette.muted, fontSize: 12)),
                          ])),
                      FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor:
                                  enabled ? AppColors.red : AppColors.blue),
                          onPressed: applying ? null : () => toggle(!enabled),
                          icon: applying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(enabled
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded),
                          label: Text(enabled ? 'Отключить' : 'Включить')),
                    ]),
                    const SizedBox(height: 22),
                    _speed('Входящая', download, AppColors.download, (v) {
                      setState(() {
                        download = v;
                        downloadController.text = v.toStringAsFixed(1);
                      });
                      _persist();
                    }, Icons.south_rounded),
                    const SizedBox(height: 8),
                    _speed('Исходящая', upload, AppColors.upload, (v) {
                      setState(() {
                        upload = v;
                        uploadController.text = v.toStringAsFixed(1);
                      });
                      _persist();
                    }, Icons.north_rounded),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: _manualLimit(
                              'Входящая, Мбит/с',
                              downloadController,
                              (value) => setState(() => download = value))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _manualLimit(
                              'Исходящая, Мбит/с',
                              uploadController,
                              (value) => setState(() => upload = value))),
                    ]),
                  ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _limitCard(
                    'Дневной лимит',
                    widget.settings.dailyLimit,
                    widget.traffic.today.total,
                    Icons.today_rounded,
                    (v) => widget
                        .onChanged(widget.settings.copyWith(dailyLimit: v)))),
            const SizedBox(width: 16),
            Expanded(
                child: _limitCard(
                    'Месячный лимит',
                    widget.settings.monthlyLimit,
                    widget.traffic.month.total,
                    Icons.calendar_month_rounded,
                    (v) => widget
                        .onChanged(widget.settings.copyWith(monthlyLimit: v))))
          ]),
          const SizedBox(height: 16),
          GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: ToggleRow(
                  icon: Icons.pause_rounded,
                  title: 'Автопауза при достижении лимита',
                  description:
                      'Остановить ограничение при достижении месячного лимита',
                  value: widget.settings.autoPauseAtLimit,
                  onChanged: (value) => widget.onChanged(
                      widget.settings.copyWith(autoPauseAtLimit: value))))
        ])));
  }

  Widget _speed(String title, double value, Color color,
          ValueChanged<double> onChanged, IconData icon) =>
      Row(children: [
        IconBadge(icon: icon, color: color),
        const SizedBox(width: 12),
        SizedBox(
            width: 96,
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
            child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    overlayColor: color.withValues(alpha: .18)),
                child: Slider(
                    value: value.clamp(0.1, 500),
                    min: 0.1,
                    max: 500,
                    divisions: 999,
                    onChanged: onChanged,
                    onChangeEnd: (_) {
                      if (enabled) _applyAndPersist();
                    }))),
        SizedBox(
            width: 110,
            child: Text('${value.toStringAsFixed(1)} Мбит/с',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])))
      ]);

  Widget _manualLimit(String label, TextEditingController controller,
          ValueChanged<double> onChanged) =>
      TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: 'Мбит/с'),
          onChanged: (text) {
            final value = parseLimit(text);
            if (value != null) {
              onChanged(value);
              _persist();
            }
          });

  Widget _limitCard(String title, double limitGb, double usedMb, IconData icon,
      ValueChanged<double> onChange) {
    final palette = Palette.of(context);
    final ratio =
        limitGb <= 0 ? 0.0 : (usedMb / (limitGb * 1024)).clamp(0.0, 1.0);
    final color = ratio >= 1
        ? AppColors.red
        : ratio >= .8
            ? AppColors.amber
            : AppColors.green;
    return GlassCard(
        accent: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700))),
            Text('${limitGb.toStringAsFixed(0)} ГБ',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: palette.cardHigh,
                      valueColor: AlwaysStoppedAnimation(color)))),
          const SizedBox(height: 8),
          Text('Использовано ${formatData(usedMb)} · ${(ratio * 100).round()}%',
              style: TextStyle(color: palette.muted, fontSize: 12)),
          Slider(
              value: limitGb.clamp(1, 100),
              min: 1,
              max: 100,
              divisions: 99,
              onChanged: onChange)
        ]));
  }
}
