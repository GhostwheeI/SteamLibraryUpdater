# Quick Start Guide

Get Steam Library Updater up and running in 5 minutes!

## Step 1: Install

1. **Download** this repository
2. **Right-click** on `Install-SteamLibraryUpdater.ps1`
3. **Select** "Run with PowerShell" (as Administrator)
4. **Follow** the installation prompts

## Step 2: Get SteamCMD

Download SteamCMD (required for updates):

1. Go to: https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip
2. Extract the ZIP file
3. Copy `steamcmd.exe` to: `C:\Program Files\SteamLibraryUpdater\steamcmd\`

## Step 3: Configure

Run the configuration tool:

```powershell
# Open PowerShell as Administrator
C:\Program Files\SteamLibraryUpdater\Configure-SteamLibraryUpdater.ps1
```

Or manually add games:

```powershell
# Open PowerShell as Administrator
cd "C:\Program Files\SteamLibraryUpdater"
Import-Module .\SteamLibraryUpdater.psm1

# Example: Add Counter-Strike 2
Add-MonitoredGame -AppId "730" -Name "Counter-Strike 2" -InstallDir "C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive" -ProcessName "cs2"
```

## Step 4: Done!

That's it! Steam Library Updater will now:
- ✅ Run automatically when Steam is running
- ✅ Check for updates every hour
- ✅ Update games when you're not playing (by default)
- ✅ Log all activities

## Finding Steam App IDs

You need the App ID for each game you want to monitor:

1. Go to https://steamdb.info/
2. Search for your game
3. The App ID is shown on the game's page

**OR**

1. Go to the game's Steam store page
2. Look at the URL: `https://store.steampowered.com/app/730/` ← 730 is the App ID

## Common App IDs

| Game | App ID |
|------|--------|
| Counter-Strike 2 | 730 |
| Dota 2 | 570 |
| Team Fortress 2 | 440 |
| Left 4 Dead 2 | 550 |
| Portal 2 | 620 |
| Garry's Mod | 4000 |
| Rust | 252490 |
| ARK: Survival Evolved | 346110 |

## Checking Installation

Verify everything is working:

```powershell
# Open PowerShell as Administrator
cd "C:\Program Files\SteamLibraryUpdater"
Import-Module .\SteamLibraryUpdater.psm1

# Check if Steam is running
Test-SteamRunning

# View configuration
Get-SteamLibraryUpdaterConfig

# Manual update check
Start-SteamLibraryUpdate -Verbose
```

## Viewing Logs

Check what the updater has been doing:

```powershell
# View today's log
notepad "C:\Program Files\SteamLibraryUpdater\Logs\SteamLibraryUpdater_$(Get-Date -Format 'yyyyMMdd').log"
```

## Uninstalling

If you need to remove Steam Library Updater:

1. Go to **Settings** → **Apps** → **Apps & features**
2. Search for "Steam Library Updater"
3. Click **Uninstall**

**OR**

```powershell
# Run as Administrator
C:\Program Files\SteamLibraryUpdater\Uninstall-SteamLibraryUpdater.ps1
```

## Need Help?

- Check the [full README](README.md) for detailed documentation
- Review the logs in `C:\Program Files\SteamLibraryUpdater\Logs\`
- Open an issue on GitHub

## Pro Tips

💡 **Tip 1**: Start with just 1-2 games to test before adding your entire library

💡 **Tip 2**: Keep "Update During Gaming" disabled to avoid performance issues

💡 **Tip 3**: Check the logs occasionally to ensure updates are happening

💡 **Tip 4**: SteamCMD will download on first run - this is normal and may take a few minutes
