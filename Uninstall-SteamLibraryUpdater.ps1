#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Uninstalls Steam Library Updater
.DESCRIPTION
    Removes Steam Library Updater from the system, including scheduled tasks and registry entries.
.EXAMPLE
    .\Uninstall-SteamLibraryUpdater.ps1
#>

[CmdletBinding()]
param(
    [switch]$Silent
)

$InstallPath = Join-Path $env:ProgramFiles "SteamLibraryUpdater"
$TaskName = "SteamLibraryUpdater"
$UninstallGuid = "{B4C8A9E2-1234-5678-9ABC-DEF012345678}"

if (-not $Silent) {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Steam Library Updater - Uninstallation" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    if (-not $Silent) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}

# Confirm uninstallation
if (-not $Silent) {
    Write-Host "This will remove Steam Library Updater from your system." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Do you want to continue? (y/N)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Uninstallation cancelled." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 0
    }
    Write-Host ""
}

$errorOccurred = $false

# Remove scheduled task
if (-not $Silent) {
    Write-Host "[1/3] Removing scheduled task..." -ForegroundColor Yellow
}
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        if (-not $Silent) {
            Write-Host "  Scheduled task removed" -ForegroundColor Green
        }
    }
    else {
        if (-not $Silent) {
            Write-Host "  No scheduled task found" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "  Error removing scheduled task: $_" -ForegroundColor Red
    $errorOccurred = $true
}

# Remove Add/Remove Programs entry
if (-not $Silent) {
    Write-Host "[2/3] Removing Add/Remove Programs entry..." -ForegroundColor Yellow
}
try {
    $uninstallRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$UninstallGuid"
    if (Test-Path $uninstallRegPath) {
        Remove-Item -Path $uninstallRegPath -Recurse -Force
        if (-not $Silent) {
            Write-Host "  Registry entry removed" -ForegroundColor Green
        }
    }
    else {
        if (-not $Silent) {
            Write-Host "  No registry entry found" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "  Error removing registry entry: $_" -ForegroundColor Red
    $errorOccurred = $true
}

# Remove installation directory
if (-not $Silent) {
    Write-Host "[3/3] Removing installation files..." -ForegroundColor Yellow
}
try {
    if (Test-Path $InstallPath) {
        # Ask if user wants to keep logs and configuration
        $keepData = $false
        if (-not $Silent) {
            $response = Read-Host "Do you want to keep your logs and configuration? (y/N)"
            $keepData = $response -match '^[Yy]'
        }
        
        if ($keepData) {
            # Keep logs and config, remove everything else
            Get-ChildItem -Path $InstallPath -Exclude "Logs", "Config.json", "appinfo" | Remove-Item -Recurse -Force
            if (-not $Silent) {
                Write-Host "  Installation files removed (kept logs and configuration)" -ForegroundColor Green
                Write-Host "  Remaining files: $InstallPath" -ForegroundColor Cyan
            }
        }
        else {
            # Remove everything
            Remove-Item -Path $InstallPath -Recurse -Force
            if (-not $Silent) {
                Write-Host "  Installation directory removed" -ForegroundColor Green
            }
        }
    }
    else {
        if (-not $Silent) {
            Write-Host "  Installation directory not found" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "  Error removing installation files: $_" -ForegroundColor Red
    Write-Host "  You may need to manually delete: $InstallPath" -ForegroundColor Yellow
    $errorOccurred = $true
}

if (-not $Silent) {
    Write-Host ""
    if ($errorOccurred) {
        Write-Host "==================================================" -ForegroundColor Yellow
        Write-Host " Uninstallation completed with errors" -ForegroundColor Yellow
        Write-Host "==================================================" -ForegroundColor Yellow
    }
    else {
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host " Uninstallation Complete!" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Steam Library Updater has been removed from your system." -ForegroundColor White
    Write-Host ""
    Write-Host "Thank you for using Steam Library Updater!" -ForegroundColor Cyan
    Write-Host ""
    
    Read-Host "Press Enter to exit"
}

exit 0
