$ErrorActionPreference = 'Stop'
Write-Host 'Сборка Traffic Limit для Windows 11' -ForegroundColor Cyan
flutter pub get
flutter config --enable-windows-desktop
flutter build windows --release
New-Item -ItemType Directory -Force build/native | Out-Null
cmake -S windows/native/TrafficLimitService -B build/native/cmake -DTRAFFIC_LIMIT_USE_WINDIVERT=OFF
cmake --build build/native/cmake --config Release
Copy-Item build/native/cmake/Release/TrafficLimitService.exe build/native/TrafficLimitService.exe -Force
if (Get-Command iscc -ErrorAction SilentlyContinue) { iscc installer/TrafficLimit.iss } else { Write-Warning 'Inno Setup не найден: установите Inno Setup 6 и повторите iscc installer/TrafficLimit.iss' }
