#Requires -Version 5.1

<#
.SYNOPSIS
    Configuration tool for Steam Library Updater
.DESCRIPTION
    Provides an interactive interface to configure Steam Library Updater settings and manage monitored games.
.EXAMPLE
    .\Configure-SteamLibraryUpdater.ps1
#>

[CmdletBinding()]
param()

# Determine the correct module path
if (Test-Path "C:\Program Files\SteamLibraryUpdater\SteamLibraryUpdater.psm1") {
    $modulePath = "C:\Program Files\SteamLibraryUpdater\SteamLibraryUpdater.psm1"
}
elseif (Test-Path (Join-Path $PSScriptRoot "SteamLibraryUpdater.psm1")) {
    $modulePath = Join-Path $PSScriptRoot "SteamLibraryUpdater.psm1"
}
else {
    Write-Host "ERROR: Could not find SteamLibraryUpdater module" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Import-Module $modulePath -Force

function Show-Menu {
    Clear-Host
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Steam Library Updater - Configuration" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $config = Get-SteamLibraryUpdaterConfig
    
    Write-Host "Current Settings:" -ForegroundColor Yellow
    Write-Host "  [1] Update During Gaming: " -NoNewline -ForegroundColor White
    Write-Host $config.UpdateDuringGaming -ForegroundColor $(if ($config.UpdateDuringGaming) { "Green" } else { "Red" })
    Write-Host "  [2] Check Interval: " -NoNewline -ForegroundColor White
    Write-Host "$($config.CheckIntervalMinutes) minutes" -ForegroundColor Cyan
    Write-Host "  [3] Auto Update Enabled: " -NoNewline -ForegroundColor White
    Write-Host $config.EnableAutoUpdate -ForegroundColor $(if ($config.EnableAutoUpdate) { "Green" } else { "Red" })
    Write-Host ""
    Write-Host "Monitored Games: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($config.MonitoredGames.Count)" -ForegroundColor Cyan
    
    if ($config.MonitoredGames.Count -gt 0) {
        Write-Host ""
        foreach ($game in $config.MonitoredGames) {
            Write-Host "  • $($game.Name)" -ForegroundColor White -NoNewline
            Write-Host " (AppId: $($game.AppId))" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Yellow
    Write-Host "  [4] Add Game to Monitor" -ForegroundColor White
    Write-Host "  [5] Remove Game from Monitoring" -ForegroundColor White
    Write-Host "  [6] View Full Configuration" -ForegroundColor White
    Write-Host "  [7] Test Update Check (Manual)" -ForegroundColor White
    Write-Host "  [8] View Logs" -ForegroundColor White
    Write-Host "  [Q] Quit" -ForegroundColor White
    Write-Host ""
}

function Toggle-UpdateDuringGaming {
    $config = Get-SteamLibraryUpdaterConfig
    $config.UpdateDuringGaming = -not $config.UpdateDuringGaming
    
    if (Set-SteamLibraryUpdaterConfig -Config $config) {
        Write-Host ""
        Write-Host "Update During Gaming: $($config.UpdateDuringGaming)" -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "Failed to save configuration" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Set-CheckInterval {
    Write-Host ""
    $interval = Read-Host "Enter check interval in minutes (current: $((Get-SteamLibraryUpdaterConfig).CheckIntervalMinutes))"
    
    if ($interval -match '^\d+$' -and [int]$interval -gt 0) {
        $config = Get-SteamLibraryUpdaterConfig
        $config.CheckIntervalMinutes = [int]$interval
        
        if (Set-SteamLibraryUpdaterConfig -Config $config) {
            Write-Host "Check interval updated to $interval minutes" -ForegroundColor Green
        }
        else {
            Write-Host "Failed to save configuration" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Invalid interval. Must be a positive number." -ForegroundColor Red
    }
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Toggle-AutoUpdate {
    $config = Get-SteamLibraryUpdaterConfig
    $config.EnableAutoUpdate = -not $config.EnableAutoUpdate
    
    if (Set-SteamLibraryUpdaterConfig -Config $config) {
        Write-Host ""
        Write-Host "Auto Update Enabled: $($config.EnableAutoUpdate)" -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "Failed to save configuration" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Add-Game {
    Write-Host ""
    Write-Host "=== Add Game to Monitor ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You can find Steam App IDs at https://steamdb.info/" -ForegroundColor Gray
    Write-Host ""
    
    $appId = Read-Host "Enter Steam App ID (e.g., 730 for CS2)"
    if (-not $appId) {
        Write-Host "Cancelled" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    $name = Read-Host "Enter game name (e.g., Counter-Strike 2)"
    if (-not $name) {
        Write-Host "Cancelled" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    $installDir = Read-Host "Enter full install directory path"
    if (-not $installDir -or -not (Test-Path $installDir)) {
        Write-Host "Invalid directory path - directory does not exist" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    # Validate it's a directory, not a file
    if (-not (Test-Path $installDir -PathType Container)) {
        Write-Host "Invalid path - must be a directory, not a file" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    # Warn if directory doesn't look like a Steam game directory
    $steamIndicators = @("*.exe", "*.dll", "steam_appid.txt")
    $hasIndicators = $false
    foreach ($pattern in $steamIndicators) {
        if (Get-ChildItem -Path $installDir -Filter $pattern -File -ErrorAction SilentlyContinue) {
            $hasIndicators = $true
            break
        }
    }
    
    if (-not $hasIndicators) {
        Write-Host "Warning: This directory doesn't appear to contain game files" -ForegroundColor Yellow
        $confirm = Read-Host "Continue anyway? (y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host "Cancelled" -ForegroundColor Yellow
            Read-Host "Press Enter to continue"
            return
        }
    }
    
    $processName = Read-Host "Enter game process name (optional, press Enter to skip)"
    
    Write-Host ""
    Write-Host "Adding game to monitoring..." -ForegroundColor Yellow
    
    if (Add-MonitoredGame -AppId $appId -Name $name -InstallDir $installDir -ProcessName $processName) {
        Write-Host "Successfully added $name to monitoring" -ForegroundColor Green
    }
    else {
        Write-Host "Failed to add game" -ForegroundColor Red
    }
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Remove-Game {
    $config = Get-SteamLibraryUpdaterConfig
    
    if ($config.MonitoredGames.Count -eq 0) {
        Write-Host ""
        Write-Host "No games are currently being monitored" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    Write-Host "=== Remove Game from Monitoring ===" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $config.MonitoredGames.Count; $i++) {
        $game = $config.MonitoredGames[$i]
        Write-Host "  [$($i + 1)] $($game.Name) (AppId: $($game.AppId))" -ForegroundColor White
    }
    
    Write-Host ""
    $selection = Read-Host "Enter number to remove (or press Enter to cancel)"
    
    if ($selection -match '^\d+$') {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $config.MonitoredGames.Count) {
            $game = $config.MonitoredGames[$index]
            if (Remove-MonitoredGame -AppId $game.AppId) {
                Write-Host "Successfully removed $($game.Name)" -ForegroundColor Green
            }
            else {
                Write-Host "Failed to remove game" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Invalid selection" -ForegroundColor Red
        }
    }
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function View-FullConfig {
    Write-Host ""
    Write-Host "=== Full Configuration ===" -ForegroundColor Cyan
    Write-Host ""
    
    $config = Get-SteamLibraryUpdaterConfig
    $config | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor White
    
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function Test-Update {
    Write-Host ""
    Write-Host "=== Running Manual Update Check ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This may take a few minutes..." -ForegroundColor Yellow
    Write-Host ""
    
    try {
        Start-SteamLibraryUpdate -Verbose
        Write-Host ""
        Write-Host "Update check completed" -ForegroundColor Green
    }
    catch {
        Write-Host "Error during update check: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "Press Enter to continue"
}

function View-Logs {
    Write-Host ""
    Write-Host "=== Recent Log Entries ===" -ForegroundColor Cyan
    Write-Host ""
    
    $logPath = if (Test-Path "C:\Program Files\SteamLibraryUpdater\Logs") {
        "C:\Program Files\SteamLibraryUpdater\Logs"
    }
    elseif (Test-Path (Join-Path $PSScriptRoot "Logs")) {
        Join-Path $PSScriptRoot "Logs"
    }
    else {
        $null
    }
    
    if (-not $logPath) {
        Write-Host "No logs found" -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to continue"
        return
    }
    
    $logFile = Get-ChildItem -Path $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($logFile) {
        Write-Host "Log file: $($logFile.FullName)" -ForegroundColor Gray
        Write-Host ""
        Get-Content $logFile.FullName -Tail 20 | Write-Host -ForegroundColor White
    }
    else {
        Write-Host "No log files found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Read-Host "Press Enter to continue"
}

# Main loop
while ($true) {
    Show-Menu
    
    $choice = Read-Host "Enter your choice"
    
    switch ($choice.ToUpper()) {
        "1" { Toggle-UpdateDuringGaming }
        "2" { Set-CheckInterval }
        "3" { Toggle-AutoUpdate }
        "4" { Add-Game }
        "5" { Remove-Game }
        "6" { View-FullConfig }
        "7" { Test-Update }
        "8" { View-Logs }
        "Q" { 
            Write-Host ""
            Write-Host "Goodbye!" -ForegroundColor Cyan
            Write-Host ""
            exit 0
        }
        default { 
            Write-Host ""
            Write-Host "Invalid choice. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
