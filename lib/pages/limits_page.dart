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
  @override
  void initState() {
    super.initState();
    download = widget.settings.downloadLimit;
    upload = widget.settings.uploadLimit;
  }

  Future<void> apply() async {
    setState(() => applying = true);
    final available = await widget.traffic.applyLimit(download, upload);
    widget.onChanged(
        widget.settings.copyWith(downloadLimit: download, uploadLimit: upload));
    if (mounted) {
      setState(() => applying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(available
              ? 'Ограничение применено к службе.'
              : 'Ограничение не применено: требуется подписанный WinDivert-драйвер и права администратора.')));
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Ограничения',
      child: Column(children: [
        SectionCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Скорость соединения',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
          Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                  onPressed: applying ? null : apply,
                  icon: applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label:
                      Text(applying ? 'Применение…' : 'Применить ограничения')))
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Расписание ограничений',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, children: [
            _chip('Пн–Чт · 09:00–18:00'),
            _chip('Ночной режим · 23:00–07:00'),
            ActionChip(
                label: const Text('+ Добавить'),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Создание расписания будет доступно после установки службы.'))))
          ])
        ])),
        const SizedBox(height: 18),
        SectionCard(
            child: ToggleRow(
                title: 'Автопауза при достижении лимита',
                description:
                    'Полностью останавливать трафик при исчерпании лимита',
                value: false,
                onChanged: (_) {}))
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
                max: 100,
                divisions: 999,
                onChanged: onChanged)),
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
  Widget _chip(String text) => Chip(
      label: Text(text,
          style: const TextStyle(
              color: AppColors.cyan, fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.cyan.withOpacity(.08),
      side: BorderSide(color: AppColors.cyan.withOpacity(.35)));
}
