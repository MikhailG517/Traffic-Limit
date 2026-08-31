# Контекст Traffic Limit

- Проект создаётся под Windows 11, пользовательский интерфейс и сообщения — на русском языке.
- Модули: `lib/models`, `lib/services`, `lib/widgets`, `lib/pages`; нативная служба находится в `windows/native/TrafficLimitService`.
- Flutter SDK отсутствует в текущем Linux-контейнере; сборка выполняется локально на Windows.
- Фактическое ограничение пакетов включается только в сборке с подписанным WinDivert SDK; fallback всегда честно показывает недоступность.

- `installer/TrafficLimit.iss` ожидает release Flutter bundle и `build/native/TrafficLimitService.exe`; иконка — `assets/traffic_limit.ico`.
- `tray_manager` для Windows принимает путь к иконке относительно Flutter assets (`assets/traffic_limit.ico`), а контекстное меню требуется явно открыть через `onTrayIconRightMouseDown → popUpContextMenu()`.
- `WinDivertOpen` при ошибке возвращает `INVALID_HANDLE_VALUE`, а не `nullptr`; проверять оба варианта до запуска telemetry worker.
- Для точного ограничения не задерживать каждый пакет: нужен deadline pacer и отдельные handles/workers для inbound/outbound. Малые control/DNS пакеты пропускаются без задержки.
- PID telemetry использует flow binding плюс fallback по локальному TCP/UDP порту из `GetExtendedTcpTable`/`GetExtendedUdpTable` для уже существующих соединений.

