param(
    [string]$ExePath,
    [int]$SampleSeconds = 60,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if ($Build) {
    Write-Host 'Сборка приложения...' -ForegroundColor Cyan
    & (Join-Path $root 'build_windows.ps1')
}

if (-not $ExePath) {
    $ExePath = Join-Path $root 'build\windows\x64\runner\Release\traffic_limit.exe'
}
if (-not (Test-Path $ExePath)) {
    Write-Error "Не найден исполняемый файл: $ExePath. Укажите -ExePath или соберите через -Build."
}

Write-Host "Запуск: $ExePath" -ForegroundColor Cyan
$proc = Start-Process -FilePath $ExePath -PassThru
Start-Sleep -Seconds 5   # дать приложению инициализироваться и пройти стартовый пик

$interval = 1.0
$cpuPrev = 0.0
$memSamples = New-Object System.Collections.Generic.List[double]
$cpuSamples = New-Object System.Collections.Generic.List[double]
for ($i = 0; $i -lt $SampleSeconds; $i++) {
    try {
        $p = Get-Process -Id $proc.Id -ErrorAction Stop
        $memSamples.Add(($p.WorkingSet64 / 1MB))
        $cpuNow = $p.CPU
        if ($cpuPrev -gt 0) {
            # Процент на одно логическое ядро: (прирост CPU-времени / интервал) * 100
            $perCore = (($cpuNow - $cpuPrev) / $interval) * 100
            $total = $perCore / [System.Environment]::ProcessorCount
            $cpuSamples.Add($total)
        }
        $cpuPrev = $cpuNow
    } catch { }
    Start-Sleep -Seconds $interval
}

try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch { }

function Avg($list) { if ($list.Count -eq 0) { return 0 } return ($list | Measure-Object -Average).Average }
function Max($list) { if ($list.Count -eq 0) { return 0 } return ($list | Measure-Object -Maximum).Maximum }
function Min($list) { if ($list.Count -eq 0) { return 0 } return ($list | Measure-Object -Minimum).Minimum }

Write-Host ''
Write-Host '=== Результаты замеров ресурсов ===' -ForegroundColor Green
Write-Host ("ОЗУ (WorkingSet, МБ): min={0:N1} avg={1:N1} max={2:N1}" -f (Min $memSamples), (Avg $memSamples), (Max $memSamples))
Write-Host ("ЦПУ (% от всей машины):  min={0:N2} avg={1:N2} max={2:N2}" -f (Min $cpuSamples), (Avg $cpuSamples), (Max $cpuSamples))
Write-Host ("Логических ядер: {0}" -f [System.Environment]::ProcessorCount)
