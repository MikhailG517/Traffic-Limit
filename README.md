# Traffic Limit

Русскоязычное Flutter-приложение для Windows 11: мониторинг интерфейсов, скорости, объёма данных, лимитов, автозапуска, системного трея и журнала событий.

## Архитектура

- `lib/models` — модели трафика и форматирование.
- `lib/services` — мониторинг, настройки, логирование и трей.
- `lib/widgets` — переиспользуемые компоненты тёмной темы.
- `lib/pages` — отдельные экраны: обзор, графики, ограничения, настройки.
- `windows/native/TrafficLimitService` — нативная служба с named pipe и чтением счётчиков Windows `GetIfTable2`.
- `installer/TrafficLimit.iss` — графический однофайловый мастер Inno Setup.

## Сборка на локальной Windows-машине

Требуется Flutter 3.19+, Visual Studio 2022 с Desktop development with C++, CMake, Inno Setup 6 и Windows 11 SDK.

```powershell
flutter create . --platforms=windows
flutter pub get
.\build_windows.ps1
```

`flutter create .` генерирует стандартный `windows/runner` и Flutter ephemeral-файлы, не изменяя модуль службы. После сборки установщик находится в `dist/TrafficLimit-Setup-1.0.0.exe`.

## Фактическое ограничение скорости

Сборка по умолчанию намеренно сообщает «ограничение недоступно»: системный Windows QoS не предоставляет безопасного универсального token-bucket ограничения для всего трафика из user-mode. Для фактического ограничения используется WinDivert: скачайте официальный WinDivert SDK, положите `include/WinDivert.h` и x64 библиотеку в `windows/native/TrafficLimitService/third_party/WinDivert/`, затем соберите:

```powershell
cmake -S windows/native/TrafficLimitService -B build/native/cmake -DTRAFFIC_LIMIT_USE_WINDIVERT=ON
cmake --build build/native/cmake --config Release
```

WinDivert.sys является kernel-mode драйвером. Для production необходима проверенная совместимая версия, корректная установка от администратора и подпись/политика загрузки драйверов Windows. Не отключайте Secure Boot и проверку подписи на пользовательских системах. Перед распространением подпишите приложение, службу и установщик сертификатом издателя.

## Проверка

Проверить приложение можно на чистой VM Windows 11: установка с UAC, создание ярлыка, перезагрузка, трей, смена переключателей, изменение лимитов, экспорт `%APPDATA%\Traffic Limit\traffic-limit.log`, остановка службы и удаление. Для проверки фактического лимита используйте `iperf3` до/после установки и сравните среднюю скорость; без WinDivert сборка ограничение не имитирует.

В рабочую директорию установлен Flutter SDK 3.47.2 и зависимости проекта; Linux-хост не поддерживает `flutter build windows`, поэтому Windows-сборка здесь не выполнялась. Для неё нужен локальный Windows-хост с Visual Studio, Windows SDK и Inno Setup. Исходники и скрипт production-сборки подготовлены для запуска на локальной машине с указанными зависимостями.

## Документы

- [Архитектура](docs/ARCHITECTURE.md)
- [Сборка](docs/BUILD.md)
- [Руководство пользователя](docs/USER_GUIDE.md)
- [Тестирование](docs/TESTING.md)
- [Безопасность](docs/SECURITY.md)
