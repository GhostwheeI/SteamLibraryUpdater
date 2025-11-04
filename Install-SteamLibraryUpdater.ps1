#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs Steam Library Updater
.DESCRIPTION
    Installs Steam Library Updater as a service that runs when Steam is running.
    Configures Windows Task Scheduler to monitor Steam and update games automatically.
.EXAMPLE
    .\Install-SteamLibraryUpdater.ps1
#>

[CmdletBinding()]
param()

# Configuration
$InstallPath = Join-Path $env:ProgramFiles "SteamLibraryUpdater"
$TaskName = "SteamLibraryUpdater"
$ProductName = "Steam Library Updater"
$Version = "1.0.0"
$Publisher = "GhostwheeI"
$UninstallGuid = "{B4C8A9E2-1234-5678-9ABC-DEF012345678}"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Steam Library Updater - Installation" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Create installation directory
Write-Host "[1/7] Creating installation directory..." -ForegroundColor Yellow
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy files to installation directory
Write-Host "[2/7] Copying files..." -ForegroundColor Yellow
$sourceFiles = @(
    "SteamLibraryUpdater.psm1",
    "Uninstall-SteamLibraryUpdater.ps1"
)

foreach ($file in $sourceFiles) {
    $sourcePath = Join-Path $PSScriptRoot $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $InstallPath -Force
        Write-Host "  Copied: $file" -ForegroundColor Green
    }
    else {
        Write-Host "  Warning: $file not found in source directory" -ForegroundColor Yellow
    }
}

# Create necessary subdirectories
$subDirs = @("appinfo", "steamcmd", "Logs")
foreach ($dir in $subDirs) {
    $dirPath = Join-Path $InstallPath $dir
    if (-not (Test-Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
    }
}

# Create default configuration
Write-Host "[3/7] Creating default configuration..." -ForegroundColor Yellow
$configPath = Join-Path $InstallPath "Config.json"
if (-not (Test-Path $configPath)) {
    $defaultConfig = @{
        UpdateDuringGaming = $false
        CheckIntervalMinutes = 60
        EnableAutoUpdate = $true
        SteamInstallPath = ""
        MonitoredGames = @()
        LastCheck = $null
    }
    
    $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
    Write-Host "  Configuration created with default settings" -ForegroundColor Green
}

# Prompt user for configuration preferences
Write-Host ""
Write-Host "=== Configuration ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "By default, Steam Library Updater will NOT update games while you are gaming"
Write-Host "to avoid impacting your connection speed or computer performance."
Write-Host ""
$updateDuringGaming = Read-Host "Do you want to allow updates while gaming? (y/N)"
if ($updateDuringGaming -match '^[Yy]') {
    $config = Get-Content $configPath | ConvertFrom-Json
    $config.UpdateDuringGaming = $true
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Force
    Write-Host "  Updates will be allowed while gaming" -ForegroundColor Green
}
else {
    Write-Host "  Updates will be paused while gaming (default)" -ForegroundColor Green
}

# Create scheduled task to monitor Steam
Write-Host ""
Write-Host "[4/7] Creating scheduled task..." -ForegroundColor Yellow

# Remove existing task if it exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create the scheduled task script
$taskScriptPath = Join-Path $InstallPath "RunUpdater.ps1"
$taskScriptContent = @"
# Steam Library Updater - Scheduled Task Script
Set-Location '$InstallPath'
Import-Module '.\SteamLibraryUpdater.psm1' -Force

# Check if Steam is running
`$steamRunning = Get-Process -Name 'steam' -ErrorAction SilentlyContinue
if (`$null -eq `$steamRunning) {
    exit 0
}

# Run the update check
Start-SteamLibraryUpdate -Verbose
"@

Set-Content -Path $taskScriptPath -Value $taskScriptContent -Force

# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$taskScriptPath`""

# Trigger: Run every hour when any user is logged on
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 60)

# Settings
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

# Principal - Run with highest privileges as SYSTEM for all users
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType Service -RunLevel Highest

# Register the task
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Automatically updates Steam games when Steam is running" -Force | Out-Null

Write-Host "  Scheduled task created: $TaskName" -ForegroundColor Green

# Create Add/Remove Programs entry
Write-Host "[5/7] Creating Add/Remove Programs entry..." -ForegroundColor Yellow

$uninstallRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallGuid"
if (-not (Test-Path $uninstallRegPath)) {
    New-Item -Path $uninstallRegPath -Force | Out-Null
}

# Set registry values
Set-ItemProperty -Path $uninstallRegPath -Name "DisplayName" -Value $ProductName -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "DisplayVersion" -Value $Version -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "Publisher" -Value $Publisher -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "InstallLocation" -Value $InstallPath -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "UninstallString" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$InstallPath\Uninstall-SteamLibraryUpdater.ps1`"" -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "DisplayIcon" -Value "$env:SystemRoot\System32\shell32.dll,13" -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallRegPath -Name "NoRepair" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallRegPath -Name "InstallDate" -Value (Get-Date -Format "yyyyMMdd") -Type String

# Calculate estimated size (in KB)
$size = (Get-ChildItem -Path $InstallPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1KB
Set-ItemProperty -Path $uninstallRegPath -Name "EstimatedSize" -Value ([math]::Round($size)) -Type DWord

Write-Host "  Added to Programs and Features" -ForegroundColor Green

# Check for SteamCMD and offer to download it
Write-Host "[6/7] Checking for SteamCMD..." -ForegroundColor Yellow
$steamCmdPath = Join-Path $InstallPath "steamcmd\steamcmd.exe"
if (-not (Test-Path $steamCmdPath)) {
    Write-Host ""
    Write-Host "  SteamCMD not found. This is required for automatic updates." -ForegroundColor Yellow
    Write-Host ""
    $downloadSteamCmd = Read-Host "Would you like to download and install SteamCMD automatically? (Y/n)"
    
    if ($downloadSteamCmd -notmatch '^[Nn]') {
        Write-Host "  Downloading SteamCMD..." -ForegroundColor Yellow
        
        try {
            $steamCmdZip = Join-Path $env:TEMP "steamcmd.zip"
            $steamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
            
            # Download SteamCMD
            Invoke-WebRequest -Uri $steamCmdUrl -OutFile $steamCmdZip -UseBasicParsing
            
            # Extract to installation directory
            $steamCmdDir = Join-Path $InstallPath "steamcmd"
            if (-not (Test-Path $steamCmdDir)) {
                New-Item -ItemType Directory -Path $steamCmdDir -Force | Out-Null
            }
            
            Expand-Archive -Path $steamCmdZip -DestinationPath $steamCmdDir -Force
            Remove-Item $steamCmdZip -Force
            
            Write-Host "  SteamCMD downloaded and installed successfully!" -ForegroundColor Green
            
            # Initialize SteamCMD (accept EULA and update)
            Write-Host "  Initializing SteamCMD (this may take a moment)..." -ForegroundColor Yellow
            $process = Start-Process -FilePath $steamCmdPath -ArgumentList "+quit" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\steamcmd_init.log" -RedirectStandardError "$env:TEMP\steamcmd_error.log"
            
            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 7) {
                Write-Host "  SteamCMD initialized successfully!" -ForegroundColor Green
            }
            else {
                Write-Host "  Warning: SteamCMD initialization may have encountered issues (exit code: $($process.ExitCode))" -ForegroundColor Yellow
                Write-Host "  The tool should still work, but check logs if you encounter problems." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  Error downloading SteamCMD: $_" -ForegroundColor Red
            Write-Host "  You can manually download it from: https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -ForegroundColor Cyan
            Write-Host "  Extract it to: $InstallPath\steamcmd\" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "  Skipped. You can manually download SteamCMD from:" -ForegroundColor Yellow
        Write-Host "  https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -ForegroundColor Cyan
        Write-Host "  Extract it to: $InstallPath\steamcmd\" -ForegroundColor Cyan
    }
    Write-Host ""
}
else {
    Write-Host "  SteamCMD found" -ForegroundColor Green
}

# Create desktop shortcut for configuration
Write-Host "[7/7] Creating configuration shortcut..." -ForegroundColor Yellow
$configScriptPath = Join-Path $InstallPath "Configure.ps1"
$configScriptContent = @"
# Steam Library Updater - Configuration Tool
Import-Module '$InstallPath\SteamLibraryUpdater.psm1' -Force

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Steam Library Updater - Configuration" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

`$config = Get-SteamLibraryUpdaterConfig

Write-Host "Current Configuration:" -ForegroundColor Yellow
Write-Host "  Update During Gaming: `$(`$config.UpdateDuringGaming)" -ForegroundColor White
Write-Host "  Check Interval: `$(`$config.CheckIntervalMinutes) minutes" -ForegroundColor White
Write-Host "  Auto Update Enabled: `$(`$config.EnableAutoUpdate)" -ForegroundColor White
Write-Host "  Monitored Games: `$(`$config.MonitoredGames.Count)" -ForegroundColor White
Write-Host ""

if (`$config.MonitoredGames.Count -gt 0) {
    Write-Host "Monitored Games:" -ForegroundColor Yellow
    foreach (`$game in `$config.MonitoredGames) {
        Write-Host "  - `$(`$game.Name) (AppId: `$(`$game.AppId))" -ForegroundColor White
    }
    Write-Host ""
}

Write-Host "To add games to monitor, use the Add-MonitoredGame function" -ForegroundColor Cyan
Write-Host "Example:" -ForegroundColor Cyan
Write-Host "  Add-MonitoredGame -AppId '730' -Name 'Counter-Strike 2' -InstallDir 'C:\Path\To\Game' -ProcessName 'cs2'" -ForegroundColor Gray
Write-Host ""

Read-Host "Press Enter to exit"
"@

Set-Content -Path $configScriptPath -Value $configScriptContent -Force

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " Installation Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Steam Library Updater has been installed successfully." -ForegroundColor White
Write-Host ""
Write-Host "Location: $InstallPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "The updater will automatically run when Steam is running." -ForegroundColor White
Write-Host "It checks for updates every 60 minutes." -ForegroundColor White
Write-Host ""
if (-not (Test-Path $steamCmdPath)) {
    Write-Host "IMPORTANT: Please download and install SteamCMD:" -ForegroundColor Yellow
    Write-Host "  1. Download from: https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip" -ForegroundColor Cyan
    Write-Host "  2. Extract to: $InstallPath\steamcmd\" -ForegroundColor Cyan
    Write-Host ""
}
Write-Host "To configure and add games to monitor:" -ForegroundColor White
Write-Host "  1. Open PowerShell as Administrator" -ForegroundColor Cyan
Write-Host "  2. Run: $configScriptPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To uninstall, use 'Add/Remove Programs' or run:" -ForegroundColor White
Write-Host "  $InstallPath\Uninstall-SteamLibraryUpdater.ps1" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to exit"
