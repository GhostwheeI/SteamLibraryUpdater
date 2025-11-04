#Requires -Version 5.1

<#
.SYNOPSIS
    Steam Library Updater - Automated Steam game update management
.DESCRIPTION
    Monitors and updates Steam games automatically when Steam is running
#>

# Module configuration
$script:ModuleConfig = @{
    ConfigPath = Join-Path $PSScriptRoot "Config.json"
    AppInfoPath = Join-Path $PSScriptRoot "appinfo"
    SteamCmdPath = Join-Path $PSScriptRoot "steamcmd\steamcmd.exe"
    LogPath = Join-Path $PSScriptRoot "Logs"
}

# Ensure directories exist
if (-not (Test-Path $script:ModuleConfig.AppInfoPath)) {
    New-Item -ItemType Directory -Path $script:ModuleConfig.AppInfoPath -Force | Out-Null
}

if (-not (Test-Path $script:ModuleConfig.LogPath)) {
    New-Item -ItemType Directory -Path $script:ModuleConfig.LogPath -Force | Out-Null
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log message to the log file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $script:ModuleConfig.LogPath "SteamLibraryUpdater_$(Get-Date -Format 'yyyyMMdd').log"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $logFile -Value $logMessage
    Write-Verbose $logMessage
}

function Get-SteamLibraryUpdaterConfig {
    <#
    .SYNOPSIS
        Gets the current configuration
    #>
    [CmdletBinding()]
    param()
    
    if (Test-Path $script:ModuleConfig.ConfigPath) {
        try {
            $config = Get-Content $script:ModuleConfig.ConfigPath -Raw | ConvertFrom-Json
            return $config
        }
        catch {
            Write-Log "Error reading config file: $_" -Level Error
        }
    }
    
    # Return default configuration
    return [PSCustomObject]@{
        UpdateDuringGaming = $false
        CheckIntervalMinutes = 60
        EnableAutoUpdate = $true
        SteamInstallPath = ""
        MonitoredGames = @()
        LastCheck = $null
    }
}

function Set-SteamLibraryUpdaterConfig {
    <#
    .SYNOPSIS
        Sets the configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )
    
    try {
        $Config | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.ConfigPath -Force
        Write-Log "Configuration saved successfully"
        return $true
    }
    catch {
        Write-Log "Error saving config file: $_" -Level Error
        return $false
    }
}

function Test-SteamRunning {
    <#
    .SYNOPSIS
        Checks if Steam is currently running
    #>
    [CmdletBinding()]
    param()
    
    $steamProcess = Get-Process -Name "steam" -ErrorAction SilentlyContinue
    return ($null -ne $steamProcess)
}

function Test-GameRunning {
    <#
    .SYNOPSIS
        Checks if any Steam game is currently running
    #>
    [CmdletBinding()]
    param()
    
    $config = Get-SteamLibraryUpdaterConfig
    
    # Get all processes once for efficiency
    $allProcesses = Get-Process -ErrorAction SilentlyContinue
    
    # Check if any monitored game processes are running
    foreach ($game in $config.MonitoredGames) {
        if ($game.ProcessName) {
            $process = $allProcesses | Where-Object { $_.ProcessName -eq $game.ProcessName }
            if ($null -ne $process) {
                Write-Log "Game running: $($game.ProcessName)" -Level Info
                return $true
            }
        }
    }
    
    # Also check for common Steam game indicators
    # Steam games often have GameOverlayUI process
    $overlayProcess = Get-Process -Name "GameOverlayUI" -ErrorAction SilentlyContinue
    if ($null -ne $overlayProcess) {
        # Additional check: see if it's actively being used (more than just idle)
        $steamApps = Get-Process | Where-Object { 
            $_.MainWindowTitle -ne "" -and 
            $_.ProcessName -ne "steam" -and
            $_.Path -like "*steamapps*"
        }
        if ($steamApps) {
            Write-Log "Steam game detected via steamapps path" -Level Info
            return $true
        }
    }
    
    return $false
}

function Get-SteamAppInfo {
    <#
    .SYNOPSIS
        Gets app info from Steam API
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    # Validate AppId is numeric to prevent injection
    if ($AppId -notmatch '^\d+$') {
        Write-Log "Invalid AppId format: $AppId. Must be numeric." -Level Error
        return $null
    }
    
    try {
        $uri = "https://api.steamcmd.net/v1/info/$AppId"
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 30
        return $response
    }
    catch {
        Write-Log "Error getting app info for $AppId : $_" -Level Error
        return $null
    }
}

function Test-GameNeedsUpdate {
    <#
    .SYNOPSIS
        Checks if a game needs an update
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    if ($AppId -notmatch '^\d+$') {
        Write-Log "Invalid AppId: $AppId. Must be numeric." -Level Error
        return $false
    }
    $appInfoFile = Join-Path $script:ModuleConfig.AppInfoPath $AppId
    $appInfoFileNew = "$appInfoFile-new"
    
    Write-Log "Checking for updates for App ID: $AppId" -Level Info
    
    # Get current app info from Steam
    $appInfo = Get-SteamAppInfo -AppId $AppId
    if ($null -eq $appInfo) {
        Write-Log "Failed to retrieve app info for $AppId" -Level Error
        return $false
    }
    
    # Save new app info
    $appInfo | ConvertTo-Json -Depth 10 | Set-Content $appInfoFileNew -Force
    
    # Compare with previous version using hash for better performance
    if (Test-Path $appInfoFile) {
        $oldHash = (Get-FileHash -Path $appInfoFile -Algorithm SHA256).Hash
        $newHash = (Get-FileHash -Path $appInfoFileNew -Algorithm SHA256).Hash
        
        if ($oldHash -eq $newHash) {
            Write-Log "App $AppId is up-to-date" -Level Info
            Remove-Item $appInfoFileNew -Force
            return $false
        }
    }
    
    Write-Log "App $AppId needs update" -Level Info
    return $true
}

function Update-SteamGame {
    <#
    .SYNOPSIS
        Updates a Steam game using SteamCMD
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        
        [Parameter(Mandatory)]
        [string]$InstallDir
    )
    
    # Validate AppId is numeric to prevent command injection
    if ($AppId -notmatch '^\d+$') {
        Write-Log "Invalid AppId format: $AppId. Must be numeric." -Level Error
        return $false
    }
    
    if (-not (Test-Path $script:ModuleConfig.SteamCmdPath)) {
        Write-Log "SteamCMD not found at: $($script:ModuleConfig.SteamCmdPath)" -Level Error
        return $false
    }
    
    if (-not (Test-Path $InstallDir)) {
        Write-Log "Install directory not found: $InstallDir" -Level Error
        return $false
    }
    
    try {
        Write-Log "Starting update for App $AppId to $InstallDir" -Level Info
        
        # Properly escape the install directory path
        $escapedInstallDir = $InstallDir.Replace('"', '\"')
        $arguments = "+force_install_dir `"$escapedInstallDir`" +login anonymous +app_update $AppId validate +quit"
        $process = Start-Process -FilePath $script:ModuleConfig.SteamCmdPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Successfully updated App $AppId" -Level Info
            
            # Update the stored app info
            $appInfoFile = Join-Path $script:ModuleConfig.AppInfoPath $AppId
            $appInfoFileNew = "$appInfoFile-new"
            if (Test-Path $appInfoFileNew) {
                Move-Item $appInfoFileNew $appInfoFile -Force
            }
            
            return $true
        }
        else {
            Write-Log "SteamCMD exited with code: $($process.ExitCode)" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Error updating game: $_" -Level Error
        return $false
    }
}

function Start-SteamLibraryUpdate {
    <#
    .SYNOPSIS
        Main function to check and update Steam library
    #>
    [CmdletBinding()]
    param()
    
    Write-Log "Starting Steam Library update check" -Level Info
    
    # Check if Steam is running
    if (-not (Test-SteamRunning)) {
        Write-Log "Steam is not running, exiting" -Level Info
        return
    }
    
    # Get configuration
    $config = Get-SteamLibraryUpdaterConfig
    
    if (-not $config.EnableAutoUpdate) {
        Write-Log "Auto-update is disabled in configuration" -Level Info
        return
    }
    
    # Check if we should update during gaming
    $gameRunning = Test-GameRunning
    if ($gameRunning -and -not $config.UpdateDuringGaming) {
        Write-Log "Game is running and UpdateDuringGaming is false, skipping update" -Level Info
        return
    }
    
    # Update each monitored game
    foreach ($game in $config.MonitoredGames) {
        try {
            if (Test-GameNeedsUpdate -AppId $game.AppId) {
                Write-Log "Updating game: $($game.Name) (AppId: $($game.AppId))" -Level Info
                $result = Update-SteamGame -AppId $game.AppId -InstallDir $game.InstallDir
                
                if ($result) {
                    Write-Log "Successfully updated: $($game.Name)" -Level Info
                }
                else {
                    Write-Log "Failed to update: $($game.Name)" -Level Error
                }
            }
        }
        catch {
            Write-Log "Error processing game $($game.Name): $_" -Level Error
        }
    }
    
    # Update last check time
    $config.LastCheck = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-SteamLibraryUpdaterConfig -Config $config
    
    Write-Log "Steam Library update check completed" -Level Info
}

function Add-MonitoredGame {
    <#
    .SYNOPSIS
        Adds a game to the monitored games list
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$InstallDir,
        
        [string]$ProcessName
    )
    
    $config = Get-SteamLibraryUpdaterConfig
    
    # Check if game already exists
    $existing = $config.MonitoredGames | Where-Object { $_.AppId -eq $AppId }
    if ($existing) {
        Write-Log "Game with AppId $AppId already exists in configuration" -Level Warning
        return $false
    }
    
    # Add new game
    $newGame = [PSCustomObject]@{
        AppId = $AppId
        Name = $Name
        InstallDir = $InstallDir
        ProcessName = $ProcessName
        Added = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    # Use ArrayList for better performance
    $gamesList = [System.Collections.ArrayList]@($config.MonitoredGames)
    $gamesList.Add($newGame) | Out-Null
    $config.MonitoredGames = $gamesList.ToArray()
    
    $result = Set-SteamLibraryUpdaterConfig -Config $config
    if ($result) {
        Write-Log "Added game to monitoring: $Name (AppId: $AppId)" -Level Info
    }
    
    return $result
}

function Remove-MonitoredGame {
    <#
    .SYNOPSIS
        Removes a game from the monitored games list
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    $config = Get-SteamLibraryUpdaterConfig
    
    $config.MonitoredGames = @($config.MonitoredGames | Where-Object { $_.AppId -ne $AppId })
    
    $result = Set-SteamLibraryUpdaterConfig -Config $config
    if ($result) {
        Write-Log "Removed game with AppId: $AppId" -Level Info
    }
    
    return $result
}

# Export module functions
Export-ModuleMember -Function @(
    'Get-SteamLibraryUpdaterConfig',
    'Set-SteamLibraryUpdaterConfig',
    'Test-SteamRunning',
    'Test-GameRunning',
    'Test-GameNeedsUpdate',
    'Update-SteamGame',
    'Start-SteamLibraryUpdate',
    'Add-MonitoredGame',
    'Remove-MonitoredGame'
)
