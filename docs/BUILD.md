# Сборка и публикация

## Требования для Windows 11

- Flutter 3.47+ и Dart из Flutter SDK;
- Visual Studio 2022 с workload **Desktop development with C++**;
- Windows 11 SDK и CMake;
- Inno Setup 6;
- WinDivert 2.2.2 x64 уже включён в `windows/native/TrafficLimitService/third_party/WinDivert/`.

## Быстрая сборка

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
.\build_windows.ps1
```

Скрипт собирает Flutter release, C++ service и запускает `iscc installer/TrafficLimit.iss`. Результат: `dist/TrafficLimit-Setup-1.0.0.exe`.

## WinDivert

Официальный WinDivert 2.2.2 x64 уже включён в исходники и установщик. Для обновления runtime замените SDK в в `windows/native/TrafficLimitService/third_party/WinDivert/`:

```text
third_party/WinDivert/include/WinDivert.h
third_party/WinDivert/x64/WinDivert.lib
```

Соберите service с `-DTRAFFIC_LIMIT_USE_WINDIVERT=ON`. Kernel driver должен быть совместим с Windows 11 и подписан издателем. Не отключайте Secure Boot или проверку подписи.

## Локальная установка SDK в этом репозитории

В Linux-контейнере проекта Flutter SDK хранится в `.flutter-sdk/` и не включается в Git. На Windows используйте официальный установщик Flutter или архив с `flutter.dev`.
