# Steam Library Updater

An automated solution to keep your Steam library up-to-date without manual intervention.

## Overview

Steam Library Updater is a PowerShell-based automation tool that monitors your Steam games and automatically keeps them updated when Steam is running. It runs silently in the background, checking for updates at regular intervals and only updating when it won't impact your gaming experience.

## Purpose

Many Steam users have large game libraries and want their games to stay updated without:
- Manually checking each game for updates
- Having updates run while they're gaming (impacting performance)
- Dealing with large downloads when they want to play
- Managing update schedules manually

Steam Library Updater solves these problems by providing a fully automated, configurable solution that respects your gaming time while keeping your library current.

## Key Features

- **🎮 Gaming-Aware**: By default, updates are paused when you're playing games to avoid impacting your connection or performance
- **🔄 Fully Automated**: Runs automatically when Steam is running - no manual intervention needed
- **🤖 Smart Auto-Detection**: Automatically finds your Steam installation and installed games
- **📥 One-Click Setup**: Automatically downloads and installs SteamCMD during installation
- **🎯 Easy Game Management**: Add games via auto-detection, search by name, or add all at once
- **⚙️ Configurable**: Choose whether to allow updates during gaming, set check intervals, and select which games to monitor
- **📦 Easy Installation**: Single-script installation that sets up everything including Add/Remove Programs entry
- **🔔 Scheduled Updates**: Uses Windows Task Scheduler to run checks at regular intervals
- **📊 Logging**: Keeps detailed logs of all update activities for troubleshooting
- **🗑️ Clean Uninstall**: Full uninstaller that removes all traces from your system

## Requirements

- Windows 10 or later
- PowerShell 5.1 or later
- Administrator privileges (for installation)
- Steam installed on your system
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) (automatically downloaded during installation)

## What's Automated

Steam Library Updater now automates almost everything that previously required manual work:

✅ **SteamCMD Installation**: Automatically downloads and installs SteamCMD during setup  
✅ **Steam Path Detection**: Automatically finds your Steam installation  
✅ **Library Detection**: Discovers all your Steam library folders  
✅ **Game Discovery**: Scans and lists all installed Steam games  
✅ **App ID Lookup**: Search for games by name to find their App ID  
✅ **Bulk Operations**: Add all installed games with a single command  

No more manual copying of files, searching for App IDs, or typing long install paths!

## Installation

### Quick Install

1. **Download the repository**
   ```powershell
   # Clone or download the repository
   git clone https://github.com/GhostwheeI/SteamLibraryUpdater.git
   cd SteamLibraryUpdater
   ```

2. **Run the installer as Administrator**
   ```powershell
   # Right-click PowerShell and select "Run as Administrator"
   .\Install-SteamLibraryUpdater.ps1
   ```

3. **Follow the installation prompts**
   - Choose whether to allow updates during gaming (default: No)
   - Choose whether to automatically download SteamCMD (recommended: Yes)
   - Installed games are auto-detected and added to monitoring
   - The installer will set up everything automatically

### What Gets Installed

- **Program Files**: `C:\Program Files\SteamLibraryUpdater\`
  - PowerShell module with all update logic
  - Configuration file
  - Uninstaller script
  - Logs directory
  
- **Windows Task Scheduler**: Scheduled task that runs every 5 minutes and respects your configured check interval

- **Add/Remove Programs**: Entry for easy uninstallation

## Configuration

### Automated Setup (Recommended)

The easiest way to configure Steam Library Updater is using the interactive configuration tool:

```powershell
# Run the configuration tool
C:\Program Files\SteamLibraryUpdater\Configure-SteamLibraryUpdater.ps1
```

The installer already auto-detects and adds installed games. Use the configuration tool to review or adjust the list.

The configuration tool provides several automated options:
- **Auto-detect installed games**: Automatically scans your Steam library and lets you select games to monitor
- **Quick add all games**: Add all installed Steam games to monitoring with one click
- **Search by name**: Find games by searching the Steam store
- **Manual entry**: Enter game details manually if needed

### Manual Setup

You can also configure games manually if preferred:

```powershell
# Open PowerShell as Administrator
cd "C:\Program Files\SteamLibraryUpdater"
Import-Module .\SteamLibraryUpdater.psm1

# Add a game to monitor manually
Add-MonitoredGame -AppId "730" -Name "Counter-Strike 2" -InstallDir "C:\Steam\steamapps\common\Counter-Strike Global Offensive" -ProcessName "cs2"

# View current configuration
Get-SteamLibraryUpdaterConfig
```

### Configuration Options

Edit `C:\Program Files\SteamLibraryUpdater\Config.json`:

```json
{
  "UpdateDuringGaming": false,
  "CheckIntervalMinutes": 60,
  "EnableAutoUpdate": true,
  "SteamInstallPath": "",
  "MonitoredGames": [],
  "LastCheck": null
}
```

- **UpdateDuringGaming**: Set to `true` to allow updates while gaming (default: `false`)
- **CheckIntervalMinutes**: How often to check for updates (default: 60 minutes)
- **EnableAutoUpdate**: Enable/disable automatic updates (default: `true`)
- **MonitoredGames**: List of games to monitor for updates

### Adding Games

The configuration tool makes adding games easy with several automated methods:

**Option 1: Auto-detect (Easiest)**
- Run `Configure-SteamLibraryUpdater.ps1`
- Select option 4 to add a game
- Choose option 1 to auto-detect from installed games
- Select from the list of detected games

**Option 2: Quick Add All**
- Run `Configure-SteamLibraryUpdater.ps1`
- Select option 6 to add all installed games at once

**Option 3: Search by Name**
- Run `Configure-SteamLibraryUpdater.ps1`
- Select option 4 to add a game
- Choose option 3 to search by name
- Enter the game name to search

**Option 4: Manual Entry**
If you prefer manual control, you can still add games using PowerShell:

```powershell
Add-MonitoredGame -AppId "440" -Name "Team Fortress 2" -InstallDir "C:\Steam\steamapps\common\Team Fortress 2" -ProcessName "hl2"
```

Find Steam App IDs from [SteamDB](https://steamdb.info/) or the Steam store URL if needed.

### Removing Games

```powershell
Remove-MonitoredGame -AppId "440"
```

## Usage

Once installed, Steam Library Updater runs automatically in the background:

1. **When Steam starts**, the scheduled task begins checking for updates
2. **Every 5 minutes**, it checks whether an update pass is due based on your interval
3. **If a game needs updating** and conditions are met (not gaming, etc.), it updates automatically
4. **All activity is logged** to `C:\Program Files\SteamLibraryUpdater\Logs\`

### Manual Update Check

You can manually trigger an update check:

```powershell
cd "C:\Program Files\SteamLibraryUpdater"
Import-Module .\SteamLibraryUpdater.psm1
Start-SteamLibraryUpdate -Verbose
```

## Uninstallation

### Via Add/Remove Programs

1. Open Windows Settings → Apps → Apps & features
2. Search for "Steam Library Updater"
3. Click Uninstall

### Via PowerShell

```powershell
# Run as Administrator
C:\Program Files\SteamLibraryUpdater\Uninstall-SteamLibraryUpdater.ps1
```

The uninstaller will:
- Remove the scheduled task
- Remove the Add/Remove Programs entry
- Ask if you want to keep logs and configuration
- Remove all installation files

## Troubleshooting

### Check Logs

Logs are stored in: `C:\Program Files\SteamLibraryUpdater\Logs\`

Each day creates a new log file: `SteamLibraryUpdater_YYYYMMDD.log`

### Common Issues

**Updates not running:**
- Check that Steam is running
- Verify the scheduled task exists: `Get-ScheduledTask -TaskName "SteamLibraryUpdater"`
- Check logs for errors

**SteamCMD errors:**
- Ensure SteamCMD is installed in the correct directory
- Run SteamCMD manually once to accept the Steam Subscriber Agreement

**Game not updating:**
- Verify the App ID is correct
- Check that the install directory path is correct
- Ensure you have sufficient disk space

### Manual Testing

Test the module functions:

```powershell
Import-Module "C:\Program Files\SteamLibraryUpdater\SteamLibraryUpdater.psm1" -Force

# Check if Steam is running
Test-SteamRunning

# Check if any games are running
Test-GameRunning

# Check a specific game for updates
Test-GameNeedsUpdate -AppId "730"
```

## Goals

- ✅ Convert from batch script to PowerShell
- ✅ Create installer for easy deployment
- ✅ Add to Add/Remove Programs
- ✅ Run automatically when Steam is running
- ✅ Configurable gaming-aware updates
- ✅ Background operation with logging
- ✅ Clean uninstallation

## Future Enhancements

- [ ] GUI configuration tool
- [ ] Update notifications
- [ ] Bandwidth throttling options
- [ ] Multiple Steam library support
- [ ] Update scheduling by time of day

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is provided as-is for use by the Steam community.

## Credits

Created by GhostwheeI

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check the logs for detailed error information
- Review the troubleshooting section

---

**Note**: This tool uses SteamCMD and respects Steam's terms of service. Always ensure you have the legal right to update the games in your library.
