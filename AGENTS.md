# Контекст Traffic Limit

- Проект создаётся под Windows 11, пользовательский интерфейс и сообщения — на русском языке.
- Модули: `lib/models`, `lib/services`, `lib/widgets`, `lib/pages`; нативная служба находится в `windows/native/TrafficLimitService`.
- Flutter SDK отсутствует в текущем Linux-контейнере; сборка выполняется локально на Windows.
- Фактическое ограничение пакетов включается только в сборке с подписанным WinDivert SDK; fallback всегда честно показывает недоступность.

- `installer/TrafficLimit.iss` ожидает release Flutter bundle и `build/native/TrafficLimitService.exe`; иконка — `assets/traffic_limit.ico`.
