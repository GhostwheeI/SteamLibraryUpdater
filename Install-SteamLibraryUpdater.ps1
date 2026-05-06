#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs Steam Update Manager.
.DESCRIPTION
    Installs the PowerShell module, tray app, scheduled update task, SteamCMD,
    ProgramData-backed configuration, and Apps & Features registration.
#>

[CmdletBinding()]
param(
    [switch]$SkipSteamCmdDownload,
    [switch]$DoNotLaunchTray
)

$ProductName = "Steam Update Manager"
$ProductFolder = "Steam-Update-Manager"
$Version = "2.0.0"
$Publisher = "GhostwheeI"
$InstallPath = Join-Path $env:ProgramFiles $ProductFolder
$DataPath = Join-Path $env:ProgramData $ProductFolder
$TaskName = "SteamUpdateManager"
$LegacyTaskName = "SteamLibraryUpdater"
$UninstallGuid = "{B4C8A9E2-1234-5678-9ABC-DEF012345678}"
$StartMenuShortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Steam Update Manager.lnk"
$DesktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Steam Update Manager.lnk"

function Write-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Yellow
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsPowerShellPath {
    $windowsPowerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $windowsPowerShell) {
        return $windowsPowerShell
    }

    return "powershell.exe"
}

function Grant-DataFolderAccess {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $users = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $users,
            "Modify",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $acl = Get-Acl -Path $Path
        $acl.SetAccessRule($rule)
        Set-Acl -Path $Path -AclObject $acl
    }
    catch {
        Write-Host "  Warning: could not adjust ProgramData permissions: $_" -ForegroundColor Yellow
    }
}

function Install-SteamCmd {
    $steamCmdPath = Join-Path $InstallPath "steamcmd\steamcmd.exe"
    if (Test-Path $steamCmdPath) {
        Write-Host "  SteamCMD found" -ForegroundColor Green
        return
    }

    if ($SkipSteamCmdDownload) {
        Write-Host "  SteamCMD download skipped" -ForegroundColor Yellow
        return
    }

    $steamCmdDir = Join-Path $InstallPath "steamcmd"
    $steamCmdZip = Join-Path $env:TEMP "steamcmd.zip"
    $steamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"

    try {
        if (-not (Test-Path $steamCmdDir)) {
            New-Item -ItemType Directory -Path $steamCmdDir -Force | Out-Null
        }

        Write-Host "  Downloading SteamCMD from Valve..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $steamCmdUrl -OutFile $steamCmdZip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $steamCmdZip -DestinationPath $steamCmdDir -Force
        Remove-Item $steamCmdZip -Force -ErrorAction SilentlyContinue

        if (Test-Path $steamCmdPath) {
            Write-Host "  SteamCMD installed" -ForegroundColor Green
            $process = Start-Process -FilePath $steamCmdPath -ArgumentList "+quit" -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 7) {
                Write-Host "  Warning: SteamCMD initialization returned exit code $($process.ExitCode)" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "  Error downloading SteamCMD: $_" -ForegroundColor Red
        Write-Host "  Manual source: $steamCmdUrl" -ForegroundColor Cyan
        Write-Host "  Extract it to: $steamCmdDir" -ForegroundColor Cyan
    }
}

function New-AppShortcut {
    param(
        [Parameter(Mandatory)]
        [string]$ShortcutPath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [Parameter(Mandatory)]
        [string]$Arguments,

        [Parameter(Mandatory)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $shortcutDirectory = Split-Path -Path $ShortcutPath -Parent
    if (-not (Test-Path $shortcutDirectory)) {
        New-Item -ItemType Directory -Path $shortcutDirectory -Force | Out-Null
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    $iconPath = Join-Path $WorkingDirectory "AppIconTransparent.ico"
    if (Test-Path $iconPath) {
        $shortcut.IconLocation = $iconPath
    }
    else {
        $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,13"
    }
    $shortcut.Save()
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " $ProductName - Installation" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Step "[1/7] Creating installation and data directories..."
New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
New-Item -ItemType Directory -Path $DataPath -Force | Out-Null
foreach ($dir in @("appinfo", "Logs")) {
    New-Item -ItemType Directory -Path (Join-Path $DataPath $dir) -Force | Out-Null
}
Grant-DataFolderAccess -Path $DataPath

Write-Step "[2/7] Copying application files..."
$sourceFiles = @(
    "SteamLibraryUpdater.psm1",
    "Steam-Update-Manager.ps1",
    "AppIcon.ico",
    "AppIcon.png",
    "AppIconTransparent.ico",
    "AppIconTransparent.png",
    "icon.png",
    "Install-SteamLibraryUpdater.ps1",
    "Configure-SteamLibraryUpdater.ps1",
    "Uninstall-SteamLibraryUpdater.ps1",
    "README.md",
    "CHANGELOG.md",
    "LICENSE"
)

foreach ($file in $sourceFiles) {
    $sourcePath = Join-Path $PSScriptRoot $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $InstallPath -Force
        Write-Host "  Copied: $file" -ForegroundColor Green
    }
    else {
        Write-Host "  Warning: missing source file $file" -ForegroundColor Yellow
    }
}

Write-Step "[3/7] Creating default configuration..."
$modulePath = Join-Path $InstallPath "SteamLibraryUpdater.psm1"
Import-Module $modulePath -Force
$config = Get-SteamLibraryUpdaterConfig
$config.AppName = $ProductName
$config.AppVersion = $Version
$config.StartWithWindows = $true
$config.CheckIntervalMinutes = 1
if (-not $config.SteamInstallPath) {
    $steamPath = Find-SteamInstallPath
    if ($steamPath) {
        $config.SteamInstallPath = $steamPath
    }
}
$config.Advanced.SteamCmdInstallPath = Join-Path $InstallPath "steamcmd\steamcmd.exe"
$config.Advanced.ScheduledTaskPollMinutes = 1
Set-SteamLibraryUpdaterConfig -Config $config | Out-Null

$runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$runCommand = "`"$(Get-WindowsPowerShellPath)`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$InstallPath\Steam-Update-Manager.ps1`""
New-Item -Path $runPath -Force | Out-Null
Set-ItemProperty -Path $runPath -Name $ProductName -Value $runCommand -Type String

Write-Step "[4/7] Auto-detecting installed Steam games..."
try {
    $installedGames = Get-InstalledSteamGames -SteamPath $config.SteamInstallPath
    $existingAppIds = @($config.MonitoredGames | ForEach-Object { $_.AppId })
    $addedCount = 0

    foreach ($game in $installedGames) {
        if ($existingAppIds -contains $game.AppId) {
            continue
        }

        if (Add-MonitoredGame -AppId $game.AppId -Name $game.Name -InstallDir $game.InstallDir -ProcessName $game.ProcessName) {
            $addedCount++
        }
    }

    Write-Host "  Added $addedCount installed game(s) to monitoring" -ForegroundColor Green
}
catch {
    Write-Host "  Warning: game auto-detection failed: $_" -ForegroundColor Yellow
}

Write-Step "[5/7] Installing SteamCMD..."
Install-SteamCmd

Write-Step "[6/7] Creating scheduled update task..."
$taskScriptPath = Join-Path $InstallPath "RunUpdater.ps1"
$taskScriptContent = @"
# Steam Update Manager - Scheduled update task
Set-Location '$InstallPath'
Import-Module '.\SteamLibraryUpdater.psm1' -Force

try {
    Write-Log 'Scheduled task started' -Level Info

    `$steamRunning = Get-Process -Name 'steam' -ErrorAction SilentlyContinue
    if (`$null -eq `$steamRunning) {
        Write-Log 'Steam is not running; scheduled task exiting' -Level Info
        exit 0
    }

    `$config = Get-SteamLibraryUpdaterConfig
    if (-not `$config.EnableAutoUpdate) {
        Write-Log 'Run with Steam is disabled; scheduled task exiting' -Level Info
        exit 0
    }

    `$intervalMinutes = 1
    if (`$config.CheckIntervalMinutes -and [int]`$config.CheckIntervalMinutes -gt 0) {
        `$intervalMinutes = [int]`$config.CheckIntervalMinutes
    }

    `$lastCheck = `$null
    if (`$config.LastCheck) {
        `$parsedLastCheck = [datetime]::MinValue
        if ([datetime]::TryParse([string]`$config.LastCheck, [ref]`$parsedLastCheck)) {
            `$lastCheck = `$parsedLastCheck
        }
    }

    if (`$lastCheck) {
        `$elapsed = (Get-Date) - `$lastCheck
        if (`$elapsed.TotalMinutes -lt `$intervalMinutes) {
            Write-Log "Scheduled task exiting; only `$([math]::Round(`$elapsed.TotalSeconds)) second(s) since last check" -Level Info
            exit 0
        }
    }

    Start-SteamQueuedUpdates | Out-Null
    Write-Log 'Scheduled task completed' -Level Info
    exit 0
}
catch {
    Write-Log "Scheduled task error: `$_" -Level Error
    exit 0
}
"@
Set-Content -Path $taskScriptPath -Value $taskScriptContent -Force

foreach ($taskToRemove in @($TaskName, $LegacyTaskName)) {
    $existingTask = Get-ScheduledTask -TaskName $taskToRemove -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $taskToRemove -Confirm:$false
    }
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$taskScriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType Service -RunLevel Highest
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Runs Steam Update Manager checks when Steam is available." -Force | Out-Null
Write-Host "  Scheduled task created: $TaskName" -ForegroundColor Green

Write-Step "[7/7] Registering Apps & Features entry..."
$uninstallRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallGuid"
New-Item -Path $uninstallRegPath -Force | Out-Null
$uninstallScript = Join-Path $InstallPath "Uninstall-SteamLibraryUpdater.ps1"
$trayScript = Join-Path $InstallPath "Steam-Update-Manager.ps1"
$displayIconPath = Join-Path $InstallPath "AppIconTransparent.ico"
$size = (Get-ChildItem -Path $InstallPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1KB

Set-ItemProperty -Path $uninstallRegPath -Name "DisplayName" -Value $ProductName -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "DisplayVersion" -Value $Version -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "Publisher" -Value $Publisher -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "InstallLocation" -Value $InstallPath -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "UninstallString" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$uninstallScript`"" -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "QuietUninstallString" -Value "powershell.exe -ExecutionPolicy Bypass -File `"$uninstallScript`" -Silent" -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "DisplayIcon" -Value $displayIconPath -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "NoModify" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallRegPath -Name "NoRepair" -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallRegPath -Name "InstallDate" -Value (Get-Date -Format "yyyyMMdd") -Type String
Set-ItemProperty -Path $uninstallRegPath -Name "EstimatedSize" -Value ([math]::Round($size)) -Type DWord
Write-Host "  Apps & Features entry registered" -ForegroundColor Green

Write-Step "Creating Start menu and desktop shortcuts..."
$powerShellPath = Get-WindowsPowerShellPath
$shortcutArguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$trayScript`" -ShowMenuOnStart"
New-AppShortcut -ShortcutPath $StartMenuShortcutPath -TargetPath $powerShellPath -Arguments $shortcutArguments -WorkingDirectory $InstallPath -Description $ProductName
New-AppShortcut -ShortcutPath $DesktopShortcutPath -TargetPath $powerShellPath -Arguments $shortcutArguments -WorkingDirectory $InstallPath -Description "$ProductName tray menu"
Write-Host "  Start menu shortcut: $StartMenuShortcutPath" -ForegroundColor Green
Write-Host "  Desktop shortcut: $DesktopShortcutPath" -ForegroundColor Green

if (-not $DoNotLaunchTray) {
    Start-Process -FilePath (Get-WindowsPowerShellPath) -WindowStyle Hidden -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-STA",
        "-File", "`"$trayScript`"",
        "-ShowMenuOnStart"
    ) | Out-Null
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host " Installation Complete" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Installed to: $InstallPath" -ForegroundColor Cyan
Write-Host "Data folder:  $DataPath" -ForegroundColor Cyan
Write-Host "Tray app:     $trayScript" -ForegroundColor Cyan
Write-Host ""
Write-Host "Use the Desktop or Start menu shortcut to show the tray menu when the taskbar icon is hidden." -ForegroundColor White
