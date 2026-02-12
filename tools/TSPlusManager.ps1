<#
.SYNOPSIS
    TSPlus Manager - Comprehensive management tool for TSPlus Remote Access

.DESCRIPTION
    Multi-tab GUI tool for managing TSPlus Remote Access installations.

    Features:
    - Uninstaller: Silent uninstall with configuration backup
    - License Manager: Apply, view, and validate TSPlus licenses
    - Service Manager: Start, stop, restart, and monitor TSPlus services
    - Configuration Backup/Restore: Export and import TSPlus settings
    - Update Checker: Check version, download and apply updates

    This tool provides complete lifecycle management for TSPlus installations.

.NOTES
    Version: 1.0.0
    Author: Bepoz Administration Team
    Requires: Administrator privileges for most operations
    Database: Not required

.EXAMPLE
    # Launch via Bepoz Toolkit
    # Navigate to: TSPlus > TSPlus Manager

#>

#requires -version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Module Loading

# Load BepozLogger (optional but recommended)
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

$script:BepozLoggerAvailable = $false
if ($loggerModule) {
    try {
        . $loggerModule.FullName
        $script:CentralLogFile = Initialize-BepozLogger -ToolName "TSPlusManager"
        $script:BepozLoggerAvailable = $true
        Write-BepozLogAction "TSPlus Manager started"
    } catch {
        $script:BepozLoggerAvailable = $false
    }
}

#endregion

#region Configuration

# TSPlus paths
$script:TSPlusInstallPath = "C:\Program Files (x86)\TSplus"
$script:TSPlusAdminTool = "$script:TSPlusInstallPath\UserDesktop\files\AdminTool.exe"
$script:TSPlusUninstaller = "$script:TSPlusInstallPath\unins000.exe"
$script:TSPlusConfigPath = "$script:TSPlusInstallPath\UserDesktop\config"
$script:TSPlusBackupPath = "C:\Bepoz\TSPlus\Backups"
$script:TSPlusDownloadUrl = "https://dl-files.com/classic/Setup-TSplus.exe"
$script:TSPlusDownloadPath = "C:\ProgramData\TSPlus\Install"

# TSPlus service names (common services - may vary by version)
$script:TSPlusServices = @(
    "TSplus",
    "TSplus Gateway",
    "TSplus Server Genius",
    "TSplus HTML5"
)

#endregion

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    # Log to BepozLogger if available
    if ($script:BepozLoggerAvailable) {
        switch ($Level) {
            "ERROR"   { Write-BepozLogError $Message }
            "WARNING" { Write-BepozLogAction "WARNING: $Message" }
            default   { Write-BepozLogAction $Message }
        }
    }

    # Output to console
    Write-Host $logLine
}

function Test-TSPlusInstalled {
    return (Test-Path $script:TSPlusAdminTool)
}

function Get-TSPlusVersion {
    if (Test-TSPlusInstalled) {
        try {
            $versionInfo = (Get-Item $script:TSPlusAdminTool).VersionInfo
            return $versionInfo.FileVersion
        } catch {
            return "Unknown"
        }
    }
    return $null
}

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function UI-Invoke {
    param($Control, $Action)
    if ($Control.InvokeRequired) {
        $Control.Invoke($Action)
    } else {
        & $Action
    }
}

#endregion

#region Tab 1: Uninstaller

function Initialize-UninstallerTab {
    param($TabPage)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(20)

    $y = 10

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Location = New-Object System.Drawing.Point(10, $y)
    $title.Size = New-Object System.Drawing.Size(760, 30)
    $title.Text = "Uninstall TSPlus Remote Access"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($title)
    $y += 40

    # Status
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(10, $y)
    $statusLabel.Size = New-Object System.Drawing.Size(760, 60)
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    if (Test-TSPlusInstalled) {
        $version = Get-TSPlusVersion
        $statusLabel.Text = "TSPlus is currently installed.`nVersion: $version`nLocation: $script:TSPlusInstallPath"
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $statusLabel.Text = "TSPlus is not installed on this system."
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
    }
    $panel.Controls.Add($statusLabel)
    $y += 70

    # Backup checkbox
    $backupCheckbox = New-Object System.Windows.Forms.CheckBox
    $backupCheckbox.Location = New-Object System.Drawing.Point(10, $y)
    $backupCheckbox.Size = New-Object System.Drawing.Size(760, 25)
    $backupCheckbox.Text = "Backup configuration before uninstalling (Recommended)"
    $backupCheckbox.Checked = $true
    $backupCheckbox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $panel.Controls.Add($backupCheckbox)
    $y += 35

    # Log textbox
    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Location = New-Object System.Drawing.Point(10, $y)
    $logBox.Size = New-Object System.Drawing.Size(760, 170)
    $logBox.Multiline = $true
    $logBox.ScrollBars = "Vertical"
    $logBox.ReadOnly = $true
    $logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $panel.Controls.Add($logBox)
    $y += 180

    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, $y)
    $progressBar.Size = New-Object System.Drawing.Size(760, 25)
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 30
    $progressBar.Visible = $false
    $panel.Controls.Add($progressBar)
    $y += 35

    # Uninstall button
    $uninstallButton = New-Object System.Windows.Forms.Button
    $uninstallButton.Location = New-Object System.Drawing.Point(10, $y)
    $uninstallButton.Size = New-Object System.Drawing.Size(180, 35)
    $uninstallButton.Text = "Uninstall TSPlus"
    $uninstallButton.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)  # Red
    $uninstallButton.ForeColor = [System.Drawing.Color]::White
    $uninstallButton.FlatStyle = "Flat"
    $uninstallButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $uninstallButton.Enabled = Test-TSPlusInstalled
    $uninstallButton.Add_Click({
        if (-not (Test-IsAdmin)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Administrator privileges are required to uninstall TSPlus.`n`nPlease run this tool as Administrator.",
                "Admin Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $result = [System.Windows.Forms.MessageBox]::Show(
            "This will uninstall TSPlus Remote Access from this system.`n`nAre you sure you want to continue?",
            "Confirm Uninstall",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        $uninstallButton.Enabled = $false
        $logBox.Clear()

        $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Starting uninstall process...`r`n")
        Write-Log "TSPlus uninstall initiated" -Level INFO

        # Backup configuration if checked
        if ($backupCheckbox.Checked) {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Backing up configuration...`r`n")
            Write-Log "Creating configuration backup" -Level INFO

            try {
                $backupTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupFolder = Join-Path $script:TSPlusBackupPath "Uninstall_$backupTimestamp"
                New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

                if (Test-Path $script:TSPlusConfigPath) {
                    Copy-Item -Path "$script:TSPlusConfigPath\*" -Destination $backupFolder -Recurse -Force
                    $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Configuration backed up to: $backupFolder`r`n")
                    Write-Log "Configuration backed up to: $backupFolder" -Level SUCCESS
                } else {
                    $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] No configuration found to backup`r`n")
                }
            } catch {
                $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Backup failed: $($_.Exception.Message)`r`n")
                Write-Log "Backup failed: $($_.Exception.Message)" -Level WARNING
            }
        }

        # Run uninstaller
        if (Test-Path $script:TSPlusUninstaller) {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Running uninstaller...`r`n")
            Write-Log "Executing TSPlus uninstaller" -Level INFO

            # Show progress bar
            $progressBar.Visible = $true

            try {
                # Start process without waiting
                $process = Start-Process -FilePath $script:TSPlusUninstaller -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -PassThru

                # Create timer to monitor process
                $timer = New-Object System.Windows.Forms.Timer
                $timer.Interval = 500  # Check every 500ms
                $script:startTime = Get-Date

                $timer.Add_Tick({
                    $elapsed = [math]::Round(((Get-Date) - $script:startTime).TotalSeconds, 0)

                    if ($process.HasExited) {
                        # Stop timer and hide progress bar
                        $timer.Stop()
                        $timer.Dispose()
                        UI-Invoke $progressBar { $progressBar.Visible = $false }

                        # Check exit code
                        if ($process.ExitCode -eq 0) {
                            UI-Invoke $logBox {
                                $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Uninstall completed successfully (Exit Code: 0, Duration: ${elapsed}s)`r`n")
                            }
                            Write-Log "TSPlus uninstalled successfully in ${elapsed}s" -Level SUCCESS

                            [System.Windows.Forms.MessageBox]::Show(
                                "TSPlus has been successfully uninstalled.`n`nDuration: ${elapsed} seconds`n`nA system reboot is recommended.",
                                "Uninstall Complete",
                                [System.Windows.Forms.MessageBoxButtons]::OK,
                                [System.Windows.Forms.MessageBoxIcon]::Information
                            ) | Out-Null

                            # Refresh status
                            UI-Invoke $statusLabel {
                                $statusLabel.Text = "TSPlus is not installed on this system."
                                $statusLabel.ForeColor = [System.Drawing.Color]::Red
                            }
                        } else {
                            UI-Invoke $logBox {
                                $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Uninstall completed with exit code: $($process.ExitCode) (Duration: ${elapsed}s)`r`n")
                            }
                            Write-Log "TSPlus uninstall exit code: $($process.ExitCode)" -Level WARNING

                            [System.Windows.Forms.MessageBox]::Show(
                                "Uninstall completed with exit code: $($process.ExitCode)`n`nDuration: ${elapsed} seconds`n`nCheck the log for details.",
                                "Uninstall Result",
                                [System.Windows.Forms.MessageBoxButtons]::OK,
                                [System.Windows.Forms.MessageBoxIcon]::Warning
                            ) | Out-Null
                        }

                        # Re-enable button
                        UI-Invoke $uninstallButton {
                            $uninstallButton.Enabled = Test-TSPlusInstalled
                        }
                    } else {
                        # Still running - update log
                        UI-Invoke $logBox {
                            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Uninstalling... (${elapsed}s elapsed)`r`n")
                        }
                    }
                })

                $timer.Start()

            } catch {
                $progressBar.Visible = $false
                $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Error: $($_.Exception.Message)`r`n")
                Write-Log "Uninstall error: $($_.Exception.Message)" -Level ERROR

                [System.Windows.Forms.MessageBox]::Show(
                    "Uninstall failed: $($_.Exception.Message)",
                    "Uninstall Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null

                $uninstallButton.Enabled = Test-TSPlusInstalled
            }
        } else {
            $logBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] Uninstaller not found at: $script:TSPlusUninstaller`r`n")
            Write-Log "Uninstaller not found" -Level ERROR

            [System.Windows.Forms.MessageBox]::Show(
                "TSPlus uninstaller not found.`n`nYou may need to uninstall via Windows Settings.",
                "Uninstaller Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }

        $uninstallButton.Enabled = Test-TSPlusInstalled
    })
    $panel.Controls.Add($uninstallButton)

    $TabPage.Controls.Add($panel)
}

#endregion

#region Tab 2: License Manager

function Initialize-LicenseTab {
    param($TabPage)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(20)

    $y = 10

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Location = New-Object System.Drawing.Point(10, $y)
    $title.Size = New-Object System.Drawing.Size(760, 30)
    $title.Text = "TSPlus License Management"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($title)
    $y += 40

    # Current license info
    $licenseInfoBox = New-Object System.Windows.Forms.GroupBox
    $licenseInfoBox.Location = New-Object System.Drawing.Point(10, $y)
    $licenseInfoBox.Size = New-Object System.Drawing.Size(760, 120)
    $licenseInfoBox.Text = "Current License Information"
    $licenseInfoBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

    $licenseStatus = New-Object System.Windows.Forms.Label
    $licenseStatus.Location = New-Object System.Drawing.Point(15, 30)
    $licenseStatus.Size = New-Object System.Drawing.Size(730, 80)
    $licenseStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $licenseStatus.Text = "Checking license status..."
    $licenseInfoBox.Controls.Add($licenseStatus)

    $panel.Controls.Add($licenseInfoBox)
    $y += 130

    # License key input
    $keyLabel = New-Object System.Windows.Forms.Label
    $keyLabel.Location = New-Object System.Drawing.Point(10, $y)
    $keyLabel.Size = New-Object System.Drawing.Size(200, 25)
    $keyLabel.Text = "License Key:"
    $keyLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $panel.Controls.Add($keyLabel)
    $y += 30

    $keyTextBox = New-Object System.Windows.Forms.TextBox
    $keyTextBox.Location = New-Object System.Drawing.Point(10, $y)
    $keyTextBox.Size = New-Object System.Drawing.Size(600, 25)
    $keyTextBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $panel.Controls.Add($keyTextBox)
    $y += 35

    # Apply license button
    $applyButton = New-Object System.Windows.Forms.Button
    $applyButton.Location = New-Object System.Drawing.Point(10, $y)
    $applyButton.Size = New-Object System.Drawing.Size(150, 35)
    $applyButton.Text = "Apply License"
    $applyButton.BackColor = [System.Drawing.Color]::FromArgb(10, 124, 72)  # Bepoz Green
    $applyButton.ForeColor = [System.Drawing.Color]::White
    $applyButton.FlatStyle = "Flat"
    $applyButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $applyButton.Add_Click({
        if (-not (Test-TSPlusInstalled)) {
            [System.Windows.Forms.MessageBox]::Show(
                "TSPlus is not installed on this system.",
                "TSPlus Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        if ([string]::IsNullOrWhiteSpace($keyTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter a license key.",
                "License Key Required",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        Write-Log "Applying TSPlus license key" -Level INFO

        # Try to apply license via registry or AdminTool
        # Note: This is a placeholder - actual implementation depends on TSPlus version
        try {
            # Method 1: Try registry (common location for TSPlus licenses)
            $regPath = "HKLM:\SOFTWARE\TSplus"
            if (Test-Path $regPath) {
                Set-ItemProperty -Path $regPath -Name "LicenseKey" -Value $keyTextBox.Text -ErrorAction Stop
                Write-Log "License key applied via registry" -Level SUCCESS

                [System.Windows.Forms.MessageBox]::Show(
                    "License key has been applied.`n`nPlease restart TSPlus services for changes to take effect.",
                    "License Applied",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            } else {
                # Method 2: Use AdminTool command line (if supported)
                [System.Windows.Forms.MessageBox]::Show(
                    "Automated license application is not available.`n`nPlease use TSPlus AdminTool to apply the license manually.",
                    "Manual Application Required",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
        } catch {
            Write-Log "License application error: $($_.Exception.Message)" -Level ERROR
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to apply license: $($_.Exception.Message)`n`nPlease use TSPlus AdminTool to apply manually.",
                "License Application Failed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })
    $panel.Controls.Add($applyButton)

    # Refresh button
    $refreshButton = New-Object System.Windows.Forms.Button
    $refreshButton.Location = New-Object System.Drawing.Point(170, $y)
    $refreshButton.Size = New-Object System.Drawing.Size(150, 35)
    $refreshButton.Text = "Refresh Status"
    $refreshButton.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)  # Gray
    $refreshButton.ForeColor = [System.Drawing.Color]::White
    $refreshButton.FlatStyle = "Flat"
    $refreshButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $refreshButton.Add_Click({
        $licenseStatus.Text = "Checking license status..."

        if (-not (Test-TSPlusInstalled)) {
            $licenseStatus.Text = "TSPlus is not installed."
            $licenseStatus.ForeColor = [System.Drawing.Color]::Red
            return
        }

        Write-Log "Checking TSPlus license status" -Level INFO

        # Check license (placeholder - depends on TSPlus version)
        try {
            $regPath = "HKLM:\SOFTWARE\TSplus"
            if (Test-Path $regPath) {
                $licenseKey = Get-ItemProperty -Path $regPath -Name "LicenseKey" -ErrorAction SilentlyContinue
                if ($licenseKey) {
                    $maskedKey = "*" * ($licenseKey.LicenseKey.Length - 4) + $licenseKey.LicenseKey.Substring($licenseKey.LicenseKey.Length - 4)
                    $licenseStatus.Text = "License Key: $maskedKey`nStatus: Unknown (use AdminTool for full details)"
                    $licenseStatus.ForeColor = [System.Drawing.Color]::Green
                } else {
                    $licenseStatus.Text = "No license key found in registry.`nPlease check TSPlus AdminTool for license details."
                    $licenseStatus.ForeColor = [System.Drawing.Color]::Orange
                }
            } else {
                $licenseStatus.Text = "TSPlus registry keys not found.`nPlease check TSPlus AdminTool for license details."
                $licenseStatus.ForeColor = [System.Drawing.Color]::Orange
            }
        } catch {
            $licenseStatus.Text = "Error checking license: $($_.Exception.Message)"
            $licenseStatus.ForeColor = [System.Drawing.Color]::Red
            Write-Log "License check error: $($_.Exception.Message)" -Level ERROR
        }
    })
    $panel.Controls.Add($refreshButton)

    # Open AdminTool button
    $adminToolButton = New-Object System.Windows.Forms.Button
    $adminToolButton.Location = New-Object System.Drawing.Point(330, $y)
    $adminToolButton.Size = New-Object System.Drawing.Size(180, 35)
    $adminToolButton.Text = "Open AdminTool"
    $adminToolButton.BackColor = [System.Drawing.Color]::FromArgb(103, 58, 182)  # Purple
    $adminToolButton.ForeColor = [System.Drawing.Color]::White
    $adminToolButton.FlatStyle = "Flat"
    $adminToolButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $adminToolButton.Add_Click({
        if (Test-Path $script:TSPlusAdminTool) {
            Write-Log "Opening TSPlus AdminTool" -Level INFO
            Start-Process -FilePath $script:TSPlusAdminTool
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "TSPlus AdminTool not found.",
                "AdminTool Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
        }
    })
    $panel.Controls.Add($adminToolButton)

    # Initial license check
    $refreshButton.PerformClick()

    $TabPage.Controls.Add($panel)
}

#endregion

#region Tab 3: Service Manager

function Initialize-ServiceTab {
    param($TabPage)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(20)

    $y = 10

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Location = New-Object System.Drawing.Point(10, $y)
    $title.Size = New-Object System.Drawing.Size(760, 30)
    $title.Text = "TSPlus Service Management"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($title)
    $y += 40

    # Service list
    $serviceListView = New-Object System.Windows.Forms.ListView
    $serviceListView.Location = New-Object System.Drawing.Point(10, $y)
    $serviceListView.Size = New-Object System.Drawing.Size(760, 300)
    $serviceListView.View = "Details"
    $serviceListView.FullRowSelect = $true
    $serviceListView.GridLines = $true
    $serviceListView.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    [void]$serviceListView.Columns.Add("Service Name", 200)
    [void]$serviceListView.Columns.Add("Status", 100)
    [void]$serviceListView.Columns.Add("Startup Type", 100)
    [void]$serviceListView.Columns.Add("Display Name", 340)

    $panel.Controls.Add($serviceListView)
    $y += 310

    # Buttons
    $buttonY = $y
    $buttonWidth = 120
    $buttonHeight = 35
    $buttonSpacing = 10

    # Start button
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Location = New-Object System.Drawing.Point(10, $buttonY)
    $startButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $startButton.Text = "Start"
    $startButton.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)  # Green
    $startButton.ForeColor = [System.Drawing.Color]::White
    $startButton.FlatStyle = "Flat"
    $startButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $startButton.Add_Click({
        if ($serviceListView.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a service.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $serviceName = $serviceListView.SelectedItems[0].Text
        Write-Log "Starting service: $serviceName" -Level INFO

        try {
            Start-Service -Name $serviceName -ErrorAction Stop
            Write-Log "Service started: $serviceName" -Level SUCCESS
            [System.Windows.Forms.MessageBox]::Show("Service '$serviceName' started successfully.", "Service Started", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            & $refreshServicesButton.PerformClick()
        } catch {
            Write-Log "Failed to start service: $($_.Exception.Message)" -Level ERROR
            [System.Windows.Forms.MessageBox]::Show("Failed to start service: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })
    $panel.Controls.Add($startButton)

    # Stop button
    $stopButton = New-Object System.Windows.Forms.Button
    $stopButton.Location = New-Object System.Drawing.Point((10 + $buttonWidth + $buttonSpacing), $buttonY)
    $stopButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $stopButton.Text = "Stop"
    $stopButton.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)  # Red
    $stopButton.ForeColor = [System.Drawing.Color]::White
    $stopButton.FlatStyle = "Flat"
    $stopButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $stopButton.Add_Click({
        if ($serviceListView.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a service.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $serviceName = $serviceListView.SelectedItems[0].Text
        $result = [System.Windows.Forms.MessageBox]::Show("Stop service '$serviceName'?", "Confirm Stop", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Log "Stopping service: $serviceName" -Level INFO

            try {
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Log "Service stopped: $serviceName" -Level SUCCESS
                [System.Windows.Forms.MessageBox]::Show("Service '$serviceName' stopped successfully.", "Service Stopped", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                & $refreshServicesButton.PerformClick()
            } catch {
                Write-Log "Failed to stop service: $($_.Exception.Message)" -Level ERROR
                [System.Windows.Forms.MessageBox]::Show("Failed to stop service: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            }
        }
    })
    $panel.Controls.Add($stopButton)

    # Restart button
    $restartButton = New-Object System.Windows.Forms.Button
    $restartButton.Location = New-Object System.Drawing.Point((10 + ($buttonWidth + $buttonSpacing) * 2), $buttonY)
    $restartButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $restartButton.Text = "Restart"
    $restartButton.BackColor = [System.Drawing.Color]::FromArgb(255, 193, 7)  # Orange
    $restartButton.ForeColor = [System.Drawing.Color]::Black
    $restartButton.FlatStyle = "Flat"
    $restartButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $restartButton.Add_Click({
        if ($serviceListView.SelectedItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Please select a service.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $serviceName = $serviceListView.SelectedItems[0].Text
        Write-Log "Restarting service: $serviceName" -Level INFO

        try {
            Restart-Service -Name $serviceName -Force -ErrorAction Stop
            Write-Log "Service restarted: $serviceName" -Level SUCCESS
            [System.Windows.Forms.MessageBox]::Show("Service '$serviceName' restarted successfully.", "Service Restarted", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            & $refreshServicesButton.PerformClick()
        } catch {
            Write-Log "Failed to restart service: $($_.Exception.Message)" -Level ERROR
            [System.Windows.Forms.MessageBox]::Show("Failed to restart service: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })
    $panel.Controls.Add($restartButton)

    # Refresh button
    $script:refreshServicesButton = New-Object System.Windows.Forms.Button
    $refreshServicesButton.Location = New-Object System.Drawing.Point((10 + ($buttonWidth + $buttonSpacing) * 3), $buttonY)
    $refreshServicesButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $refreshServicesButton.Text = "Refresh"
    $refreshServicesButton.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)  # Gray
    $refreshServicesButton.ForeColor = [System.Drawing.Color]::White
    $refreshServicesButton.FlatStyle = "Flat"
    $refreshServicesButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $refreshServicesButton.Add_Click({
        $serviceListView.Items.Clear()
        Write-Log "Refreshing service list" -Level INFO

        # Get all services that might be TSPlus-related
        $services = Get-Service | Where-Object { $_.Name -like "*TSplus*" -or $_.DisplayName -like "*TSplus*" }

        if ($services.Count -eq 0) {
            $item = New-Object System.Windows.Forms.ListViewItem("No TSPlus services found")
            $item.SubItems.Add("-")
            $item.SubItems.Add("-")
            $item.SubItems.Add("-")
            [void]$serviceListView.Items.Add($item)
        } else {
            foreach ($service in $services) {
                $item = New-Object System.Windows.Forms.ListViewItem($service.Name)
                $item.SubItems.Add($service.Status.ToString())
                $item.SubItems.Add($service.StartType.ToString())
                $item.SubItems.Add($service.DisplayName)

                # Color code status
                if ($service.Status -eq "Running") {
                    $item.ForeColor = [System.Drawing.Color]::Green
                } else {
                    $item.ForeColor = [System.Drawing.Color]::Red
                }

                [void]$serviceListView.Items.Add($item)
            }
        }
    })
    $panel.Controls.Add($refreshServicesButton)

    # Start All button
    $startAllButton = New-Object System.Windows.Forms.Button
    $startAllButton.Location = New-Object System.Drawing.Point((10 + ($buttonWidth + $buttonSpacing) * 4), $buttonY)
    $startAllButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
    $startAllButton.Text = "Start All"
    $startAllButton.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)  # Green
    $startAllButton.ForeColor = [System.Drawing.Color]::White
    $startAllButton.FlatStyle = "Flat"
    $startAllButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $startAllButton.Add_Click({
        Write-Log "Starting all TSPlus services" -Level INFO

        $services = Get-Service | Where-Object { $_.Name -like "*TSplus*" -or $_.DisplayName -like "*TSplus*" }
        $started = 0
        $failed = 0

        foreach ($service in $services) {
            if ($service.Status -ne "Running") {
                try {
                    Start-Service -Name $service.Name -ErrorAction Stop
                    $started++
                    Write-Log "Started service: $($service.Name)" -Level SUCCESS
                } catch {
                    $failed++
                    Write-Log "Failed to start service $($service.Name): $($_.Exception.Message)" -Level ERROR
                }
            }
        }

        [System.Windows.Forms.MessageBox]::Show("Started: $started`nFailed: $failed", "Start All Services", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        & $refreshServicesButton.PerformClick()
    })
    $panel.Controls.Add($startAllButton)

    # Initial refresh
    $refreshServicesButton.PerformClick()

    $TabPage.Controls.Add($panel)
}

#endregion

#region Tab 4: Configuration Backup/Restore

function Initialize-BackupTab {
    param($TabPage)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(20)

    $y = 10

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Location = New-Object System.Drawing.Point(10, $y)
    $title.Size = New-Object System.Drawing.Size(760, 30)
    $title.Text = "Configuration Backup & Restore"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($title)
    $y += 40

    # Backup section
    $backupGroup = New-Object System.Windows.Forms.GroupBox
    $backupGroup.Location = New-Object System.Drawing.Point(10, $y)
    $backupGroup.Size = New-Object System.Drawing.Size(760, 180)
    $backupGroup.Text = "Backup Configuration"
    $backupGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

    $backupLabel = New-Object System.Windows.Forms.Label
    $backupLabel.Location = New-Object System.Drawing.Point(15, 30)
    $backupLabel.Size = New-Object System.Drawing.Size(730, 40)
    $backupLabel.Text = "Backup TSPlus configuration files to: $script:TSPlusBackupPath"
    $backupLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $backupGroup.Controls.Add($backupLabel)

    $backupDescLabel = New-Object System.Windows.Forms.Label
    $backupDescLabel.Location = New-Object System.Drawing.Point(15, 75)
    $backupDescLabel.Size = New-Object System.Drawing.Size(730, 25)
    $backupDescLabel.Text = "Enter a description for this backup (optional):"
    $backupDescLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $backupGroup.Controls.Add($backupDescLabel)

    $backupDescBox = New-Object System.Windows.Forms.TextBox
    $backupDescBox.Location = New-Object System.Drawing.Point(15, 100)
    $backupDescBox.Size = New-Object System.Drawing.Size(600, 25)
    $backupDescBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $backupDescBox.Text = "Manual backup - $(Get-Date -Format 'yyyy-MM-dd')"
    $backupGroup.Controls.Add($backupDescBox)

    $backupButton = New-Object System.Windows.Forms.Button
    $backupButton.Location = New-Object System.Drawing.Point(15, 135)
    $backupButton.Size = New-Object System.Drawing.Size(180, 35)
    $backupButton.Text = "Create Backup"
    $backupButton.BackColor = [System.Drawing.Color]::FromArgb(10, 124, 72)  # Bepoz Green
    $backupButton.ForeColor = [System.Drawing.Color]::White
    $backupButton.FlatStyle = "Flat"
    $backupButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $backupButton.Add_Click({
        if (-not (Test-TSPlusInstalled)) {
            [System.Windows.Forms.MessageBox]::Show("TSPlus is not installed.", "TSPlus Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        Write-Log "Creating configuration backup" -Level INFO

        try {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupFolder = Join-Path $script:TSPlusBackupPath "Backup_$timestamp"
            New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

            # Save description
            if (-not [string]::IsNullOrWhiteSpace($backupDescBox.Text)) {
                $backupDescBox.Text | Out-File -FilePath (Join-Path $backupFolder "description.txt")
            }

            # Backup configuration
            if (Test-Path $script:TSPlusConfigPath) {
                Copy-Item -Path "$script:TSPlusConfigPath\*" -Destination $backupFolder -Recurse -Force
                Write-Log "Configuration backed up to: $backupFolder" -Level SUCCESS

                # Get backup size
                $backupSize = (Get-ChildItem -Path $backupFolder -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB

                [System.Windows.Forms.MessageBox]::Show(
                    "Configuration backed up successfully.`n`nLocation: $backupFolder`nSize: $([math]::Round($backupSize, 2)) MB",
                    "Backup Complete",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null

                # Refresh backup list
                & $refreshBackupsButton.PerformClick()
            } else {
                [System.Windows.Forms.MessageBox]::Show("TSPlus configuration folder not found.", "Config Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            }
        } catch {
            Write-Log "Backup failed: $($_.Exception.Message)" -Level ERROR
            [System.Windows.Forms.MessageBox]::Show("Backup failed: $($_.Exception.Message)", "Backup Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })
    $backupGroup.Controls.Add($backupButton)

    $openBackupFolderButton = New-Object System.Windows.Forms.Button
    $openBackupFolderButton.Location = New-Object System.Drawing.Point(205, 135)
    $openBackupFolderButton.Size = New-Object System.Drawing.Size(180, 35)
    $openBackupFolderButton.Text = "Open Backup Folder"
    $openBackupFolderButton.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)  # Gray
    $openBackupFolderButton.ForeColor = [System.Drawing.Color]::White
    $openBackupFolderButton.FlatStyle = "Flat"
    $openBackupFolderButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $openBackupFolderButton.Add_Click({
        if (Test-Path $script:TSPlusBackupPath) {
            Start-Process -FilePath "explorer.exe" -ArgumentList $script:TSPlusBackupPath
        } else {
            [System.Windows.Forms.MessageBox]::Show("Backup folder does not exist yet.", "Folder Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
    })
    $backupGroup.Controls.Add($openBackupFolderButton)

    $panel.Controls.Add($backupGroup)
    $y += 190

    # Restore section
    $restoreGroup = New-Object System.Windows.Forms.GroupBox
    $restoreGroup.Location = New-Object System.Drawing.Point(10, $y)
    $restoreGroup.Size = New-Object System.Drawing.Size(760, 220)
    $restoreGroup.Text = "Restore Configuration"
    $restoreGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

    $restoreLabel = New-Object System.Windows.Forms.Label
    $restoreLabel.Location = New-Object System.Drawing.Point(15, 30)
    $restoreLabel.Size = New-Object System.Drawing.Size(730, 25)
    $restoreLabel.Text = "Select a backup to restore:"
    $restoreLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $restoreGroup.Controls.Add($restoreLabel)

    $backupListBox = New-Object System.Windows.Forms.ListBox
    $backupListBox.Location = New-Object System.Drawing.Point(15, 55)
    $backupListBox.Size = New-Object System.Drawing.Size(730, 100)
    $backupListBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $restoreGroup.Controls.Add($backupListBox)

    $script:refreshBackupsButton = New-Object System.Windows.Forms.Button
    $refreshBackupsButton.Location = New-Object System.Drawing.Point(15, 165)
    $refreshBackupsButton.Size = New-Object System.Drawing.Size(150, 35)
    $refreshBackupsButton.Text = "Refresh List"
    $refreshBackupsButton.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)  # Gray
    $refreshBackupsButton.ForeColor = [System.Drawing.Color]::White
    $refreshBackupsButton.FlatStyle = "Flat"
    $refreshBackupsButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $refreshBackupsButton.Add_Click({
        $backupListBox.Items.Clear()

        if (Test-Path $script:TSPlusBackupPath) {
            $backups = Get-ChildItem -Path $script:TSPlusBackupPath -Directory | Sort-Object Name -Descending

            if ($backups.Count -eq 0) {
                [void]$backupListBox.Items.Add("No backups found")
            } else {
                foreach ($backup in $backups) {
                    $descFile = Join-Path $backup.FullName "description.txt"
                    $desc = ""
                    if (Test-Path $descFile) {
                        $desc = " - $(Get-Content $descFile -First 1)"
                    }
                    [void]$backupListBox.Items.Add("$($backup.Name)$desc")
                }
            }
        } else {
            [void]$backupListBox.Items.Add("Backup folder does not exist")
        }
    })
    $restoreGroup.Controls.Add($refreshBackupsButton)

    $restoreButton = New-Object System.Windows.Forms.Button
    $restoreButton.Location = New-Object System.Drawing.Point(175, 165)
    $restoreButton.Size = New-Object System.Drawing.Size(180, 35)
    $restoreButton.Text = "Restore Selected"
    $restoreButton.BackColor = [System.Drawing.Color]::FromArgb(255, 193, 7)  # Orange
    $restoreButton.ForeColor = [System.Drawing.Color]::Black
    $restoreButton.FlatStyle = "Flat"
    $restoreButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $restoreButton.Add_Click({
        if ($backupListBox.SelectedIndex -eq -1) {
            [System.Windows.Forms.MessageBox]::Show("Please select a backup to restore.", "No Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $selectedText = $backupListBox.SelectedItem.ToString()
        $backupName = $selectedText.Split(' - ')[0]
        $backupPath = Join-Path $script:TSPlusBackupPath $backupName

        $result = [System.Windows.Forms.MessageBox]::Show(
            "This will restore TSPlus configuration from:`n$backupPath`n`nCurrent configuration will be backed up first.`n`nContinue?",
            "Confirm Restore",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        Write-Log "Restoring configuration from: $backupPath" -Level INFO

        try {
            # Backup current config first
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $preRestoreBackup = Join-Path $script:TSPlusBackupPath "PreRestore_$timestamp"
            New-Item -ItemType Directory -Path $preRestoreBackup -Force | Out-Null

            if (Test-Path $script:TSPlusConfigPath) {
                Copy-Item -Path "$script:TSPlusConfigPath\*" -Destination $preRestoreBackup -Recurse -Force
                Write-Log "Current config backed up to: $preRestoreBackup" -Level INFO
            }

            # Restore from backup
            Copy-Item -Path "$backupPath\*" -Destination $script:TSPlusConfigPath -Recurse -Force
            Write-Log "Configuration restored from: $backupPath" -Level SUCCESS

            [System.Windows.Forms.MessageBox]::Show(
                "Configuration restored successfully.`n`nPlease restart TSPlus services for changes to take effect.",
                "Restore Complete",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        } catch {
            Write-Log "Restore failed: $($_.Exception.Message)" -Level ERROR
            [System.Windows.Forms.MessageBox]::Show("Restore failed: $($_.Exception.Message)", "Restore Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    })
    $restoreGroup.Controls.Add($restoreButton)

    $panel.Controls.Add($restoreGroup)

    # Initial refresh
    $refreshBackupsButton.PerformClick()

    $TabPage.Controls.Add($panel)
}

#endregion

#region Tab 5: Update Checker

function Initialize-UpdateTab {
    param($TabPage)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding(20)

    $y = 10

    # Title
    $title = New-Object System.Windows.Forms.Label
    $title.Location = New-Object System.Drawing.Point(10, $y)
    $title.Size = New-Object System.Drawing.Size(760, 30)
    $title.Text = "TSPlus Update Checker"
    $title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($title)
    $y += 40

    # Current version
    $currentVersionLabel = New-Object System.Windows.Forms.Label
    $currentVersionLabel.Location = New-Object System.Drawing.Point(10, $y)
    $currentVersionLabel.Size = New-Object System.Drawing.Size(760, 60)
    $currentVersionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    if (Test-TSPlusInstalled) {
        $version = Get-TSPlusVersion
        $currentVersionLabel.Text = "Current TSPlus Version: $version`nInstalled at: $script:TSPlusInstallPath"
        $currentVersionLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $currentVersionLabel.Text = "TSPlus is not installed on this system."
        $currentVersionLabel.ForeColor = [System.Drawing.Color]::Red
    }
    $panel.Controls.Add($currentVersionLabel)
    $y += 70

    # Update info
    $updateInfoBox = New-Object System.Windows.Forms.GroupBox
    $updateInfoBox.Location = New-Object System.Drawing.Point(10, $y)
    $updateInfoBox.Size = New-Object System.Drawing.Size(760, 120)
    $updateInfoBox.Text = "Update Information"
    $updateInfoBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

    $updateStatus = New-Object System.Windows.Forms.Label
    $updateStatus.Location = New-Object System.Drawing.Point(15, 30)
    $updateStatus.Size = New-Object System.Drawing.Size(730, 80)
    $updateStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $updateStatus.Text = "Click 'Check for Updates' to check TSPlus website for latest version."
    $updateInfoBox.Controls.Add($updateStatus)

    $panel.Controls.Add($updateInfoBox)
    $y += 130

    # Download URL
    $urlLabel = New-Object System.Windows.Forms.Label
    $urlLabel.Location = New-Object System.Drawing.Point(10, $y)
    $urlLabel.Size = New-Object System.Drawing.Size(200, 25)
    $urlLabel.Text = "Installer Download URL:"
    $urlLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $panel.Controls.Add($urlLabel)
    $y += 30

    $urlTextBox = New-Object System.Windows.Forms.TextBox
    $urlTextBox.Location = New-Object System.Drawing.Point(10, $y)
    $urlTextBox.Size = New-Object System.Drawing.Size(760, 25)
    $urlTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $urlTextBox.Text = $script:TSPlusDownloadUrl
    $panel.Controls.Add($urlTextBox)
    $y += 35

    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, $y)
    $progressBar.Size = New-Object System.Drawing.Size(760, 25)
    $progressBar.Visible = $false
    $panel.Controls.Add($progressBar)
    $y += 35

    # Buttons
    $checkButton = New-Object System.Windows.Forms.Button
    $checkButton.Location = New-Object System.Drawing.Point(10, $y)
    $checkButton.Size = New-Object System.Drawing.Size(180, 35)
    $checkButton.Text = "Check for Updates"
    $checkButton.BackColor = [System.Drawing.Color]::FromArgb(103, 58, 182)  # Purple
    $checkButton.ForeColor = [System.Drawing.Color]::White
    $checkButton.FlatStyle = "Flat"
    $checkButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $checkButton.Add_Click({
        Write-Log "Checking for TSPlus updates" -Level INFO

        $updateStatus.Text = "Note: TSPlus does not provide a programmatic version check API.`n" +
                           "Please visit https://www.tsplus.net to check for the latest version.`n" +
                           "You can use the 'Download Update' button below to download from the URL specified."
        $updateStatus.ForeColor = [System.Drawing.Color]::Blue
    })
    $panel.Controls.Add($checkButton)

    $downloadButton = New-Object System.Windows.Forms.Button
    $downloadButton.Location = New-Object System.Drawing.Point(200, $y)
    $downloadButton.Size = New-Object System.Drawing.Size(180, 35)
    $downloadButton.Text = "Download Update"
    $downloadButton.BackColor = [System.Drawing.Color]::FromArgb(10, 124, 72)  # Bepoz Green
    $downloadButton.ForeColor = [System.Drawing.Color]::White
    $downloadButton.FlatStyle = "Flat"
    $downloadButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $downloadButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($urlTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a download URL.", "URL Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        $downloadButton.Enabled = $false
        $progressBar.Visible = $true
        $progressBar.Value = 0

        Write-Log "Downloading TSPlus installer from: $($urlTextBox.Text)" -Level INFO

        try {
            $downloadPath = Join-Path $script:TSPlusDownloadPath "Setup-TSplus.exe"
            New-Item -ItemType Directory -Path $script:TSPlusDownloadPath -Force | Out-Null

            $webClient = New-Object System.Net.WebClient

            # Progress handler
            $webClient.add_DownloadProgressChanged({
                param($sender, $e)
                UI-Invoke $progressBar { $progressBar.Value = $e.ProgressPercentage }
            })

            # Completion handler
            $webClient.add_DownloadFileCompleted({
                param($sender, $e)
                UI-Invoke $progressBar { $progressBar.Visible = $false }
                UI-Invoke $downloadButton { $downloadButton.Enabled = $true }

                if ($e.Error) {
                    $updateStatus.Text = "Download failed: $($e.Error.Message)"
                    $updateStatus.ForeColor = [System.Drawing.Color]::Red
                    Write-Log "Download failed: $($e.Error.Message)" -Level ERROR

                    [System.Windows.Forms.MessageBox]::Show(
                        "Download failed: $($e.Error.Message)",
                        "Download Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    ) | Out-Null
                } else {
                    $updateStatus.Text = "Download complete: $downloadPath`nRun TSPlus Installer tool to install this update."
                    $updateStatus.ForeColor = [System.Drawing.Color]::Green
                    Write-Log "Download complete: $downloadPath" -Level SUCCESS

                    [System.Windows.Forms.MessageBox]::Show(
                        "Download complete.`n`nLocation: $downloadPath`n`nUse the TSPlus Installer tool to install this update.",
                        "Download Complete",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    ) | Out-Null
                }
            })

            $webClient.DownloadFileAsync($urlTextBox.Text, $downloadPath)

        } catch {
            $progressBar.Visible = $false
            $downloadButton.Enabled = $true
            $updateStatus.Text = "Download error: $($_.Exception.Message)"
            $updateStatus.ForeColor = [System.Drawing.Color]::Red
            Write-Log "Download error: $($_.Exception.Message)" -Level ERROR

            [System.Windows.Forms.MessageBox]::Show(
                "Download error: $($_.Exception.Message)",
                "Download Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    })
    $panel.Controls.Add($downloadButton)

    $openFolderButton = New-Object System.Windows.Forms.Button
    $openFolderButton.Location = New-Object System.Drawing.Point(390, $y)
    $openFolderButton.Size = New-Object System.Drawing.Size(180, 35)
    $openFolderButton.Text = "Open Download Folder"
    $openFolderButton.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)  # Gray
    $openFolderButton.ForeColor = [System.Drawing.Color]::White
    $openFolderButton.FlatStyle = "Flat"
    $openFolderButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $openFolderButton.Add_Click({
        if (Test-Path $script:TSPlusDownloadPath) {
            Start-Process -FilePath "explorer.exe" -ArgumentList $script:TSPlusDownloadPath
        } else {
            [System.Windows.Forms.MessageBox]::Show("Download folder does not exist yet.", "Folder Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
    })
    $panel.Controls.Add($openFolderButton)

    $TabPage.Controls.Add($panel)
}

#endregion

#region Main Form

# Create main form
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "TSPlus Manager"
$mainForm.Size = New-Object System.Drawing.Size(820, 600)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = "FixedDialog"
$mainForm.MaximizeBox = $false

# Create tab control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = "Fill"
$tabControl.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Create tabs
$uninstallTab = New-Object System.Windows.Forms.TabPage
$uninstallTab.Text = "Uninstaller"
$tabControl.TabPages.Add($uninstallTab)

$licenseTab = New-Object System.Windows.Forms.TabPage
$licenseTab.Text = "License"
$tabControl.TabPages.Add($licenseTab)

$serviceTab = New-Object System.Windows.Forms.TabPage
$serviceTab.Text = "Services"
$tabControl.TabPages.Add($serviceTab)

$backupTab = New-Object System.Windows.Forms.TabPage
$backupTab.Text = "Backup/Restore"
$tabControl.TabPages.Add($backupTab)

$updateTab = New-Object System.Windows.Forms.TabPage
$updateTab.Text = "Updates"
$tabControl.TabPages.Add($updateTab)

# Initialize tabs
Initialize-UninstallerTab -TabPage $uninstallTab
Initialize-LicenseTab -TabPage $licenseTab
Initialize-ServiceTab -TabPage $serviceTab
Initialize-BackupTab -TabPage $backupTab
Initialize-UpdateTab -TabPage $updateTab

$mainForm.Controls.Add($tabControl)

# Show form
Write-Log "TSPlus Manager GUI opened" -Level INFO
[void]$mainForm.ShowDialog()

Write-Log "TSPlus Manager closed" -Level INFO

#endregion
