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
- WinDivert FLOW/SOCKET `LocalPort`/`RemotePort` приходят в host byte order — их НЕ нужно обрабатывать `ntohs` (в отличие от TCP/UDP header и MIB-таблиц, где сетевой порядок). Неверный `ntohs` в flowLoop ломает связывание flow↔packet и даёт нулевые скорости приложений.
- Диагностика включается: флагом запуска `--diagnostics`, переключателем «Диагностика» в Настройках или пунктом меню трея «Диагностика».
- Логи пишутся в каталог приложения (`getApplicationSupportDirectory`) в файл `traffic-limit.log` с уровнями DEBUG/INFO/WARN/ERROR, метками времени и stack trace. Пути к секретам маскируются (`<filtered>`). Открыть папку/экспорт — кнопки в Настройках и пункт трея «Открыть журнал/логи».
- Приложение стартует свёрнутым в трей (окно не показывается); открыть окно — пункт трея «Открыть Traffic Limit» или флаг `--show`.
- Сборка службы — GUI-подсистема (`WIN32`), поэтому `GetStdHandle(STDOUT)` при запуске из Flutter невалиден: `--get-processes`, `--get-status` и проверка `"limiter":true` получали пустой stdout. Ответ теперь пишется во временный файл по `--out=<path>`, а Flutter читает его; буфер ответа 256 КБ, pipe in/out по 4 МБ.


- Старт в трей: шаблонный `SetNextFrameCallback(Show)` в `windows/runner/flutter_window.cpp` удалён — он показывал окно после `hide()` из Dart. Окно показывает только Dart (`--show` или трей).
- Позиция иконки в трее: Windows запоминает её по (путь exe, hWnd, uID). `tray_manager` 0.2.4 не задавал `uID` (мусор из стека) → после перезагрузки иконка считалась новой и уходила в скрытую область. Нужен tray_manager ≥ 0.5.2 (`uID = 1`, восстановление по `TaskbarCreated`). 0.6+ требует другой API (nativeapi).
- Учёт объёма: `TrafficLedger` (часы 8 дней, дни 400 дней) по календарю: сегодня с 00:00, неделя с понедельника, месяц с 1-го. Счётчики читаются по каждому физическому адаптеру; новый адаптер только задаёт базу (иначе в «сегодня» попадает трафик с момента загрузки ОС).
- Шрифт интерфейса — Manrope (OFL, `assets/fonts`), Material Icons для тестов-скриншотов грузить через `FontLoader` из `.flutter-sdk/bin/cache/artifacts/material_fonts`.
