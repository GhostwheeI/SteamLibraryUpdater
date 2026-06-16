# Quick Start Guide

Get Steam Update Manager up and running in 5 minutes!

## Step 1: Install

1. **Download** this repository
2. **Right-click** on `Install-SteamLibraryUpdater.ps1`
3. **Select** "Run with PowerShell" (as Administrator)
4. **Follow** the installation prompts

## Step 2: Configure Your Games

Run the configuration tool to automatically detect and add your Steam games:

```powershell
# Open PowerShell as Administrator
C:\Program Files\Steam-Update-Manager\Configure-SteamLibraryUpdater.ps1
```

Note: The installer already auto-detects and adds installed games. Use the tool below to review or adjust the list.

**Easy Options:**
- Press **4** then **1** to auto-detect installed games (pick from a list)
- Press **6** to automatically add ALL your installed Steam games at once
- Press **4** then **3** to search for a game by name

**Note:** SteamCMD will be automatically downloaded during installation if you chose "Yes" when prompted. If you skipped it, the installer will provide download instructions.

## Step 3: Done!

That's it! Steam Update Manager will now:
- ✅ Run automatically when Steam is running
- ✅ Check for updates on your configured interval (default: 60 minutes)
- ✅ Update games when you're not playing (by default)
- ✅ Log all activities

## Finding Steam App IDs (Optional - Not Usually Needed)

With the new auto-detection features, you rarely need to look up App IDs manually! But if you need to:

**Method 1: Use the Search Feature**
- Run the configuration tool and select option 4 (Add Game), then option 3 (Search by name)
- Enter the game name and it will automatically find the App ID

**Method 2: Manual Lookup**
1. Go to https://steamdb.info/
2. Search for your game
3. The App ID is shown on the game's page

**Method 3: From Steam Store**
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
cd "C:\Program Files\Steam-Update-Manager"
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
notepad "C:\ProgramData\Steam-Update-Manager\Logs\SteamUpdateManager_$(Get-Date -Format 'yyyyMMdd').log"
```

## Uninstalling

If you need to remove Steam Update Manager:

1. Go to **Settings** → **Apps** → **Apps & features**
2. Search for "Steam Update Manager"
3. Click **Uninstall**

**OR**

```powershell
# Run as Administrator
C:\Program Files\Steam-Update-Manager\Uninstall-SteamLibraryUpdater.ps1
```

## Need Help?

- Check the [full README](README.md) for detailed documentation
- Review the logs in `C:\ProgramData\Steam-Update-Manager\Logs\`
- Open an issue on GitHub

## Pro Tips

💡 **Tip 1**: Start with just 1-2 games to test before adding your entire library

💡 **Tip 2**: Keep "Update During Gaming" disabled to avoid performance issues

💡 **Tip 3**: Check the logs occasionally to ensure updates are happening

💡 **Tip 4**: SteamCMD will download on first run - this is normal and may take a few minutes

