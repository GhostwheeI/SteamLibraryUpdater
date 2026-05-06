# Changelog

All notable changes to Steam Update Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.0.1] - 2026-05-06

### Fixed

- Quoted the legacy SteamCMD `force_install_dir` argument explicitly so Windows PowerShell 5.1 cannot split `C:\Program Files\...` into a stray `C:\program` update folder.

## [2.0.0] - 2026-05-06

### Added

- Added `Steam-Update-Manager.ps1`, a PowerShell WinForms tray host with a right-click menu.
- Added tray menu header with app name/version and a dynamic `Status:` line.
- Added tray actions for Run with Steam, manual queued update starts, update-condition configuration, Settings, About, and Exit.
- Added Settings dialog for Start with Windows, Show Taskbar Icon, diagnostic logging, log-folder access, and theme selection.
- Added Windows app-theme detection so `Auto` resolves to the current system Light or Dark app theme.
- Added custom app icon support for the tray, desktop shortcut, Start menu shortcut, and Apps & Features entry.
- Added automatic installed-game monitoring as the default behavior.
- Moved logs access into Settings.
- Added a Configure tray option for update conditions.
- Added a Settings checkbox for `Show Taskbar Icon`, unchecked by default.
- Added ProgramData-backed config, appinfo cache, and logs under `C:\ProgramData\Steam-Update-Manager`.
- Added size-controlled diagnostic logging with configurable `MaxLogFileKB` and `MaxLogFiles`.
- Added advanced configuration values for update metadata provider, automatic installed-game monitoring, task polling interval, and SteamCMD path.

### Changed

- Renamed the installed product identity to Steam Update Manager.
- Changed install location to `C:\Program Files\Steam-Update-Manager`.
- Updated the installer to register Steam Update Manager in Apps & Features, install the tray host, create ProgramData runtime folders, download SteamCMD by default, and launch the tray app after install.
- Updated the uninstaller to remove the scheduled task, startup entry, Apps & Features registration, installed scripts, and optionally ProgramData state.
- Updated the CLI configuration script to resolve the new install path while keeping legacy path compatibility.
- Simplified tray menu wording around Steam startup, queued update starts, and gaming pauses.
- Moved `Allow updates while gaming` into Configure and left it unchecked by default.
- Renamed the manual update and configure tray actions for shorter, clearer menu labels.
- Moved shortcut and app registration icons to `AppIconTransparent.ico` to avoid cached white-background icon rendering.
- Replaced the top-level `Run with Steam` checkmark with an `On`/`Off` submenu to remove the menu-wide check-margin bar.
- Changed Start with Windows to default on and Show Taskbar Icon to hide the tray icon by default.
- Replaced SteamCMD-based background updates with Steam client queue nudging through appmanifest scheduling metadata.
- Reduced scheduled queue checks to a one-minute cadence.

### Compatibility

- Existing module function names remain available for scripts and advanced CLI use.

## [1.1.0] - 2025-12-18

### Added

- Auto-detect and auto-add installed games during installation
- Installer now includes the interactive configuration tool in the install directory

### Changed

- Scheduled task runs every 5 minutes and defers to CheckIntervalMinutes to avoid excessive checks

## [1.0.0] - 2025-11-04

### Added - Major Overhaul

This release represents a complete transformation from a simple batch script to a full-featured PowerShell application.

#### Core Functionality
- **PowerShell Module** (`SteamLibraryUpdater.psm1`)
  - Comprehensive game update management system
  - Configurable settings stored in JSON format
  - Gaming-aware update logic (pause updates during gaming by default)
  - Steam process detection
  - Game process detection
  - Logging system with daily log rotation
  - Steam API integration for update checking
  - SteamCMD integration for game updates

#### Installation & Distribution
- **Automated Installer** (`Install-SteamLibraryUpdater.ps1`)
  - One-click installation to Program Files
  - Windows Task Scheduler integration (runs hourly when Steam is running)
  - Add/Remove Programs registration
  - Interactive configuration during setup
  - SteamCMD detection and installation guidance
  
- **Clean Uninstaller** (`Uninstall-SteamLibraryUpdater.ps1`)
  - Complete removal of all components
  - Option to preserve logs and configuration
  - Registry cleanup
  - Scheduled task removal

#### User Interface
- **Configuration Tool** (`Configure-SteamLibraryUpdater.ps1`)
  - Interactive menu-driven interface
  - Add/remove games from monitoring
  - Toggle settings (update during gaming, auto-update)
  - View configuration and logs
  - Manual update testing

#### Documentation
- **Comprehensive README** with full feature documentation
- **Quick Start Guide** for rapid deployment
- **Examples Document** with 23+ practical usage scenarios
- **Changelog** for version tracking

#### Configuration System
- JSON-based configuration file
- User preferences:
  - Update during gaming (default: false)
  - Check interval in minutes (default: 60)
  - Enable/disable auto-updates (default: true)
  - Monitored games list with metadata
  - Last check timestamp

#### Automation
- Windows Task Scheduler integration
- Runs automatically when Steam is running
- Hourly update checks (configurable)
- Background operation (no user interaction required)

#### Game Management
- Add games to monitoring with App ID, name, install directory, and process name
- Remove games from monitoring
- Support for multiple Steam library locations
- Per-game metadata tracking

#### Logging
- Daily log files with timestamps
- Log levels (Info, Warning, Error)
- Automatic log rotation
- Detailed operation logging for troubleshooting

### Changed

- **Complete rewrite** from batch script to PowerShell
- **Architecture change** from single-shot script to persistent service-like operation
- **User experience** improved with automated installation and configuration

### Deprecated

- **Batch Script** (`update_game_steam.bat`)
  - No longer maintained
  - Replaced by PowerShell module
  - Kept in repository for reference only

### Migration from Batch Script

If you were using the old batch script:

1. **Install the new version** using `Install-SteamLibraryUpdater.ps1`
2. **Add your games** using the configuration tool or `Add-MonitoredGame` function
3. **Configure preferences** for update timing and behavior
4. **Remove old batch script references** from your automation

The new version provides all the functionality of the old script plus:
- Automatic scheduling
- Gaming awareness
- Configuration management
- Better logging
- Easier deployment

## [0.1.0] - Previous

### Original Batch Script Features

- Manual execution required
- Command-line parameters for App ID and install directory
- Steam API update checking via curl
- SteamCMD integration for updates
- File comparison for change detection
- Return codes for automation (0 = up-to-date, 1 = updated)

---

## Upgrade Path

### From Batch Script to v1.0.0

**Before:**
```batch
update_game_steam.bat 730 "C:\Steam\steamapps\common\Counter-Strike Global Offensive"
```

**After:**
```powershell
# One-time setup
Install-SteamLibraryUpdater.ps1
Add-MonitoredGame -AppId "730" -Name "Counter-Strike 2" -InstallDir "C:\Steam\steamapps\common\Counter-Strike Global Offensive" -ProcessName "cs2"

# No manual execution needed - runs automatically!
```

## Future Roadmap

Potential features for future releases:

- [ ] GUI configuration application
- [ ] Update notifications (system tray)
- [ ] Bandwidth throttling options
- [ ] Multiple Steam library auto-detection
- [ ] Update scheduling by time of day
- [ ] Update size estimation before downloading
- [ ] Pause/resume functionality
- [ ] Email/webhook notifications
- [ ] Statistics and reporting dashboard
- [ ] Custom update rules per game
- [ ] Integration with Steam Web API for better game detection

## Contributing

See [README.md](README.md#contributing) for information on contributing to this project.

## Support

For issues, questions, or feature requests, please open an issue on GitHub.
