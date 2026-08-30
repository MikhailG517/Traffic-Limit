import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage(
      {super.key,
      required this.settings,
      required this.onChanged,
      required this.logger});
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final LoggerService logger;
  Future<void> _showLogs(BuildContext context) async {
    final text = await logger.read();
    if (!context.mounted) return;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Журнал работы'),
                content: SizedBox(
                    width: 640,
                    height: 360,
                    child: SingleChildScrollView(child: SelectableText(text))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрыть')),
                  FilledButton(
                      onPressed: () async {
                        final path = await logger.export();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Лог экспортирован: $path')));
                        }
                      },
                      child: const Text('Экспорт'))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    final settingsCard = SectionCard(
        child: Column(children: [
      ToggleRow(
          title: 'Запускать вместе с системой',
          description: 'Автостарт при входе в Windows',
          value: settings.autostart,
          onChanged: (v) => onChanged(settings.copyWith(autostart: v))),
      const Divider(color: AppColors.border),
      ToggleRow(
          title: 'Показывать скорость в трее',
          description: 'Компактный индикатор в системном трее',
          value: settings.traySpeed,
          onChanged: (v) => onChanged(settings.copyWith(traySpeed: v))),
      const Divider(color: AppColors.border),
      ToggleRow(
          title: 'Уведомления о лимитах',
          description: 'Предупреждать при 80% и 100% лимита',
          value: settings.limitNotifications,
          onChanged: (v) =>
              onChanged(settings.copyWith(limitNotifications: v))),
      const Divider(color: AppColors.border),
      _selectRow('Единицы измерения', 'Формат отображения скорости',
          'Кбит/с · Мбит/с'),
      const Divider(color: AppColors.border),
      _selectRow('Тема оформления', 'Тёмная тема рекомендована', 'Тёмная'),
    ]));
    final logsCard = SectionCard(
        child: Row(children: [
      const Icon(Icons.article_outlined, color: AppColors.lightBlue),
      const SizedBox(width: 14),
      const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Журнал работы', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Логи приложения, службы и ошибок',
            style: TextStyle(color: AppColors.muted))
      ])),
      OutlinedButton.icon(
          onPressed: () => _showLogs(context),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Просмотреть')),
    ]));
    return PageShell(
        title: 'Настройки',
        child: Column(
            children: [settingsCard, const SizedBox(height: 18), logsCard]));
  }

  Widget _selectRow(String title, String desc, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(color: AppColors.muted, fontSize: 13))
        ])),
        Chip(label: Text(value))
      ]));
}
