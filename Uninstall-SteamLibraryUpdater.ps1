#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Uninstalls Steam Update Manager.
.DESCRIPTION
    Removes the scheduled task, startup entry, Apps & Features registration,
    installed scripts, and optionally ProgramData configuration/logs.
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$KeepData
)

$ProductName = "Steam Update Manager"
$ProductFolder = "Steam-Update-Manager"
$InstallPath = Join-Path $env:ProgramFiles $ProductFolder
$DataPath = Join-Path $env:ProgramData $ProductFolder
$TaskName = "SteamUpdateManager"
$LegacyTaskName = "SteamLibraryUpdater"
$RunValueName = "Steam Update Manager"
$UninstallGuid = "{B4C8A9E2-1234-5678-9ABC-DEF012345678}"
$StartMenuShortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Steam Update Manager.lnk"
$DesktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Steam Update Manager.lnk"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-ProgressLine {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Silent) {
        Write-Host $Message -ForegroundColor Yellow
    }
}

if (-not $Silent) {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " $ProductName - Uninstallation" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    if (-not $Silent) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}

if (-not $Silent) {
    Write-Host "This will remove $ProductName from your system." -ForegroundColor Yellow
    $confirm = Read-Host "Do you want to continue? (y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 0
    }

    if (-not $KeepData) {
        $response = Read-Host "Keep configuration, logs, and appinfo cache? (y/N)"
        $KeepData = $response -match '^[Yy]'
    }
}

$errorOccurred = $false

Write-ProgressLine "[1/5] Removing scheduled task..."
try {
    foreach ($taskToRemove in @($TaskName, $LegacyTaskName)) {
        $task = Get-ScheduledTask -TaskName $taskToRemove -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $taskToRemove -Confirm:$false
            if (-not $Silent) { Write-Host "  Scheduled task removed: $taskToRemove" -ForegroundColor Green }
        }
    }
}
catch {
    Write-Host "  Error removing scheduled task: $_" -ForegroundColor Red
    $errorOccurred = $true
}

Write-ProgressLine "[2/5] Removing Start with Windows entry..."
try {
    $runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    Remove-ItemProperty -Path $runPath -Name $RunValueName -ErrorAction SilentlyContinue
    if (-not $Silent) { Write-Host "  Startup entry removed if present" -ForegroundColor Green }
}
catch {
    Write-Host "  Error removing startup entry: $_" -ForegroundColor Red
    $errorOccurred = $true
}

Write-ProgressLine "[3/5] Removing shortcuts and Apps & Features entry..."
try {
    foreach ($shortcutPath in @($StartMenuShortcutPath, $DesktopShortcutPath)) {
        if (Test-Path $shortcutPath) {
            Remove-Item -LiteralPath $shortcutPath -Force
            if (-not $Silent) { Write-Host "  Shortcut removed: $shortcutPath" -ForegroundColor Green }
        }
    }
}
catch {
    Write-Host "  Error removing shortcuts: $_" -ForegroundColor Red
    $errorOccurred = $true
}

try {
    $uninstallRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallGuid"
    if (Test-Path $uninstallRegPath) {
        Remove-Item -Path $uninstallRegPath -Recurse -Force
        if (-not $Silent) { Write-Host "  Registry entry removed" -ForegroundColor Green }
    }
}
catch {
    Write-Host "  Error removing registry entry: $_" -ForegroundColor Red
    $errorOccurred = $true
}

Write-ProgressLine "[4/5] Removing installation files..."
try {
    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force
        if (-not $Silent) { Write-Host "  Installation folder removed" -ForegroundColor Green }
    }
}
catch {
    Write-Host "  Error removing installation folder: $_" -ForegroundColor Red
    Write-Host "  You may need to manually delete: $InstallPath" -ForegroundColor Yellow
    $errorOccurred = $true
}

Write-ProgressLine "[5/5] Handling application data..."
try {
    if ((Test-Path $DataPath) -and -not $KeepData) {
        Remove-Item -Path $DataPath -Recurse -Force
        if (-not $Silent) { Write-Host "  Data folder removed" -ForegroundColor Green }
    }
    elseif ((Test-Path $DataPath) -and $KeepData) {
        if (-not $Silent) { Write-Host "  Data folder kept: $DataPath" -ForegroundColor Cyan }
    }
}
catch {
    Write-Host "  Error handling data folder: $_" -ForegroundColor Red
    $errorOccurred = $true
}

if (-not $Silent) {
    Write-Host ""
    if ($errorOccurred) {
        Write-Host "Uninstallation completed with errors." -ForegroundColor Yellow
    }
    else {
        Write-Host "Uninstallation complete." -ForegroundColor Green
    }
    Write-Host ""
    Read-Host "Press Enter to exit"
}

if ($errorOccurred) {
    exit 1
}

exit 0
