
function Add-Game-AutoDetect {
    Write-Host ""
    Write-Host "Scanning for installed Steam games..." -ForegroundColor Yellow

    $installedGames = Get-InstalledSteamGames

    if ($installedGames.Count -eq 0) {
        Write-Host "No Steam games found. Make sure Steam is installed." -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    $config = Get-SteamLibraryUpdaterConfig
    $monitoredAppIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($game in $config.MonitoredGames) {
        $null = $monitoredAppIds.Add($game.AppId)
    }

    $availableGames = $installedGames | Where-Object { -not $monitoredAppIds.Contains($_.AppId) }

    if ($availableGames.Count -eq 0) {
        Write-Host "All installed games are already being monitored!" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }

    Write-Host ""
    Write-Host "Found $($availableGames.Count) games not yet monitored:" -ForegroundColor Green
    Write-Host ""

    $maxDisplayGames = 20
    for ($i = 0; $i -lt [Math]::Min($availableGames.Count, $maxDisplayGames); $i++) {
        $game = $availableGames[$i]
        Write-Host "  [$($i + 1)] $($game.Name) (AppId: $($game.AppId))" -ForegroundColor White
    }

    if ($availableGames.Count -gt $maxDisplayGames) {
        Write-Host "  ... and $($availableGames.Count - $maxDisplayGames) more" -ForegroundColor Gray
    }

    Write-Host ""
    $selection = Read-Host "Enter number to add (or press Enter to cancel)"

    if ($selection -match '^\d+$') {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $availableGames.Count) {
            $selectedGame = $availableGames[$index]
            Write-Host ""
            Write-Host "Adding $($selectedGame.Name)..." -ForegroundColor Yellow
            if (Add-MonitoredGame -AppId $selectedGame.AppId -Name $selectedGame.Name -InstallDir $selectedGame.InstallDir -ProcessName $selectedGame.ProcessName) {
                Write-Host "Successfully added $($selectedGame.Name) to monitoring" -ForegroundColor Green
            } else {
                Write-Host "Failed to add game" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid selection" -ForegroundColor Red
        }
    } else {
        Write-Host "Operation cancelled" -ForegroundColor Gray
    }
    Read-Host "Press Enter to continue"
}

function Add-Game-Manual {
    Write-Host ""
    Write-Host "--- Manual Entry ---" -ForegroundColor Cyan
    $appId = Read-Host "Enter Steam AppId (e.g. 730)"
    if ([string]::IsNullOrWhiteSpace($appId)) { return }

    $name = Read-Host "Enter game name (e.g. Counter-Strike 2)"
    if ([string]::IsNullOrWhiteSpace($name)) { return }

    $installDir = Read-Host "Enter install directory (e.g. C:\Steam\steamapps\common\Counter-Strike Global Offensive)"
    if ([string]::IsNullOrWhiteSpace($installDir)) { return }

    $processName = Read-Host "Enter process name without .exe (e.g. cs2) [Optional]"

    if (Add-MonitoredGame -AppId $appId -Name $name -InstallDir $installDir -ProcessName $processName) {
        Write-Host "Successfully added $name to monitoring" -ForegroundColor Green
    } else {
        Write-Host "Failed to add game" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Add-Game-Search {
    Write-Host ""
    Write-Host "--- Search By Name ---" -ForegroundColor Cyan
    $searchTerm = Read-Host "Enter game name to search for"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { return }

    Write-Host "Searching for $searchTerm..." -ForegroundColor Yellow
    $searchResults = Find-AppIdByName -GameName $searchTerm

    if (-not $searchResults) {
        Write-Host "No games found matching '$searchTerm'" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Write-Host ""
    Write-Host "Found $($searchResults.Count) matching games:" -ForegroundColor Green
    Write-Host ""

    for ($i = 0; $i -lt $searchResults.Count; $i++) {
        $result = $searchResults[$i]
        Write-Host "  [$($i + 1)] $($result.Name) (AppId: $($result.AppId))" -ForegroundColor White
    }

    Write-Host ""
    $selection = Read-Host "Enter number to add (or press Enter to cancel)"

    if ($selection -match '^\d+$') {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $searchResults.Count) {
            $searchResult = $searchResults[$index]
            $installedGames = Get-InstalledSteamGames
            $installedGame = $installedGames | Where-Object { $_.AppId -eq $searchResult.AppId }

            if ($installedGame) {
                Write-Host "Adding $($installedGame.Name)..." -ForegroundColor Yellow
                if (Add-MonitoredGame -AppId $installedGame.AppId -Name $installedGame.Name -InstallDir $installedGame.InstallDir -ProcessName $installedGame.ProcessName) {
                    Write-Host "Successfully added $($installedGame.Name) to monitoring" -ForegroundColor Green
                } else {
                    Write-Host "Failed to add game" -ForegroundColor Red
                }
            } else {
                Write-Host "Could not find install details for $($searchResult.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid selection" -ForegroundColor Red
        }
    } else {
        Write-Host "Operation cancelled" -ForegroundColor Gray
    }
    Read-Host "Press Enter to continue"
}


function Add-Game-AutoDetect {
    Write-Host ""
    Write-Host "Scanning for installed Steam games..." -ForegroundColor Yellow

    $installedGames = Get-InstalledSteamGames

    if ($installedGames.Count -eq 0) {
        Write-Host "No Steam games found. Make sure Steam is installed." -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    $config = Get-SteamLibraryUpdaterConfig
    $monitoredAppIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($game in $config.MonitoredGames) {
        $null = $monitoredAppIds.Add($game.AppId)
    }

    $availableGames = $installedGames | Where-Object { -not $monitoredAppIds.Contains($_.AppId) }

    if ($availableGames.Count -eq 0) {
        Write-Host "All installed games are already being monitored!" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }

    Write-Host ""
    Write-Host "Found $($availableGames.Count) games not yet monitored:" -ForegroundColor Green
    Write-Host ""

    $maxDisplayGames = 20
    for ($i = 0; $i -lt [Math]::Min($availableGames.Count, $maxDisplayGames); $i++) {
        $game = $availableGames[$i]
        Write-Host "  [$($i + 1)] $($game.Name) (AppId: $($game.AppId))" -ForegroundColor White
    }

    if ($availableGames.Count -gt $maxDisplayGames) {
        Write-Host "  ... and $($availableGames.Count - $maxDisplayGames) more" -ForegroundColor Gray
    }

    Write-Host ""
    $selection = Read-Host "Enter number to add (or press Enter to cancel)"

    if ($selection -match '^\d+$') {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $availableGames.Count) {
            $selectedGame = $availableGames[$index]
            Write-Host ""
            Write-Host "Adding $($selectedGame.Name)..." -ForegroundColor Yellow
            if (Add-MonitoredGame -AppId $selectedGame.AppId -Name $selectedGame.Name -InstallDir $selectedGame.InstallDir -ProcessName $selectedGame.ProcessName) {
                Write-Host "Successfully added $($selectedGame.Name) to monitoring" -ForegroundColor Green
            } else {
                Write-Host "Failed to add game" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid selection" -ForegroundColor Red
        }
    } else {
        Write-Host "Operation cancelled" -ForegroundColor Gray
    }
    Read-Host "Press Enter to continue"
}

function Add-Game-Manual {
    Write-Host ""
    Write-Host "--- Manual Entry ---" -ForegroundColor Cyan
    $appId = Read-Host "Enter Steam AppId (e.g. 730)"
    if ([string]::IsNullOrWhiteSpace($appId)) { return }

    $name = Read-Host "Enter game name (e.g. Counter-Strike 2)"
    if ([string]::IsNullOrWhiteSpace($name)) { return }

    $installDir = Read-Host "Enter install directory (e.g. C:\Steam\steamapps\common\Counter-Strike Global Offensive)"
    if ([string]::IsNullOrWhiteSpace($installDir)) { return }

    $processName = Read-Host "Enter process name without .exe (e.g. cs2) [Optional]"

    if (Add-MonitoredGame -AppId $appId -Name $name -InstallDir $installDir -ProcessName $processName) {
        Write-Host "Successfully added $name to monitoring" -ForegroundColor Green
    } else {
        Write-Host "Failed to add game" -ForegroundColor Red
    }
    Read-Host "Press Enter to continue"
}

function Add-Game-Search {
    Write-Host ""
    Write-Host "--- Search By Name ---" -ForegroundColor Cyan
    $searchTerm = Read-Host "Enter game name to search for"
    if ([string]::IsNullOrWhiteSpace($searchTerm)) { return }

    Write-Host "Searching for $searchTerm..." -ForegroundColor Yellow
    $searchResults = Find-AppIdByName -GameName $searchTerm

    if (-not $searchResults) {
        Write-Host "No games found matching '$searchTerm'" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }

    Write-Host ""
    Write-Host "Found $($searchResults.Count) matching games:" -ForegroundColor Green
    Write-Host ""

    for ($i = 0; $i -lt $searchResults.Count; $i++) {
        $result = $searchResults[$i]
        Write-Host "  [$($i + 1)] $($result.Name) (AppId: $($result.AppId))" -ForegroundColor White
    }

    Write-Host ""
    $selection = Read-Host "Enter number to add (or press Enter to cancel)"

    if ($selection -match '^\d+$') {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $searchResults.Count) {
            $searchResult = $searchResults[$index]
            $installedGames = Get-InstalledSteamGames
            $installedGame = $installedGames | Where-Object { $_.AppId -eq $searchResult.AppId }

            if ($installedGame) {
                Write-Host "Adding $($installedGame.Name)..." -ForegroundColor Yellow
                if (Add-MonitoredGame -AppId $installedGame.AppId -Name $installedGame.Name -InstallDir $installedGame.InstallDir -ProcessName $installedGame.ProcessName) {
                    Write-Host "Successfully added $($installedGame.Name) to monitoring" -ForegroundColor Green
                } else {
                    Write-Host "Failed to add game" -ForegroundColor Red
                }
            } else {
                Write-Host "Could not find install details for $($searchResult.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid selection" -ForegroundColor Red
        }
    } else {
        Write-Host "Operation cancelled" -ForegroundColor Gray
    }
    Read-Host "Press Enter to continue"
}

#Requires -Version 5.1

<#
.SYNOPSIS
    Configuration tool for Steam Update Manager
.DESCRIPTION
    Provides an interactive interface to configure Steam Update Manager settings and manage monitored games.
.EXAMPLE
    .\Configure-SteamLibraryUpdater.ps1
#>

[CmdletBinding()]
param()

# Determine the correct module path
if (Test-Path "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1") {
    $modulePath = "C:\Program Files\Steam-Update-Manager\SteamLibraryUpdater.psm1"
}
elseif (Test-Path "C:\Program Files\SteamLibraryUpdater\SteamLibraryUpdater.psm1") {
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
    Write-Host " Steam Update Manager - Configuration" -ForegroundColor Cyan
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
    Write-Host "  [6] Quick Add All Installed Games" -ForegroundColor White
    Write-Host "  [7] View Full Configuration" -ForegroundColor White
    Write-Host "  [8] Test Update Check (Manual)" -ForegroundColor White
    Write-Host "  [9] View Logs" -ForegroundColor White
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
    
    Write-Host "How would you like to add the game?" -ForegroundColor Yellow
    Write-Host "  [1] Auto-detect from installed games" -ForegroundColor White
    Write-Host "  [2] Enter manually" -ForegroundColor White
    Write-Host "  [3] Search by name" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Enter choice (1-3)"
    
    switch ($choice) {
        "1" { Add-Game-AutoDetect }
        "2" { Add-Game-Manual }
        "3" { Add-Game-Search }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            Read-Host "Press Enter to continue"
        }
    }
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
    
    $paths = Get-SteamUpdateManagerPaths
    $logPath = if (Test-Path $paths.LogPath) {
        $paths.LogPath
    }
    elseif (Test-Path "C:\Program Files\SteamLibraryUpdater\Logs") {
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

function Quick-AddAll {
    Write-Host ""
    Write-Host "=== Quick Add All Installed Games ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will scan your Steam library and add all installed games to monitoring." -ForegroundColor Yellow
    Write-Host ""
    
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Cancelled" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    Write-Host "Scanning for installed Steam games..." -ForegroundColor Yellow
    
    $installedGames = Get-InstalledSteamGames
    
    if ($installedGames.Count -eq 0) {
        Write-Host "No Steam games found." -ForegroundColor Red
        Read-Host "Press Enter to continue"
        return
    }
    
    # Get currently monitored games
    $config = Get-SteamLibraryUpdaterConfig
    $monitoredAppIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($game in $config.MonitoredGames) {
        $null = $monitoredAppIds.Add($game.AppId)
    }
    
    # Filter out already monitored games
    $availableGames = $installedGames | Where-Object { -not $monitoredAppIds.Contains($_.AppId) }
    
    if ($availableGames.Count -eq 0) {
        Write-Host "All installed games are already being monitored!" -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        return
    }
    
    Write-Host ""
    Write-Host "Found $($availableGames.Count) games to add:" -ForegroundColor Green
    Write-Host ""
    
    $added = 0
    $failed = 0
    
    foreach ($game in $availableGames) {
        Write-Host "  Adding: $($game.Name)..." -NoNewline -ForegroundColor White
        
        if (Add-MonitoredGame -AppId $game.AppId -Name $game.Name -InstallDir $game.InstallDir -ProcessName $game.ProcessName) {
            Write-Host " OK" -ForegroundColor Green
            $added++
        }
        else {
            Write-Host " FAILED" -ForegroundColor Red
            $failed++
        }
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Added: $added" -ForegroundColor Green
    if ($failed -gt 0) {
        Write-Host "  Failed: $failed" -ForegroundColor Red
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
        "6" { Quick-AddAll }
        "7" { View-FullConfig }
        "8" { Test-Update }
        "9" { View-Logs }
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
