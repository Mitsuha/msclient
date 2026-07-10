; Inno Setup 脚本：把 Windows 构建产物打成安装程序 (.exe)
; 编译: iscc /DMyAppVersion=1.0.0 /DSourceDir=<Release目录绝对路径> /O<输出目录> installer.iss
;
; SourceDir 默认指向 shorebird/flutter 的 Release 产物目录。

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

#define MyAppName "Mirrorstages"
#define MyAppPublisher "MirrorStages"
#define MyAppExeName "desktop.exe"

[Setup]
; AppId 固定不变，用于升级识别；不要随意更改。
AppId={{B3D9E2A1-7C4F-4E6A-9F2D-1A8C5E0B6D34}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Mirrorstages
DefaultGroupName=Mirrorstages
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputBaseFilename=MirrorStages-Desktop-{#MyAppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\assets\tray\app_icon.ico
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Mirrorstages"; Flags: nowait postinstall skipifsilent
