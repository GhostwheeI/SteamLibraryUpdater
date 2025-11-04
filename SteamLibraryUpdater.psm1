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
    
    $uri = "https://api.steamcmd.net/v1/info/$AppId"
    $maxAttempts = 4
    $delay = 1
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 30
            return $response
        }
        catch {
            if ($attempt -lt $maxAttempts) {
                $errorMsg = $_
                Write-Log "Attempt $attempt failed to get app info for $AppId : $errorMsg. Retrying in $delay second(s)..." -Level Warning
                Start-Sleep -Seconds $delay
                $delay = [Math]::Min($delay * 2, 8)
            }
            else {
                Write-Log "Error getting app info for $AppId after $maxAttempts attempts: $_" -Level Error
                return $null
            }
        }
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
        
        # Use array-based arguments to avoid shell interpretation issues
        $arguments = @(
            "+force_install_dir"
            $InstallDir
            "+login"
            "anonymous"
            "+app_update"
            $AppId
            "validate"
            "+quit"
        )
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
            
            # Clean up the -new file on failure to prevent false positives
            $appInfoFile = Join-Path $script:ModuleConfig.AppInfoPath $AppId
            $appInfoFileNew = "$appInfoFile-new"
            if (Test-Path $appInfoFileNew) {
                Remove-Item $appInfoFileNew -Force -ErrorAction SilentlyContinue
            }
            
            return $false
        }
    }
    catch {
        Write-Log "Error updating game: $_" -Level Error
        
        # Clean up the -new file on failure to prevent false positives
        $appInfoFile = Join-Path $script:ModuleConfig.AppInfoPath $AppId
        $appInfoFileNew = "$appInfoFile-new"
        if (Test-Path $appInfoFileNew) {
            Remove-Item $appInfoFileNew -Force -ErrorAction SilentlyContinue
        }
        
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

function Find-SteamInstallPath {
    <#
    .SYNOPSIS
        Automatically detects the Steam installation path
    #>
    [CmdletBinding()]
    param()
    
    # Check registry for Steam installation path
    $registryPaths = @(
        "HKCU:\Software\Valve\Steam",
        "HKLM:\Software\Valve\Steam",
        "HKLM:\Software\Wow6432Node\Valve\Steam"
    )
    
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            $steamPath = (Get-ItemProperty -Path $regPath -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
            if ($steamPath -and (Test-Path $steamPath)) {
                Write-Log "Found Steam installation at: $steamPath" -Level Info
                return $steamPath
            }
        }
    }
    
    # Check common installation locations
    $commonPaths = @(
        "C:\Program Files (x86)\Steam",
        "C:\Program Files\Steam",
        "$env:ProgramFiles\Steam",
        "${env:ProgramFiles(x86)}\Steam"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $steamExe = Join-Path $path "steam.exe"
            if (Test-Path $steamExe) {
                Write-Log "Found Steam installation at: $path" -Level Info
                return $path
            }
        }
    }
    
    Write-Log "Could not automatically detect Steam installation" -Level Warning
    return $null
}

function Get-SteamLibraryFolders {
    <#
    .SYNOPSIS
        Gets all Steam library folders from the Steam configuration
    #>
    [CmdletBinding()]
    param(
        [string]$SteamPath
    )
    
    if (-not $SteamPath) {
        $SteamPath = Find-SteamInstallPath
        if (-not $SteamPath) {
            return @()
        }
    }
    
    $libraryFolders = @()
    
    # Add the default Steam library
    $defaultLibrary = Join-Path $SteamPath "steamapps"
    if (Test-Path $defaultLibrary) {
        $libraryFolders += $defaultLibrary
    }
    
    # Read libraryfolders.vdf to find additional libraries
    $libraryVdf = Join-Path $SteamPath "steamapps\libraryfolders.vdf"
    if (Test-Path $libraryVdf) {
        try {
            $content = Get-Content $libraryVdf -Raw
            
            # Parse VDF format - look for paths
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($match in $matches) {
                $libPath = $match.Groups[1].Value
                # VDF uses escaped backslashes - convert double backslashes to single
                $libPath = $libPath.Replace('\\', '\')
                
                $steamappsPath = Join-Path $libPath "steamapps"
                if ((Test-Path $steamappsPath) -and ($libraryFolders -notcontains $steamappsPath)) {
                    $libraryFolders += $steamappsPath
                }
            }
        }
        catch {
            Write-Log "Error parsing libraryfolders.vdf: $_" -Level Warning
        }
    }
    
    return $libraryFolders
}

function Get-InstalledSteamGames {
    <#
    .SYNOPSIS
        Scans Steam libraries and returns information about installed games
    #>
    [CmdletBinding()]
    param(
        [string]$SteamPath
    )
    
    if (-not $SteamPath) {
        $SteamPath = Find-SteamInstallPath
        if (-not $SteamPath) {
            Write-Log "Could not find Steam installation" -Level Warning
            return @()
        }
    }
    
    $libraries = Get-SteamLibraryFolders -SteamPath $SteamPath
    $games = @()
    
    foreach ($library in $libraries) {
        # Look for .acf manifest files
        $manifestFiles = Get-ChildItem -Path $library -Filter "appmanifest_*.acf" -File -ErrorAction SilentlyContinue
        
        foreach ($manifest in $manifestFiles) {
            try {
                $content = Get-Content $manifest.FullName -Raw
                
                # Parse basic ACF format
                $appId = if ($content -match '"appid"\s+"(\d+)"') { $matches[1] } else { $null }
                $name = if ($content -match '"name"\s+"([^"]+)"') { $matches[1] } else { $null }
                $installDir = if ($content -match '"installdir"\s+"([^"]+)"') { $matches[1] } else { $null }
                
                if ($appId -and $name -and $installDir) {
                    $fullInstallPath = Join-Path $library "common\$installDir"
                    
                    if (Test-Path $fullInstallPath) {
                        # Try to find the main executable
                        $exeFiles = Get-ChildItem -Path $fullInstallPath -Filter "*.exe" -File -ErrorAction SilentlyContinue |
                            Where-Object { $_.Name -notmatch '(unins|crash|setup|installer|launcher)' } |
                            Sort-Object Length -Descending |
                            Select-Object -First 3
                        
                        $processName = ""
                        if ($exeFiles) {
                            # Use the first (largest) exe as a guess for the process name
                            $processName = [System.IO.Path]::GetFileNameWithoutExtension($exeFiles[0].Name)
                        }
                        
                        $games += [PSCustomObject]@{
                            AppId = $appId
                            Name = $name
                            InstallDir = $fullInstallPath
                            ProcessName = $processName
                            Library = $library
                        }
                    }
                }
            }
            catch {
                Write-Log "Error parsing manifest $($manifest.Name): $_" -Level Warning
            }
        }
    }
    
    return $games
}

function Find-AppIdByName {
    <#
    .SYNOPSIS
        Searches for a Steam App ID by game name using the Steam Web API
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GameName
    )
    
    try {
        # Use Steam store search API
        $searchUrl = "https://store.steampowered.com/api/storesearch/?term=$([uri]::EscapeDataString($GameName))&cc=US&l=english"
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 30
        
        if ($response.total -gt 0 -and $response.items) {
            # Return the first result as it's usually the most relevant
            $topResult = $response.items[0]
            return [PSCustomObject]@{
                AppId = $topResult.id
                Name = $topResult.name
                Type = $topResult.type
            }
        }
    }
    catch {
        Write-Log "Error searching for game '$GameName': $_" -Level Warning
    }
    
    return $null
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
    'Remove-MonitoredGame',
    'Find-SteamInstallPath',
    'Get-SteamLibraryFolders',
    'Get-InstalledSteamGames',
    'Find-AppIdByName'
)
