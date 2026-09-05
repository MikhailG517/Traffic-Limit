import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/system_settings_service.dart';
import '../services/logger_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage(
      {super.key,
      required this.settings,
      required this.onChanged,
      required this.system,
      required this.logger,
      required this.onExit});
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final SystemSettingsService system;
  final LoggerService logger;
  final Future<void> Function() onExit;
  Future<void> _autostart(BuildContext context, bool enabled) async {
    final ok = await system.setAutostart(enabled);
    if (!context.mounted) return;
    if (ok) {
      onChanged(settings.copyWith(autostart: enabled));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось изменить автозапуск Windows.')));
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
      title: 'Настройки',
      child: SectionCard(
          child: Column(children: [
        ToggleRow(
            title: 'Запускать вместе с системой',
            description:
                'Запись создаётся в реестре Windows для текущего пользователя',
            value: settings.autostart,
            onChanged: (value) => _autostart(context, value)),
        const Divider(color: AppColors.border),
        ToggleRow(
            title: 'Показывать скорость в трее',
            description:
                'Tooltip иконки в системном трее обновляется каждую секунду',
            value: settings.traySpeed,
            onChanged: (value) =>
                onChanged(settings.copyWith(traySpeed: value))),
        const Divider(color: AppColors.border),
        ToggleRow(
            title: 'Уведомления о лимитах',
            description: 'Показывать предупреждение при достижении лимита',
            value: settings.limitNotifications,
            onChanged: (value) =>
                onChanged(settings.copyWith(limitNotifications: value))),
        const Divider(color: AppColors.border),
        ToggleRow(
            title: 'Диагностика',
            description:
                'Подробное логирование запуска, трея, лимита и скорости приложений',
            value: settings.diagnostics,
            onChanged: (value) =>
                onChanged(settings.copyWith(diagnostics: value))),
        const Divider(color: AppColors.border),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              const Expanded(
                  child: Text('Журнал приложения',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              OutlinedButton.icon(
                  onPressed: () => logger.openLogFolder(),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Папка с логами')),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                  onPressed: () async {
                    final path = await logger.export();
                    if (path.isNotEmpty && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Лог сохранён: $path')));
                    }
                  },
                  icon: const Icon(Icons.save_alt_rounded, size: 18),
                  label: const Text('Экспорт')),
            ])),
        const Divider(color: AppColors.border),
        Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Row(children: [
              const Expanded(
                  child: Text('Завершение приложения',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              OutlinedButton.icon(
                  onPressed: onExit,
                  icon: const Icon(Icons.power_settings_new_rounded),
                  label: const Text('Завершить')),
            ])),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Тема оформления',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Применяется немедленно и сохраняется',
                        style: TextStyle(color: AppColors.muted, fontSize: 13))
                  ])),
              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'dark', label: Text('Тёмная')),
                    ButtonSegment(value: 'light', label: Text('Светлая'))
                  ],
                  selected: {
                    settings.themeMode
                  },
                  onSelectionChanged: (value) =>
                      onChanged(settings.copyWith(themeMode: value.first)))
            ])),
      ])));
}
