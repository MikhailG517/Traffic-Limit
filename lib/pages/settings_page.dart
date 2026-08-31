import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/system_settings_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage(
      {super.key,
      required this.settings,
      required this.onChanged,
      required this.system});
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final SystemSettingsService system;
  Future<void> _autostart(BuildContext context, bool enabled) async {
    final ok = await system.setAutostart(enabled);
    if (!context.mounted) return;
    if (ok)
      onChanged(settings.copyWith(autostart: enabled));
    else
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось изменить автозапуск Windows.')));
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
