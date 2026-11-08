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
      subtitle: 'Запуск, трей, журнал и оформление',
      child: SingleChildScrollView(
          child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(children: [
                ToggleRow(
                    icon: Icons.power_rounded,
                    title: 'Запускать вместе с системой',
                    description:
                        'Запись создаётся в реестре Windows для текущего пользователя',
                    value: settings.autostart,
                    onChanged: (value) => _autostart(context, value)),
                Divider(color: Palette.of(context).border, height: 1),
                ToggleRow(
                    icon: Icons.swap_vert_rounded,
                    title: 'Показывать скорость в трее',
                    description:
                        'Tooltip иконки в системном трее обновляется каждую секунду',
                    value: settings.traySpeed,
                    onChanged: (value) =>
                        onChanged(settings.copyWith(traySpeed: value))),
                Divider(color: Palette.of(context).border, height: 1),
                ToggleRow(
                    icon: Icons.notifications_active_rounded,
                    title: 'Уведомления о лимитах',
                    description:
                        'Показывать предупреждение при достижении лимита',
                    value: settings.limitNotifications,
                    onChanged: (value) => onChanged(
                        settings.copyWith(limitNotifications: value))),
                Divider(color: Palette.of(context).border, height: 1),
                ToggleRow(
                    icon: Icons.bug_report_rounded,
                    title: 'Диагностика',
                    description:
                        'Подробное логирование запуска, трея, лимита и скорости приложений',
                    value: settings.diagnostics,
                    onChanged: (value) =>
                        onChanged(settings.copyWith(diagnostics: value))),
                Divider(color: Palette.of(context).border, height: 1),
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
                                  SnackBar(
                                      content: Text('Лог сохранён: $path')));
                            }
                          },
                          icon: const Icon(Icons.save_alt_rounded, size: 18),
                          label: const Text('Экспорт')),
                    ])),
                Divider(color: Palette.of(context).border, height: 1),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      const IconBadge(
                          icon: Icons.palette_rounded, color: AppColors.violet),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Тема оформления',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('Применяется немедленно и сохраняется',
                                style: TextStyle(
                                    color: Palette.of(context).muted,
                                    fontSize: 13))
                          ])),
                      PillTabs<String>(
                          values: const ['dark', 'light'],
                          selected: settings.themeMode,
                          label: (v) => v == 'dark' ? 'Тёмная' : 'Светлая',
                          onChanged: (v) =>
                              onChanged(settings.copyWith(themeMode: v)))
                    ])),
              ]))));
}
