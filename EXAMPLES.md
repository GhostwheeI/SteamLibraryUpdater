# Usage Examples

This document provides practical examples of using Steam Update Manager.

## Table of Contents

- [Basic Installation and Setup](#basic-installation-and-setup)
- [Automated Game Detection](#automated-game-detection)
- [Adding Games to Monitor](#adding-games-to-monitor)
- [Configuration Examples](#configuration-examples)
- [Manual Operations](#manual-operations)
- [Troubleshooting Scenarios](#troubleshooting-scenarios)

## Basic Installation and Setup

### Example 1: Standard Installation

```powershell
# 1. Open PowerShell as Administrator
# 2. Navigate to the downloaded repository
cd C:\Users\YourName\Downloads\SteamLibraryUpdater

# 3. Run the installer
.\Install-SteamLibraryUpdater.ps1

# 4. Follow prompts:
# - "Do you want to allow updates while gaming? (y/N)" → Press N (default)

# 5. Download SteamCMD
# Visit: https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip
# Extract steamcmd.exe to: C:\Program Files\Steam-Update-Manager\steamcmd\
```

### Example 2: Installation with Automatic SteamCMD Download

```powershell
# Run installer
.\Install-SteamLibraryUpdater.ps1

# When prompted "Would you like to download and install SteamCMD automatically?"
# Press: Enter (or type 'y' for Yes)

# The installer will automatically:
# 1. Download SteamCMD
# 2. Extract it to the correct location
# 3. Initialize it for first use
```

## Automated Game Detection

### Example 3: Auto-Detect Installed Steam Games

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Automatically find your Steam installation
$steamPath = Find-SteamInstallPath
Write-Host "Steam found at: $steamPath"

# Get all installed games
$games = Get-InstalledSteamGames
Write-Host "Found $($games.Count) installed games"

# Display the games
$games | Select-Object Name, AppId, InstallDir | Format-Table
```

### Example 4: Quick Add All Games

```powershell
# Using the interactive configuration tool
C:\Program Files\Steam-Update-Manager\Configure-SteamLibraryUpdater.ps1

# Press 6 for "Quick Add All Installed Games"
# Confirm when prompted
# All your installed Steam games will be automatically added to monitoring
```

### Example 5: Search for a Game by Name

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Search for a game
$result = Find-AppIdByName -GameName "Portal"

if ($result) {
    Write-Host "Found: $($result.Name)"
    Write-Host "App ID: $($result.AppId)"
    Write-Host "Type: $($result.Type)"
}
```

### Example 6: Get Steam Library Folders

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Find Steam installation
$steamPath = Find-SteamInstallPath

# Get all library folders (including additional drives)
$libraries = Get-SteamLibraryFolders -SteamPath $steamPath

Write-Host "Steam Library Folders:"
$libraries | ForEach-Object {
    Write-Host "  $_"
}
```

## Adding Games to Monitor

### Example 7: Using the Interactive Configuration Tool

```powershell
# Run the configuration tool
C:\Program Files\Steam-Update-Manager\Configure-SteamLibraryUpdater.ps1

# Press 4 to "Add Game to Monitor"
# Then select:
#   Option 1: Auto-detect from installed games (shows a list to choose from)
#   Option 2: Enter manually (traditional method)
#   Option 3: Search by name (finds the game via Steam API)
```

### Example 8: Add Counter-Strike 2 (Auto-Detected)

```powershell
# Using auto-detection - the easy way!
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Get all installed games
$games = Get-InstalledSteamGames

# Find CS2
$cs2 = $games | Where-Object { $_.Name -like "*Counter-Strike*" }

# Add it with one command (all info is auto-populated)
if ($cs2) {
    Add-MonitoredGame -AppId $cs2.AppId -Name $cs2.Name -InstallDir $cs2.InstallDir -ProcessName $cs2.ProcessName
}
```

### Example 9: Add Multiple Games

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Add Dota 2
Add-MonitoredGame -AppId "570" -Name "Dota 2" -InstallDir "C:\Steam\steamapps\common\dota 2 beta" -ProcessName "dota2"

# Add Team Fortress 2
Add-MonitoredGame -AppId "440" -Name "Team Fortress 2" -InstallDir "C:\Steam\steamapps\common\Team Fortress 2" -ProcessName "hl2"

# Add Left 4 Dead 2
Add-MonitoredGame -AppId "550" -Name "Left 4 Dead 2" -InstallDir "C:\Steam\steamapps\common\Left 4 Dead 2" -ProcessName "left4dead2"

# Add Portal 2
Add-MonitoredGame -AppId "620" -Name "Portal 2" -InstallDir "C:\Steam\steamapps\common\Portal 2" -ProcessName "portal2"
```

### Example 10: Finding Your Game Install Directory

```powershell
# Method 1: Use Auto-Detection (Easiest!)
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"
$games = Get-InstalledSteamGames
$games | Select-Object Name, InstallDir | Format-Table -AutoSize

# Method 2: Use Steam Library Folders Discovery
$steamPath = Find-SteamInstallPath
$libraries = Get-SteamLibraryFolders -SteamPath $steamPath
foreach ($lib in $libraries) {
    Write-Host "Library: $lib" -ForegroundColor Green
    $commonPath = Join-Path $lib "common"
    if (Test-Path $commonPath) {
        Get-ChildItem $commonPath -Directory | Select-Object Name, FullName
    }
}

# Method 3: Manual Search (Old Way)
# 1. Open Steam
# 2. Right-click the game → Properties → Local Files → Browse
# 3. Copy the path from File Explorer
```

## Configuration Examples

### Example 11: Enable Updates During Gaming

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Get current config
$config = Get-SteamLibraryUpdaterConfig

# Enable updates during gaming
$config.UpdateDuringGaming = $true

# Save the config
Set-SteamLibraryUpdaterConfig -Config $config

Write-Host "Updates will now run even while gaming" -ForegroundColor Green
```

### Example 12: Change Check Interval to 30 Minutes

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

$config = Get-SteamLibraryUpdaterConfig
$config.CheckIntervalMinutes = 30
Set-SteamLibraryUpdaterConfig -Config $config

Write-Host "Update checks will now run every 30 minutes" -ForegroundColor Green
```

### Example 13: Temporarily Disable Auto-Updates

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

$config = Get-SteamLibraryUpdaterConfig
$config.EnableAutoUpdate = $false
Set-SteamLibraryUpdaterConfig -Config $config

Write-Host "Auto-updates disabled" -ForegroundColor Yellow
Write-Host "Re-enable by setting EnableAutoUpdate to $true" -ForegroundColor Cyan
```

### Example 14: Use the Interactive Configuration Tool

```powershell
# Open PowerShell as Administrator
C:\Program Files\Steam-Update-Manager\Configure-SteamLibraryUpdater.ps1

# Then use the menu:
# - Press 1 to toggle "Update During Gaming"
# - Press 2 to change check interval
# - Press 3 to toggle auto-update
# - Press 4 to add a game
# - Press 5 to remove a game
# - Press Q to quit
```

## Manual Operations

### Example 15: Manual Update Check

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Run a manual update check (with verbose output)
Start-SteamLibraryUpdate -Verbose

# This checks all monitored games and updates them if needed
```

### Example 16: Check If Steam Is Running

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

if (Test-SteamRunning) {
    Write-Host "Steam is currently running" -ForegroundColor Green
} else {
    Write-Host "Steam is not running" -ForegroundColor Yellow
}
```

### Example 17: Check If Any Game Is Running

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

if (Test-GameRunning) {
    Write-Host "A game is currently running" -ForegroundColor Green
} else {
    Write-Host "No games are running" -ForegroundColor Yellow
}
```

### Example 18: Check Single Game for Updates

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Check if CS2 needs an update
$needsUpdate = Test-GameNeedsUpdate -AppId "730"

if ($needsUpdate) {
    Write-Host "Counter-Strike 2 needs an update" -ForegroundColor Yellow
} else {
    Write-Host "Counter-Strike 2 is up to date" -ForegroundColor Green
}
```

### Example 19: Manually Update a Specific Game

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Manually update Counter-Strike 2
$success = Update-SteamGame -AppId "730" -InstallDir "C:\Steam\steamapps\common\Counter-Strike Global Offensive"

if ($success) {
    Write-Host "Update completed successfully" -ForegroundColor Green
} else {
    Write-Host "Update failed" -ForegroundColor Red
}
```

## Troubleshooting Scenarios

### Example 20: View Recent Logs

```powershell
# View today's log
$logFile = "C:\Program Files\Steam-Update-Manager\Logs\SteamLibraryUpdater_$(Get-Date -Format 'yyyyMMdd').log"

if (Test-Path $logFile) {
    # Show last 20 lines
    Get-Content $logFile -Tail 20
} else {
    Write-Host "No log file found for today" -ForegroundColor Yellow
}
```

### Example 21: View All Monitored Games

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

$config = Get-SteamLibraryUpdaterConfig

Write-Host "Monitored Games:" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan

foreach ($game in $config.MonitoredGames) {
    Write-Host ""
    Write-Host "Name: $($game.Name)" -ForegroundColor White
    Write-Host "App ID: $($game.AppId)" -ForegroundColor Gray
    Write-Host "Install Dir: $($game.InstallDir)" -ForegroundColor Gray
    Write-Host "Process Name: $($game.ProcessName)" -ForegroundColor Gray
    Write-Host "Added: $($game.Added)" -ForegroundColor Gray
}
```

### Example 22: Remove a Game from Monitoring

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Remove Counter-Strike 2 (App ID 730)
Remove-MonitoredGame -AppId "730"

Write-Host "Game removed from monitoring" -ForegroundColor Green
```

### Example 23: Verify Scheduled Task

```powershell
# Check if the scheduled task exists
$task = Get-ScheduledTask -TaskName "SteamUpdateManager" -ErrorAction SilentlyContinue

if ($task) {
    Write-Host "Scheduled task found" -ForegroundColor Green
    Write-Host "State: $($task.State)" -ForegroundColor Cyan
    
    # Get task info
    $taskInfo = Get-ScheduledTaskInfo -TaskName "SteamUpdateManager"
    Write-Host "Last Run Time: $($taskInfo.LastRunTime)" -ForegroundColor Cyan
    Write-Host "Next Run Time: $($taskInfo.NextRunTime)" -ForegroundColor Cyan
} else {
    Write-Host "Scheduled task NOT found" -ForegroundColor Red
    Write-Host "Try reinstalling the application" -ForegroundColor Yellow
}
```

### Example 24: Reset Configuration to Defaults

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

# Create default configuration
$defaultConfig = [PSCustomObject]@{
    UpdateDuringGaming = $false
    CheckIntervalMinutes = 60
    EnableAutoUpdate = $true
    SteamInstallPath = ""
    MonitoredGames = @()
    LastCheck = $null
}

# Save it
Set-SteamLibraryUpdaterConfig -Config $defaultConfig

Write-Host "Configuration reset to defaults" -ForegroundColor Green
Write-Host "You will need to re-add your games" -ForegroundColor Yellow
```

### Example 25: Check SteamCMD Installation

```powershell
$steamCmdPath = "C:\Program Files\Steam-Update-Manager\steamcmd\steamcmd.exe"

if (Test-Path $steamCmdPath) {
    Write-Host "SteamCMD is installed" -ForegroundColor Green
    
    # Get file info
    $fileInfo = Get-Item $steamCmdPath
    Write-Host "Path: $($fileInfo.FullName)" -ForegroundColor Cyan
    Write-Host "Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host "Last Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
} else {
    Write-Host "SteamCMD is NOT installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Download from: https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -ForegroundColor Cyan
    Write-Host "Extract to: $steamCmdPath" -ForegroundColor Cyan
}
```

## Advanced Examples

### Example 26: Batch Add Games from CSV

```powershell
# Create a CSV file (games.csv) with columns: AppId,Name,InstallDir,ProcessName
# Example content:
# AppId,Name,InstallDir,ProcessName
# 730,"Counter-Strike 2","C:\Steam\steamapps\common\Counter-Strike Global Offensive",cs2
# 570,"Dota 2","C:\Steam\steamapps\common\dota 2 beta",dota2

Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

$games = Import-Csv -Path "games.csv"

foreach ($game in $games) {
    Write-Host "Adding $($game.Name)..." -ForegroundColor Yellow
    
    Add-MonitoredGame `
        -AppId $game.AppId `
        -Name $game.Name `
        -InstallDir $game.InstallDir `
        -ProcessName $game.ProcessName
}

Write-Host "All games added!" -ForegroundColor Green
```

### Example 27: Export Configuration for Backup

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

$config = Get-SteamLibraryUpdaterConfig
$backupPath = "C:\Users\$env:USERNAME\Desktop\SteamUpdateManager_Backup_$(Get-Date -Format 'yyyyMMdd').json"

$config | ConvertTo-Json -Depth 10 | Set-Content $backupPath

Write-Host "Configuration backed up to: $backupPath" -ForegroundColor Green
```

### Example 28: Restore Configuration from Backup

```powershell
Import-Module "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"

$backupPath = "C:\Users\$env:USERNAME\Desktop\SteamUpdateManager_Backup_20250101.json"

if (Test-Path $backupPath) {
    $config = Get-Content $backupPath -Raw | ConvertFrom-Json
    Set-SteamLibraryUpdaterConfig -Config $config
    Write-Host "Configuration restored from backup" -ForegroundColor Green
} else {
    Write-Host "Backup file not found: $backupPath" -ForegroundColor Red
}
```

---

## Need More Help?

- Check the [README](README.md) for detailed documentation
- See the [Quick Start Guide](QUICKSTART.md) for installation
- Review logs in `C:\Program Files\Steam-Update-Manager\Logs\`
- Open an issue on GitHub for additional support
