#Requires -Version 5.1

<#
.SYNOPSIS
    Steam Update Manager - Automated Steam game update management
.DESCRIPTION
    Monitors and updates Steam games automatically when Steam is running
#>

# Module configuration
$script:AppName = "Steam Update Manager"
$script:AppVersion = "2.0.1"
$script:ProductFolder = "Steam-Update-Manager"
$script:DataRoot = if ($env:ProgramData) {
    Join-Path $env:ProgramData $script:ProductFolder
}
else {
    $PSScriptRoot
}

$script:ModuleConfig = @{
    ConfigPath = Join-Path $script:DataRoot "Config.json"
    AppInfoPath = Join-Path $script:DataRoot "appinfo"
    SteamCmdPath = Join-Path $PSScriptRoot "steamcmd\steamcmd.exe"
    LogPath = Join-Path $script:DataRoot "Logs"
    DataRoot = $script:DataRoot
    InstallRoot = $PSScriptRoot
}

# Ensure directories exist
if (-not (Test-Path $script:ModuleConfig.AppInfoPath)) {
    New-Item -ItemType Directory -Path $script:ModuleConfig.AppInfoPath -Force | Out-Null
}

if (-not (Test-Path $script:ModuleConfig.LogPath)) {
    New-Item -ItemType Directory -Path $script:ModuleConfig.LogPath -Force | Out-Null
}

function Get-DefaultSteamUpdateManagerConfig {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        AppName = $script:AppName
        AppVersion = $script:AppVersion
        Theme = "Auto"
        StartWithWindows = $true
        ShowTaskbarIcon = $false
        DiagnosticLogging = $true
        MaxLogFileKB = 512
        MaxLogFiles = 8
        UpdateDuringGaming = $false
        CheckIntervalMinutes = 1
        EnableAutoUpdate = $true
        UpdateCondition = "WhenAvailable"
        SteamInstallPath = ""
        MonitoredGames = @()
        LastCheck = $null
        Advanced = [PSCustomObject]@{
            AutoMonitorInstalledGames = $true
            UpdateCheckProvider = "https://api.steamcmd.net/v1/info"
            ScheduledTaskPollMinutes = 1
            SteamCmdInstallPath = ""
        }
    }
}

function Add-MissingConfigValue {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [PSCustomObject]$Defaults
    )

    foreach ($property in $Defaults.PSObject.Properties) {
        if (-not $Config.PSObject.Properties[$property.Name]) {
            $Config | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
            continue
        }

        if ($property.Value -is [PSCustomObject] -and $Config.$($property.Name) -is [PSCustomObject]) {
            Add-MissingConfigValue -Config $Config.$($property.Name) -Defaults $property.Value
        }
    }
}

function Get-SteamUpdateManagerPaths {
    [CmdletBinding()]
    param()

    return [PSCustomObject]$script:ModuleConfig
}

function Get-SteamUpdateManagerVersion {
    [CmdletBinding()]
    param()

    return $script:AppVersion
}

function Invoke-LogRetention {
    param(
        [Parameter(Mandatory)]
        [string]$CurrentLogFile,

        [int]$MaxLogFileKB = 512,

        [int]$MaxLogFiles = 8
    )

    if ((Test-Path $CurrentLogFile) -and ((Get-Item $CurrentLogFile).Length -gt ($MaxLogFileKB * 1KB))) {
        $archiveName = "{0}.{1}.log" -f ([System.IO.Path]::GetFileNameWithoutExtension($CurrentLogFile)), (Get-Date -Format "yyyyMMddHHmmss")
        Rename-Item -Path $CurrentLogFile -NewName $archiveName -Force
    }

    Get-ChildItem -Path $script:ModuleConfig.LogPath -Filter "*.log" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $MaxLogFiles |
        Remove-Item -Force -ErrorAction SilentlyContinue
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
    
    $diagnosticLogging = $true
    $maxLogFileKB = 512
    $maxLogFiles = 8
    if (Test-Path $script:ModuleConfig.ConfigPath) {
        try {
            $logConfig = Get-Content $script:ModuleConfig.ConfigPath -Raw | ConvertFrom-Json
            if ($logConfig.PSObject.Properties['DiagnosticLogging']) {
                $diagnosticLogging = [bool]$logConfig.DiagnosticLogging
            }
            if ($logConfig.PSObject.Properties['MaxLogFileKB'] -and [int]$logConfig.MaxLogFileKB -gt 0) {
                $maxLogFileKB = [int]$logConfig.MaxLogFileKB
            }
            if ($logConfig.PSObject.Properties['MaxLogFiles'] -and [int]$logConfig.MaxLogFiles -gt 0) {
                $maxLogFiles = [int]$logConfig.MaxLogFiles
            }
        }
        catch {
            $diagnosticLogging = $true
        }
    }

    if ((-not $diagnosticLogging) -and $Level -ne 'Error') {
        return
    }

    if (-not (Test-Path $script:ModuleConfig.LogPath)) {
        New-Item -ItemType Directory -Path $script:ModuleConfig.LogPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $script:ModuleConfig.LogPath "SteamUpdateManager_$(Get-Date -Format 'yyyyMMdd').log"
    $logMessage = "[$timestamp] [$Level] $Message"

    Invoke-LogRetention -CurrentLogFile $logFile -MaxLogFileKB $maxLogFileKB -MaxLogFiles $maxLogFiles
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
    
    $defaults = Get-DefaultSteamUpdateManagerConfig

    if (Test-Path $script:ModuleConfig.ConfigPath) {
        try {
            $config = Get-Content $script:ModuleConfig.ConfigPath -Raw | ConvertFrom-Json
            Add-MissingConfigValue -Config $config -Defaults $defaults
            return $config
        }
        catch {
            Write-Log "Error reading config file: $_" -Level Error
        }
    }
    
    # Return default configuration
    return $defaults
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
        if (-not (Test-Path $script:DataRoot)) {
            New-Item -ItemType Directory -Path $script:DataRoot -Force | Out-Null
        }
        $Config.AppName = $script:AppName
        $Config.AppVersion = $script:AppVersion
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
    
    $config = Get-SteamLibraryUpdaterConfig
    $provider = "https://api.steamcmd.net/v1/info"
    if ($config.Advanced -and $config.Advanced.UpdateCheckProvider) {
        $provider = $config.Advanced.UpdateCheckProvider.TrimEnd("/")
    }
    $uri = "$provider/$AppId"
    $maxAttempts = 4
    $delay = 1
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 30
            return $response
        }
        catch {
            if ($attempt -lt $maxAttempts) {
                $errorMsg = $_.ToString()
                Write-Log "Attempt $attempt failed to get app info for ${AppId}: $errorMsg - Retrying in $delay second(s)..." -Level Warning
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
    
    $config = Get-SteamLibraryUpdaterConfig
    $steamCmdPath = $script:ModuleConfig.SteamCmdPath
    if ($config.Advanced -and $config.Advanced.SteamCmdInstallPath) {
        $steamCmdPath = $config.Advanced.SteamCmdInstallPath
    }

    if (-not (Test-Path $steamCmdPath)) {
        Write-Log "SteamCMD not found at: $steamCmdPath" -Level Error
        return $false
    }
    
    if (-not (Test-Path $InstallDir)) {
        Write-Log "Install directory not found: $InstallDir" -Level Error
        return $false
    }
    
    try {
        Write-Log "Starting update for App $AppId to $InstallDir" -Level Info
        
        # Windows PowerShell 5.1 can still split Start-Process argument arrays
        # in surprising ways. Quote the install path explicitly so SteamCMD
        # never interprets "C:\Program Files\..." as "C:\program".
        $escapedInstallDir = $InstallDir -replace '"', '\"'
        $argumentLine = "+force_install_dir `"$escapedInstallDir`" +login anonymous +app_update $AppId validate +quit"
        $process = Start-Process -FilePath $steamCmdPath -ArgumentList $argumentLine -Wait -PassThru -NoNewWindow
        
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
    param(
        [switch]$Force
    )
    
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

    if ((-not $Force) -and $config.PSObject.Properties['UpdateCondition'] -and $config.UpdateCondition -ne "WhenAvailable") {
        Write-Log "Automatic updates are not configured to run when available" -Level Info
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
                            Where-Object { $_.Name -notmatch '\b(unins|crash|setup|installer|launcher)\b' } |
                            Sort-Object Length -Descending |
                            Select-Object -First 3
                        
                        $processName = $null
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

function Get-AcfValue {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $escapedName = [regex]::Escape($Name)
    $match = [regex]::Match($Content, '"' + $escapedName + '"\s+"([^"]*)"')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Set-AcfValue {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $escapedName = [regex]::Escape($Name)
    $pattern = '("' + $escapedName + '"\s+")([^"]*)(")'
    if ([regex]::IsMatch($Content, $pattern)) {
        return [regex]::Replace($Content, $pattern, '${1}' + $Value + '${3}', 1)
    }

    return $Content
}

function Start-SteamQueuedUpdates {
    <#
    .SYNOPSIS
        Nudges Steam's own queued client updates to run when available.
    .DESCRIPTION
        SteamCMD is not reliable for normal owned client games without account
        credentials. This function updates Steam appmanifest scheduling metadata
        so queued updates are eligible immediately, then opens Steam's Downloads
        view to let the Steam client process the queue.
    #>
    [CmdletBinding()]
    param()

    $config = Get-SteamLibraryUpdaterConfig

    if (-not $config.EnableAutoUpdate) {
        Write-Log "Run with Steam is disabled; queued update nudge skipped" -Level Info
        return [PSCustomObject]@{
            Changed = 0
            Queued = 0
            Message = "Run with Steam is disabled"
        }
    }

    if ($config.PSObject.Properties['UpdateCondition'] -and $config.UpdateCondition -ne "WhenAvailable") {
        Write-Log "Update condition is $($config.UpdateCondition); queued update nudge skipped" -Level Info
        return [PSCustomObject]@{
            Changed = 0
            Queued = 0
            Message = "Update condition is not WhenAvailable"
        }
    }

    if ((Test-GameRunning) -and -not $config.UpdateDuringGaming) {
        Write-Log "Game is running and Allow updates while gaming is false; queued update nudge skipped" -Level Info
        return [PSCustomObject]@{
            Changed = 0
            Queued = 0
            Message = "Gaming detected"
        }
    }

    $steamPath = $config.SteamInstallPath
    if (-not $steamPath) {
        $steamPath = Find-SteamInstallPath
    }

    if (-not $steamPath) {
        Write-Log "Steam installation was not found; queued update nudge skipped" -Level Warning
        return [PSCustomObject]@{
            Changed = 0
            Queued = 0
            Message = "Steam not found"
        }
    }

    $libraries = Get-SteamLibraryFolders -SteamPath $steamPath
    $manifestFiles = foreach ($library in $libraries) {
        Get-ChildItem -Path $library -Filter "appmanifest_*.acf" -File -ErrorAction SilentlyContinue
    }

    $changed = 0
    $queued = 0

    foreach ($manifest in $manifestFiles) {
        try {
            $content = Get-Content -LiteralPath $manifest.FullName -Raw
            $appid = Get-AcfValue -Content $content -Name "appid"
            $name = Get-AcfValue -Content $content -Name "name"
            $bytesToDownload = [int64]((Get-AcfValue -Content $content -Name "BytesToDownload") -as [int64])
            $scheduledAutoUpdate = [int64]((Get-AcfValue -Content $content -Name "ScheduledAutoUpdate") -as [int64])

            if ($bytesToDownload -le 0 -and $scheduledAutoUpdate -le 0) {
                continue
            }

            $queued++
            $updatedContent = $content
            if ($scheduledAutoUpdate -ne 0) {
                $updatedContent = Set-AcfValue -Content $updatedContent -Name "ScheduledAutoUpdate" -Value "0"
            }

            if ($updatedContent -ne $content) {
                Set-Content -LiteralPath $manifest.FullName -Value $updatedContent -NoNewline -Force
                $changed++
                Write-Log "Queued Steam update made eligible now: $name (AppId: $appid)" -Level Info
            }
        }
        catch {
            Write-Log "Unable to process Steam manifest $($manifest.FullName): $_" -Level Warning
        }
    }

    $steamExe = Join-Path $steamPath "steam.exe"
    if (Test-Path $steamExe) {
        Start-Process -FilePath $steamExe -ArgumentList "steam://open/downloads" -WindowStyle Minimized -ErrorAction SilentlyContinue | Out-Null
    }

    $config.LastCheck = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-SteamLibraryUpdaterConfig -Config $config | Out-Null
    Write-Log "Steam queued update nudge completed. Queued manifests: $queued. Changed schedules: $changed." -Level Info

    return [PSCustomObject]@{
        Changed = $changed
        Queued = $queued
        Message = "Queued update nudge completed"
    }
}

function Find-AppIdByName {
    <#
    .SYNOPSIS
        Searches for a Steam App ID by game name using the Steam Web API
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GameName
    )
    
    # Validate input to prevent malicious content
    if ($GameName.Length -gt 200) {
        Write-Log "Game name too long (max 200 characters)" -Level Warning
        return $null
    }
    
    try {
        # Use Steam store search API with proper URL encoding
        $encodedName = [uri]::EscapeDataString($GameName)
        $searchUrl = "https://store.steampowered.com/api/storesearch/?term=$encodedName&cc=US&l=english"
        
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -TimeoutSec 30 -ErrorAction Stop
        
        # Validate response structure
        if ($null -eq $response) {
            Write-Log "Received null response from Steam API" -Level Warning
            return $null
        }
        
        if ($response.PSObject.Properties['total'] -and $response.total -gt 0 -and 
            $response.PSObject.Properties['items'] -and $response.items) {
            # Return the first result as it's usually the most relevant
            $topResult = $response.items[0]
            
            # Validate required properties exist
            if ($topResult.PSObject.Properties['id'] -and $topResult.PSObject.Properties['name']) {
                return [PSCustomObject]@{
                    AppId = $topResult.id
                    Name = $topResult.name
                    Type = if ($topResult.PSObject.Properties['type']) { $topResult.type } else { "unknown" }
                }
            }
        }
        
        Write-Log "No valid results found for game '$GameName'" -Level Info
    }
    catch {
        Write-Log "Error searching for game '$GameName': $_" -Level Warning
    }
    
    return $null
}

# Export module functions
Export-ModuleMember -Function @(
    'Write-Log',
    'Get-SteamLibraryUpdaterConfig',
    'Set-SteamLibraryUpdaterConfig',
    'Get-SteamUpdateManagerPaths',
    'Get-SteamUpdateManagerVersion',
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
    'Start-SteamQueuedUpdates',
    'Find-AppIdByName'
)
