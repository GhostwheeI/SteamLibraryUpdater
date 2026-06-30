# Steam Update Manager

[![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://microsoft.com/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

PowerShell-based Steam library update management with a Windows taskbar tray menu, scheduled background checks, Apps & Features registration, and a clean uninstall path.

## Table of Contents
- [Quick Install & Uninstall](#quick-install--uninstall)
- [Current Shape](#current-shape)
- [Requirements](#requirements)
- [Install](#install)
- [Tray Menu](#tray-menu)
- [Configure](#configure)
- [Settings](#settings)
- [Advanced Configuration](#advanced-configuration)
- [CLI Compatibility](#cli-compatibility)
- [Logging](#logging)
- [Uninstall](#uninstall)
- [Notes](#notes)


## Quick Install & Uninstall

**Install:**
Run PowerShell as Administrator:
```powershell
.\Install-SteamLibraryUpdater.ps1
```

**Uninstall:**
Use Windows Settings > Apps > Installed apps, or run PowerShell as Administrator:
```powershell
C:\Program Files\Steam-Update-Manager\Uninstall-SteamLibraryUpdater.ps1
```

## Current Shape

Steam Update Manager keeps the original CLI/update engine available, then adds a tray host for the most common controls.

- Right-click taskbar menu with app name/version at the top
- Dynamic `Status:` line for paused, waiting, gaming-paused, and ready states
- Manual queued-update start from the tray menu
- Run with Steam toggle from the tray menu
- Configure dialog for update conditions
- Automatic installed-game monitoring
- Settings dialog for Start with Windows, Show Taskbar Icon, diagnostic logging, and theme selection
- Logs folder access from Settings
- About dialog with version and runtime paths
- App icon for the tray, Start menu, desktop shortcut, and Apps & Features entry
- Scheduled task for background update checks when Steam is running
- Apps & Features registration for uninstall
- ProgramData-backed config/log/cache storage
- Size-controlled diagnostic logs

## Requirements

- Windows 10 or later
- Windows PowerShell 5.1 or later
- Administrator privileges for installation/uninstallation
- Steam installed locally
- SteamCMD is installed for legacy CLI compatibility; the GUI uses Steam client queue scheduling for normal queued client updates.

The installer downloads SteamCMD from Valve's official SteamCMD package URL unless `-SkipSteamCmdDownload` is used.

## Install

Run PowerShell as Administrator:

```powershell
.\Install-SteamLibraryUpdater.ps1
```

Installed application files:

```text
C:\Program Files\Steam-Update-Manager
```

Writable runtime data:

```text
C:\ProgramData\Steam-Update-Manager
```

The installer:

- Copies the PowerShell module, tray host, configuration tool, and uninstaller
- Creates the ProgramData config/log/cache folders
- Grants normal users Modify access to the ProgramData folder
- Detects Steam and installed games when possible
- Installs SteamCMD by default
- Creates the `SteamUpdateManager` scheduled task
- Creates Start menu and desktop shortcuts that show the tray icon and open the menu
- Registers the app in Apps & Features
- Launches the tray menu unless `-DoNotLaunchTray` is used

## Tray Menu

Right-click the taskbar icon to access:

- App header with version
- `Status:` line
- `Run with Steam` with `On` and `Off` submenu choices
- `Manually Start All Queued Updates`
- `Configure Update Conditions`
- `Settings`
- `About`
- `Exit`

Double-clicking the tray icon also starts a manual update check.

## Configure

The Configure dialog controls update conditions:

- `When available` is checked by default.
- `Allow updates while gaming` is unchecked by default.

## Settings

The tray settings dialog currently manages:

- Start with Windows
- Show Taskbar Icon
- Diagnostic logging
- Theme: `Auto`, `Light`, or `Dark`

When Theme is `Auto`, Steam Update Manager reads the current Windows app theme and resolves to Light or Dark automatically. The tray menu checks this each time it opens.

## Advanced Configuration

Advanced settings live in:

```text
C:\ProgramData\Steam-Update-Manager\Config.json
```

Default configuration:

```json
{
  "AppName": "Steam Update Manager",
  "AppVersion": "2.1.0",
  "Theme": "Auto",
  "StartWithWindows": true,
  "ShowTaskbarIcon": false,
  "DiagnosticLogging": true,
  "MaxLogFileKB": 512,
  "MaxLogFiles": 8,
  "UpdateDuringGaming": false,
  "UpdateCondition": "WhenAvailable",
  "CheckIntervalMinutes": 1,
  "EnableAutoUpdate": true,
  "SteamInstallPath": "",
  "MonitoredGames": [],
  "LastCheck": null,
  "Advanced": {
    "UpdateCheckProvider": "https://api.steamcmd.net/v1/info",
    "ScheduledTaskPollMinutes": 1,
    "SteamCmdInstallPath": ""
  }
}
```

Settings not exposed in the tray UI are intentionally treated as advanced config.

## CLI Compatibility

The existing PowerShell module functions remain available:

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1" -Force

Get-SteamLibraryUpdaterConfig
Set-SteamLibraryUpdaterConfig -Config $config
Find-SteamInstallPath
Get-SteamLibraryFolders
Get-InstalledSteamGames
Find-AppIdByName -GameName "Counter-Strike 2"
Add-MonitoredGame -AppId "730" -Name "Counter-Strike 2" -InstallDir "C:\Steam\steamapps\common\Counter-Strike Global Offensive" -ProcessName "cs2"
Remove-MonitoredGame -AppId "730"
Start-SteamLibraryUpdate
Start-SteamQueuedUpdates
```

The old `Configure-SteamLibraryUpdater.ps1` menu remains for advanced/manual game management.

## Logging

Logs are written to:

```text
C:\ProgramData\Steam-Update-Manager\Logs
```

Diagnostic logging can be disabled from Settings. Errors still write to the log. Log retention is controlled by:

- `MaxLogFileKB`
- `MaxLogFiles`

## Uninstall

Use Windows Settings > Apps > Installed apps, or run PowerShell as Administrator:

```powershell
C:\Program Files\Steam-Update-Manager\Uninstall-SteamLibraryUpdater.ps1
```

The uninstaller removes:

- Scheduled task
- Start with Windows entry
- Apps & Features registry entry
- Installed scripts
- ProgramData config/log/cache folder unless you choose to keep it

## Notes

Steam Update Manager's tray workflow nudges Steam's own queued update schedule and opens the Steam Downloads view. The legacy CLI update path still uses SteamCMD and public Steam metadata endpoints. Make sure you have the legal right to update the games being managed.
