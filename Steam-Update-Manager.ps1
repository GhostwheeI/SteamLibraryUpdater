#Requires -Version 5.1

<#
.SYNOPSIS
    Steam Update Manager tray host.
.DESCRIPTION
    Provides the right-click taskbar menu and user settings surface while the
    PowerShell module keeps the existing Steam update behavior available.
#>

[CmdletBinding()]
param(
    [switch]$ShowMenuOnStart
)

$script:AppName = "Steam Update Manager"
$script:ModulePath = Join-Path $PSScriptRoot "SteamLibraryUpdater.psm1"
$script:RunValueName = "Steam Update Manager"
$script:IconPath = Join-Path $PSScriptRoot "AppIconTransparent.ico"
$script:PngIconPath = Join-Path $PSScriptRoot "AppIconTransparent.png"
$script:IconBitmap = $null

function Get-WindowsPowerShellPath {
    $windowsPowerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $windowsPowerShell) {
        return $windowsPowerShell
    }

    return "powershell.exe"
}

if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
    $powerShellExe = Get-WindowsPowerShellPath
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-WindowStyle", "Hidden",
        "-STA",
        "-File", "`"$PSCommandPath`""
    )
    if ($ShowMenuOnStart) {
        $arguments += "-ShowMenuOnStart"
    }

    Start-Process -FilePath $powerShellExe -WindowStyle Hidden -ArgumentList $arguments | Out-Null
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Import-Module $script:ModulePath -Force
$startupPaths = Get-SteamUpdateManagerPaths
if (-not (Test-Path $startupPaths.ConfigPath)) {
    Set-SteamLibraryUpdaterConfig -Config (Get-SteamLibraryUpdaterConfig) | Out-Null
}
$script:StartupConfig = Get-SteamLibraryUpdaterConfig
$script:TemporaryTrayIcon = $ShowMenuOnStart -and -not [bool]$script:StartupConfig.ShowTaskbarIcon

function Get-RunRegistryPath {
    return "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
}

function Get-SystemThemeName {
    $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $appsUseLightTheme = (Get-ItemProperty -Path $personalizePath -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue).AppsUseLightTheme

    if ($null -eq $appsUseLightTheme) {
        return "Light"
    }

    if ([int]$appsUseLightTheme -eq 0) {
        return "Dark"
    }

    return "Light"
}

function Resolve-AppTheme {
    param(
        [string]$Theme
    )

    if ([string]::IsNullOrWhiteSpace($Theme) -or $Theme -eq "Auto") {
        return Get-SystemThemeName
    }

    if ($Theme -eq "Dark") {
        return "Dark"
    }

    return "Light"
}

function Get-AppIcon {
    try {
        if (Test-Path $script:IconPath) {
            return New-Object System.Drawing.Icon($script:IconPath)
        }

        if (Test-Path $script:PngIconPath) {
            $script:IconBitmap = New-Object System.Drawing.Bitmap($script:PngIconPath)
            return [System.Drawing.Icon]::FromHandle($script:IconBitmap.GetHicon())
        }
    }
    catch {
        Write-Log "Failed to load app icon: $_" -Level Warning
    }

    return [System.Drawing.SystemIcons]::Application
}

function Set-ControlTheme {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Control]$Control,

        [Parameter(Mandatory)]
        [string]$ThemeName
    )

    if ($ThemeName -eq "Dark") {
        $Control.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
        $Control.ForeColor = [System.Drawing.Color]::WhiteSmoke
    }
    else {
        $Control.BackColor = [System.Drawing.SystemColors]::Control
        $Control.ForeColor = [System.Drawing.SystemColors]::ControlText
    }

    foreach ($child in $Control.Controls) {
        Set-ControlTheme -Control $child -ThemeName $ThemeName
    }
}

function Set-MenuTheme {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.ContextMenuStrip]$Menu,

        [Parameter(Mandatory)]
        [string]$ThemeName
    )

    if ($ThemeName -eq "Dark") {
        $backColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
        $foreColor = [System.Drawing.Color]::WhiteSmoke
    }
    else {
        $backColor = [System.Drawing.SystemColors]::Menu
        $foreColor = [System.Drawing.SystemColors]::MenuText
    }

    $Menu.BackColor = $backColor
    $Menu.ForeColor = $foreColor
    $Menu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System

    foreach ($item in $Menu.Items) {
        Set-MenuItemTheme -Item $item -BackColor $backColor -ForeColor $foreColor
    }
}

function Set-MenuItemTheme {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.ToolStripItem]$Item,

        [Parameter(Mandatory)]
        [System.Drawing.Color]$BackColor,

        [Parameter(Mandatory)]
        [System.Drawing.Color]$ForeColor
    )

    $Item.BackColor = $BackColor
    $Item.ForeColor = $ForeColor

    if ($Item -is [System.Windows.Forms.ToolStripMenuItem] -and $Item.DropDownItems.Count -gt 0) {
        $Item.DropDown.ShowImageMargin = $false
        $Item.DropDown.ShowCheckMargin = $false
        $Item.DropDown.BackColor = $BackColor
        $Item.DropDown.ForeColor = $ForeColor
        $Item.DropDown.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System
        foreach ($childItem in $Item.DropDownItems) {
            Set-MenuItemTheme -Item $childItem -BackColor $BackColor -ForeColor $ForeColor
        }
    }
}

function Test-StartWithWindows {
    $runPath = Get-RunRegistryPath
    $value = (Get-ItemProperty -Path $runPath -Name $script:RunValueName -ErrorAction SilentlyContinue).$($script:RunValueName)
    return -not [string]::IsNullOrWhiteSpace($value)
}

function Set-StartWithWindows {
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )

    $runPath = Get-RunRegistryPath
    $powerShellExe = Get-WindowsPowerShellPath
    if ($Enabled) {
        $command = "`"$powerShellExe`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$PSCommandPath`""
        New-Item -Path $runPath -Force | Out-Null
        Set-ItemProperty -Path $runPath -Name $script:RunValueName -Value $command -Type String
    }
    else {
        Remove-ItemProperty -Path $runPath -Name $script:RunValueName -ErrorAction SilentlyContinue
    }
}

function Get-StatusText {
    try {
        $config = Get-SteamLibraryUpdaterConfig
        if (-not $config.EnableAutoUpdate) {
            return "Paused"
        }

        if (-not (Test-SteamRunning)) {
            return "Waiting for Steam"
        }

        if ((Test-GameRunning) -and -not $config.UpdateDuringGaming) {
            return "Gaming detected, updates paused"
        }

        if ($config.LastCheck) {
            return "Ready, last check $($config.LastCheck)"
        }

        return "Ready"
    }
    catch {
        Write-Log "Unable to determine tray status: $_" -Level Error
        return "Needs attention"
    }
}

function Save-Config {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    if (-not (Set-SteamLibraryUpdaterConfig -Config $Config)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Steam Update Manager could not save Config.json. Check the log for details.",
            $script:AppName,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return $false
    }

    return $true
}

function Open-SettingsWindow {
    $config = Get-SteamLibraryUpdaterConfig

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$script:AppName Settings"
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(380, 250)
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.ShowInTaskbar = [bool]$config.ShowTaskbarIcon

    $themeName = Resolve-AppTheme -Theme $config.Theme

    $startupCheck = New-Object System.Windows.Forms.CheckBox
    $startupCheck.Text = "Start with Windows"
    $startupCheck.AutoSize = $true
    $startupCheck.Location = New-Object System.Drawing.Point(22, 24)
    $startupCheck.Checked = Test-StartWithWindows

    $loggingCheck = New-Object System.Windows.Forms.CheckBox
    $loggingCheck.Text = "Diagnostic logging"
    $loggingCheck.AutoSize = $true
    $loggingCheck.Location = New-Object System.Drawing.Point(22, 58)
    $loggingCheck.Checked = [bool]$config.DiagnosticLogging

    $taskbarCheck = New-Object System.Windows.Forms.CheckBox
    $taskbarCheck.Text = "Show Taskbar Icon"
    $taskbarCheck.AutoSize = $true
    $taskbarCheck.Location = New-Object System.Drawing.Point(22, 92)
    $taskbarCheck.Checked = [bool]$config.ShowTaskbarIcon

    $themeLabel = New-Object System.Windows.Forms.Label
    $themeLabel.Text = "Theme"
    $themeLabel.AutoSize = $true
    $themeLabel.Location = New-Object System.Drawing.Point(22, 132)

    $themeCombo = New-Object System.Windows.Forms.ComboBox
    $themeCombo.DropDownStyle = "DropDownList"
    $themeCombo.Items.AddRange(@("Auto", "Light", "Dark"))
    $themeCombo.Location = New-Object System.Drawing.Point(120, 128)
    $themeCombo.Width = 160
    if ($themeCombo.Items.Contains($config.Theme)) {
        $themeCombo.SelectedItem = $config.Theme
    }
    else {
        $themeCombo.SelectedItem = "Auto"
    }

    $logsButton = New-Object System.Windows.Forms.Button
    $logsButton.Text = "Open Logs Folder"
    $logsButton.Width = 130
    $logsButton.Height = 30
    $logsButton.Location = New-Object System.Drawing.Point(22, 174)
    $logsButton.Add_Click({
        Open-Path -Path (Get-SteamUpdateManagerPaths).LogPath
    })

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save"
    $saveButton.Width = 82
    $saveButton.Height = 30
    $saveButton.Location = New-Object System.Drawing.Point(178, 200)
    $saveButton.Add_Click({
        $config.StartWithWindows = [bool]$startupCheck.Checked
        $config.DiagnosticLogging = [bool]$loggingCheck.Checked
        $config.ShowTaskbarIcon = [bool]$taskbarCheck.Checked
        $config.Theme = [string]$themeCombo.SelectedItem

        Set-StartWithWindows -Enabled ([bool]$startupCheck.Checked)
        if (Save-Config -Config $config) {
            $script:NotifyIcon.Visible = ([bool]$config.ShowTaskbarIcon -or $ShowMenuOnStart)
            $script:TemporaryTrayIcon = $ShowMenuOnStart -and -not [bool]$config.ShowTaskbarIcon
            Write-Log "Settings saved from tray UI" -Level Info
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
    })

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Width = 82
    $cancelButton.Height = 30
    $cancelButton.Location = New-Object System.Drawing.Point(270, 200)
    $cancelButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    $form.Controls.AddRange(@($startupCheck, $loggingCheck, $taskbarCheck, $themeLabel, $themeCombo, $logsButton, $saveButton, $cancelButton))
    Set-ControlTheme -Control $form -ThemeName $themeName
    $form.AcceptButton = $saveButton
    $form.CancelButton = $cancelButton
    $form.ShowDialog() | Out-Null
}

function Open-ConfigureWindow {
    $config = Get-SteamLibraryUpdaterConfig

    if (-not $config.PSObject.Properties['UpdateCondition']) {
        $config | Add-Member -MemberType NoteProperty -Name "UpdateCondition" -Value "WhenAvailable"
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$script:AppName Configure"
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ClientSize = New-Object System.Drawing.Size(400, 220)
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.ShowInTaskbar = [bool]$config.ShowTaskbarIcon

    $themeName = Resolve-AppTheme -Theme $config.Theme

    $conditionsLabel = New-Object System.Windows.Forms.Label
    $conditionsLabel.Text = "Update Conditions"
    $conditionsLabel.AutoSize = $true
    $conditionsLabel.Location = New-Object System.Drawing.Point(22, 24)

    $whenAvailableCheck = New-Object System.Windows.Forms.CheckBox
    $whenAvailableCheck.Text = "When available"
    $whenAvailableCheck.AutoSize = $true
    $whenAvailableCheck.Location = New-Object System.Drawing.Point(36, 58)
    $whenAvailableCheck.Checked = ($config.UpdateCondition -eq "WhenAvailable")

    $gamingCheck = New-Object System.Windows.Forms.CheckBox
    $gamingCheck.Text = "Allow updates while gaming"
    $gamingCheck.AutoSize = $true
    $gamingCheck.Location = New-Object System.Drawing.Point(36, 92)
    $gamingCheck.Checked = [bool]$config.UpdateDuringGaming

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save"
    $saveButton.Width = 82
    $saveButton.Height = 30
    $saveButton.Location = New-Object System.Drawing.Point(198, 160)
    $saveButton.Add_Click({
        if ($whenAvailableCheck.Checked) {
            $config.UpdateCondition = "WhenAvailable"
        }
        else {
            $config.UpdateCondition = "ManualOnly"
        }
        $config.UpdateDuringGaming = [bool]$gamingCheck.Checked

        if (Save-Config -Config $config) {
            Write-Log "Update conditions saved from tray UI" -Level Info
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
    })

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Width = 82
    $cancelButton.Height = 30
    $cancelButton.Location = New-Object System.Drawing.Point(290, 160)
    $cancelButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    $form.Controls.AddRange(@($conditionsLabel, $whenAvailableCheck, $gamingCheck, $saveButton, $cancelButton))
    Set-ControlTheme -Control $form -ThemeName $themeName
    $form.AcceptButton = $saveButton
    $form.CancelButton = $cancelButton
    $form.ShowDialog() | Out-Null
}

function Open-AboutWindow {
    $version = Get-SteamUpdateManagerVersion
    $paths = Get-SteamUpdateManagerPaths
    $message = @"
$script:AppName v$version

PowerShell tray manager for Steam library update checks.

Config: $($paths.ConfigPath)
Logs: $($paths.LogPath)
"@

    [System.Windows.Forms.MessageBox]::Show(
        $message,
        "About $script:AppName",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Invoke-ManualUpdateCheck {
    try {
        $powerShellExe = Get-WindowsPowerShellPath
        $command = "Import-Module `"$script:ModulePath`" -Force; Start-SteamQueuedUpdates"
        Start-Process -FilePath $powerShellExe -WindowStyle Hidden -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", $command
        ) | Out-Null
        Write-Log "Manual update check launched from tray UI" -Level Info
        $script:NotifyIcon.ShowBalloonTip(3000, $script:AppName, "Update check started.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
    catch {
        Write-Log "Failed to launch manual update check: $_" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "The update check could not be started. Check the log for details.",
            $script:AppName,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Add-AllInstalledGames {
    try {
        $config = Get-SteamLibraryUpdaterConfig
        $installedGames = Get-InstalledSteamGames -SteamPath $config.SteamInstallPath
        $existingAppIds = @($config.MonitoredGames | ForEach-Object { $_.AppId })
        $added = 0

        foreach ($game in $installedGames) {
            if ($existingAppIds -contains $game.AppId) {
                continue
            }

            if (Add-MonitoredGame -AppId $game.AppId -Name $game.Name -InstallDir $game.InstallDir -ProcessName $game.ProcessName) {
                $added++
            }
        }

        $script:NotifyIcon.ShowBalloonTip(3000, $script:AppName, "Added $added installed game(s) to monitoring.", [System.Windows.Forms.ToolTipIcon]::Info)
    }
    catch {
        Write-Log "Failed to add installed games from tray UI: $_" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "Installed games could not be added. Check the log for details.",
            $script:AppName,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Ensure-InstalledGamesMonitored {
    try {
        $config = Get-SteamLibraryUpdaterConfig
        if ($config.Advanced -and $config.Advanced.PSObject.Properties['AutoMonitorInstalledGames'] -and -not [bool]$config.Advanced.AutoMonitorInstalledGames) {
            return
        }

        $installedGames = Get-InstalledSteamGames -SteamPath $config.SteamInstallPath
        $existingAppIds = @($config.MonitoredGames | ForEach-Object { $_.AppId })
        $added = 0

        foreach ($game in $installedGames) {
            if ($existingAppIds -contains $game.AppId) {
                continue
            }

            if (Add-MonitoredGame -AppId $game.AppId -Name $game.Name -InstallDir $game.InstallDir -ProcessName $game.ProcessName) {
                $added++
            }
        }

        if ($added -gt 0) {
            Write-Log "Automatically added $added installed Steam game(s) to monitoring" -Level Info
        }
    }
    catch {
        Write-Log "Automatic installed game monitoring failed: $_" -Level Warning
    }
}

function Open-Path {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Start-Process -FilePath $Path | Out-Null
    }
}

$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Icon = Get-AppIcon
$script:NotifyIcon.Text = "$script:AppName v$(Get-SteamUpdateManagerVersion)"
$script:NotifyIcon.Visible = ([bool]$script:StartupConfig.ShowTaskbarIcon -or $ShowMenuOnStart)

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.ShowImageMargin = $false
$menu.ShowCheckMargin = $false
$menu.Padding = New-Object System.Windows.Forms.Padding(0, 3, 0, 3)
$menu.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$headerItem = New-Object System.Windows.Forms.ToolStripMenuItem
$headerItem.Enabled = $false

$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$statusItem.Enabled = $false

$runWithSteamItem = New-Object System.Windows.Forms.ToolStripMenuItem("Run with Steam")
$runWithSteamItem.DropDown.ShowImageMargin = $false
$runWithSteamItem.DropDown.ShowCheckMargin = $false

$runWithSteamOnItem = New-Object System.Windows.Forms.ToolStripMenuItem("On")
$runWithSteamOnItem.Add_Click({
    $config = Get-SteamLibraryUpdaterConfig
    $config.EnableAutoUpdate = $true
    Save-Config -Config $config | Out-Null
})

$runWithSteamOffItem = New-Object System.Windows.Forms.ToolStripMenuItem("Off")
$runWithSteamOffItem.Add_Click({
    $config = Get-SteamLibraryUpdaterConfig
    $config.EnableAutoUpdate = $false
    Save-Config -Config $config | Out-Null
})

$null = $runWithSteamItem.DropDownItems.Add($runWithSteamOnItem)
$null = $runWithSteamItem.DropDownItems.Add($runWithSteamOffItem)

$checkNowItem = New-Object System.Windows.Forms.ToolStripMenuItem("Manually Start All Queued Updates")
$checkNowItem.Add_Click({ Invoke-ManualUpdateCheck })

$configureItem = New-Object System.Windows.Forms.ToolStripMenuItem("Configure Update Conditions")
$configureItem.Add_Click({ Open-ConfigureWindow })

$settingsItem = New-Object System.Windows.Forms.ToolStripMenuItem("Settings")
$settingsItem.Add_Click({ Open-SettingsWindow })

$aboutItem = New-Object System.Windows.Forms.ToolStripMenuItem("About")
$aboutItem.Add_Click({ Open-AboutWindow })

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
$exitItem.Add_Click({
    Write-Log "Tray app exited by user" -Level Info
    $script:NotifyIcon.Visible = $false
    $script:NotifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$null = $menu.Items.Add($headerItem)
$null = $menu.Items.Add($statusItem)
$null = $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$null = $menu.Items.Add($runWithSteamItem)
$null = $menu.Items.Add($checkNowItem)
$null = $menu.Items.Add($configureItem)
$null = $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$null = $menu.Items.Add($settingsItem)
$null = $menu.Items.Add($aboutItem)
$null = $menu.Items.Add($exitItem)

$menu.add_Opening({
    $config = Get-SteamLibraryUpdaterConfig
    Set-MenuTheme -Menu $menu -ThemeName (Resolve-AppTheme -Theme $config.Theme)
    $headerItem.Text = "$script:AppName v$(Get-SteamUpdateManagerVersion)"
    $statusItem.Text = "Status: $(Get-StatusText)"
    if ([bool]$config.EnableAutoUpdate) {
        $runWithSteamOnItem.Text = "On (selected)"
        $runWithSteamOffItem.Text = "Off"
    }
    else {
        $runWithSteamOnItem.Text = "On"
        $runWithSteamOffItem.Text = "Off (selected)"
    }
})

$menu.add_Closed({
    $config = Get-SteamLibraryUpdaterConfig
    if ($script:TemporaryTrayIcon -and -not [bool]$config.ShowTaskbarIcon) {
        $script:NotifyIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    }
})

$script:NotifyIcon.ContextMenuStrip = $menu
$script:NotifyIcon.Add_DoubleClick({ Invoke-ManualUpdateCheck })

if ($ShowMenuOnStart) {
    $startupMenuTimer = New-Object System.Windows.Forms.Timer
    $startupMenuTimer.Interval = 800
    $startupMenuTimer.Add_Tick({
        $startupMenuTimer.Stop()
        $startupMenuTimer.Dispose()
        $script:NotifyIcon.ContextMenuStrip.Show([System.Windows.Forms.Cursor]::Position)
    })
    $startupMenuTimer.Start()
}

Write-Log "Tray app started" -Level Info
Ensure-InstalledGamesMonitored
if (-not $ShowMenuOnStart -and -not [bool]$script:StartupConfig.ShowTaskbarIcon) {
    Write-Log "Tray icon is hidden by setting; startup pass completed without keeping a tray process resident" -Level Info
    $script:NotifyIcon.Dispose()
    exit 0
}
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::Run()
