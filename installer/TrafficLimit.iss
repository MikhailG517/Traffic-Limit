#define AppName "Traffic Limit"
#define AppVersion "1.0.0"
#define AppPublisher "Traffic Limit"
#define AppExeName "traffic_limit.exe"
[Setup]
AppId={{B7DF3D3A-8D24-4F01-9E5B-TRAFFICLIMIT}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Traffic Limit
DefaultGroupName={#AppName}
OutputDir=..\dist
OutputBaseFilename=TrafficLimit-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
SetupIconFile=..\assets\traffic_limit.ico
UninstallDisplayIcon={app}\traffic_limit.exe
[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\build\native\TrafficLimitService.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\native\WinDivert.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\native\WinDivert64.sys"; DestDir: "{app}"; Flags: ignoreversion
[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; Flags: unchecked
Name: "autostart"; Description: "Запускать вместе с Windows"; Flags: unchecked
[Run]
Filename: "{app}\TrafficLimitService.exe"; Parameters: "--install"; Flags: runhidden waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "Запустить Traffic Limit"; Flags: nowait postinstall skipifsilent
[UninstallRun]
Filename: "{app}\TrafficLimitService.exe"; Parameters: "--uninstall"; Flags: runhidden waituntilterminated
[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "TrafficLimit"; ValueData: "{app}\{#AppExeName}"; Flags: uninsdeletevalue; Tasks: autostart
