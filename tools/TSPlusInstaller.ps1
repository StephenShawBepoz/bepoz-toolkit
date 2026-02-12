#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    TSPlus Remote Access Silent Installer

.DESCRIPTION
    WinForms GUI tool that downloads, validates, and silently installs TSPlus Remote Access.

    This tool:
    - Downloads TSPlus Classic installer from configurable URL
    - Validates Authenticode signature before execution (security)
    - Installs silently with real-time progress monitoring
    - Creates required Bepoz directory structure
    - Optionally creates local Windows group for TSPlus users
    - Optionally reboots after successful installation
    - Logs all operations for audit trail

    Typical installation takes 5-10 minutes depending on:
    - Server speed
    - Network bandwidth
    - Antivirus scanning

    Version 2.0 - Migrated to Bepoz Toolkit with comprehensive logging

.PARAMETER None
    This is a GUI tool with no command-line parameters.

.NOTES
    Author: Bepoz Administration Team
    Version: 2.0.0
    PowerShell Version: 5.1+
    Dependencies: BepozLogger.ps1 (optional but recommended)

    SECURITY NOTES:
    - REQUIRES Administrator privileges (installs software)
    - Validates Authenticode signature before running installer
    - Downloads from external URL (ensure network access)
    - Can reboot the computer if user selects that option

    DEFAULT CONFIGURATION:
    - Installer URL: https://dl-files.com/classic/Setup-TSplus.exe
    - Download Directory: C:\ProgramData\TSPlus\Install
    - Expected Install Path: C:\Program Files (x86)\TSplus\UserDesktop\files\AdminTool.exe
    - Required Bepoz Directory: C:\Bepoz\Back Office Cloud - Uploads

    Changelog:
    - 2.0.0: Migrated to Bepoz Toolkit, added BepozLogger integration
    - 1.0.0: Initial standalone version with signature validation

.EXAMPLE
    # Run through Bepoz Toolkit
    # 1. Launch toolkit
    # 2. Select TSPlus category
    # 3. Select "TSPlus Installer"
    # 4. Click "Run Tool"

.EXAMPLE
    # Run standalone (requires admin)
    # powershell.exe -ExecutionPolicy Bypass -File TSPlusInstaller.ps1

.LINK
    https://github.com/StephenShawBepoz/bepoz-toolkit/wiki/TSPlus-Installer
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Console Window Hiding
# Hide the hosting console window (keep the WinForms UI visible).
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeConsole {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
$consoleHandle = [NativeConsole]::GetConsoleWindow()
if ($consoleHandle -ne [IntPtr]::Zero) { [NativeConsole]::ShowWindow($consoleHandle, 0) } # 0 = SW_HIDE
#endregion

#region Module Loading

# Load BepozLogger (optional but highly recommended for this tool)
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

$script:BepozLoggerAvailable = $false
if ($loggerModule) {
    try {
        . $loggerModule.FullName
        $script:CentralLogFile = Initialize-BepozLogger -ToolName "TSPlusInstaller"
        $script:BepozLoggerAvailable = $true
        Write-BepozLogAction "Tool started - TSPlus Remote Access Installer"
        Write-BepozLogAction "Requires Administrator: YES"
        Write-BepozLogAction "Requires Database: NO"
    } catch {
        # Logger failed to load - continue without it
        $script:BepozLoggerAvailable = $false
    }
}

#endregion

#region Configuration

# Installer download configuration
$Script:InstallerUrl = "https://dl-files.com/classic/Setup-TSplus.exe"
$Script:DownloadDir  = Join-Path $env:ProgramData "TSPlus\Install"
$Script:InstallerExe = Join-Path $Script:DownloadDir "Setup-TSplus.exe"

# TSPlus silent installation arguments (Classic setup)
$Script:InstallArgs = @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")

# Post-install validation path (adjust if your environment differs)
$Script:AdminToolPath = "C:\Program Files (x86)\TSplus\UserDesktop\files\AdminTool.exe"

# Required Bepoz directory (created before installation)
$Script:RequiredBepozDir = "C:\Bepoz\Back Office Cloud - Uploads"

#endregion

#region Helper Functions

function Test-IsAdmin {
    <#
    .SYNOPSIS
        Check if current PowerShell session has Administrator privileges
    .OUTPUTS
        Boolean - $true if running as Administrator
    #>
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Tls12 {
    <#
    .SYNOPSIS
        Force TLS 1.2 for secure downloads
    #>
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if ($script:BepozLoggerAvailable) {
            Write-BepozLogAction "TLS 1.2 enabled for secure downloads"
        }
    } catch {
        if ($script:BepozLoggerAvailable) {
            Write-BepozLogError -Message "Failed to enable TLS 1.2" -Exception $_.Exception
        }
    }
}

function Ensure-Directory {
    <#
    .SYNOPSIS
        Create directory if it doesn't exist
    .PARAMETER PathToCreate
        Full path to directory
    .OUTPUTS
        Boolean - $true if successful, $false if failed
    #>
    param([string]$PathToCreate)

    try {
        if (-not (Test-Path -LiteralPath $PathToCreate)) {
            New-Item -Path $PathToCreate -ItemType Directory -Force | Out-Null
            Append-Log ("Created directory: {0}" -f $PathToCreate)
            if ($script:BepozLoggerAvailable) {
                Write-BepozLogAction "Created directory: $PathToCreate"
            }
        } else {
            Append-Log ("Directory already exists: {0}" -f $PathToCreate)
            if ($script:BepozLoggerAvailable) {
                Write-BepozLogAction "Directory already exists: $PathToCreate"
            }
        }
        return $true
    } catch {
        Complete-WithError("Failed to create directory '$PathToCreate': $($_.Exception.Message)")
        if ($script:BepozLoggerAvailable) {
            Write-BepozLogError -Message "Failed to create directory: $PathToCreate" -Exception $_.Exception
        }
        return $false
    }
}

function Ensure-LocalGroup {
    <#
    .SYNOPSIS
        Create local Windows group if it doesn't exist
    .PARAMETER GroupName
        Name of local group to create
    .OUTPUTS
        Boolean - $true if successful or group exists, $false if failed
    #>
    param([string]$GroupName)

    if ([string]::IsNullOrWhiteSpace($GroupName)) { return $true }

    try {
        $existing = [ADSI]"WinNT://$env:COMPUTERNAME/$GroupName,group"
        # Accessing the path will throw if it doesn't exist.
        $null = $existing.Path
        Append-Log ("Local group already exists: {0}" -f $GroupName)
        if ($script:BepozLoggerAvailable) {
            Write-BepozLogAction "Local group already exists: $GroupName"
        }
        return $true
    } catch {
        Append-Log ("Local group not found, creating: {0}" -f $GroupName)
        if ($script:BepozLoggerAvailable) {
            Write-BepozLogAction "Creating local group: $GroupName"
        }

        try {
            $computer = [ADSI]"WinNT://$env:COMPUTERNAME"
            $group = $computer.Create("group", $GroupName)
            $group.SetInfo()
            Append-Log ("Created local group: {0}" -f $GroupName)
            if ($script:BepozLoggerAvailable) {
                Write-BepozLogAction "Successfully created local group: $GroupName"
            }
            return $true
        } catch {
            Complete-WithError("Failed to create local group '$GroupName': $($_.Exception.Message)")
            if ($script:BepozLoggerAvailable) {
                Write-BepozLogError -Message "Failed to create local group: $GroupName" -Exception $_.Exception
            }
            return $false
        }
    }
}

function UI-Invoke {
    <#
    .SYNOPSIS
        Thread-safe UI update helper
    .DESCRIPTION
        Invokes scriptblock on UI thread if needed (for cross-thread operations)
    #>
    param(
        [System.Windows.Forms.Control]$Control,
        [scriptblock]$Action
    )

    if ($Control.InvokeRequired) {
        $Control.Invoke($Action)
    } else {
        & $Action
    }
}

#endregion

#region GUI Construction

$form = New-Object System.Windows.Forms.Form
$form.Text = "TSPlus Remote Access - Download & Silent Install"
$form.Size = New-Object System.Drawing.Size(760, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Title
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "This will download and install TSPlus Remote Access silently."
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(16, 14)
$form.Controls.Add($lblTitle)

# Disclaimer
$lblDisclaimer = New-Object System.Windows.Forms.Label
$lblDisclaimer.Text = "Note: Installation can take up to ~10 minutes depending on server speed and antivirus scanning. Please do not close this window."
$lblDisclaimer.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblDisclaimer.AutoSize = $false
$lblDisclaimer.Size = New-Object System.Drawing.Size(720, 40)
$lblDisclaimer.Location = New-Object System.Drawing.Point(16, 44)
$lblDisclaimer.ForeColor = [System.Drawing.Color]::FromArgb(128, 128, 128)
$form.Controls.Add($lblDisclaimer)

# Installer URL
$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Text = "Installer URL:"
$lblUrl.AutoSize = $true
$lblUrl.Location = New-Object System.Drawing.Point(16, 92)
$form.Controls.Add($lblUrl)

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Text = $Script:InstallerUrl
$txtUrl.Location = New-Object System.Drawing.Point(100, 88)
$txtUrl.Size = New-Object System.Drawing.Size(635, 22)
$txtUrl.ReadOnly = $false
$form.Controls.Add($txtUrl)

# Local Group (optional)
$lblGroup = New-Object System.Windows.Forms.Label
$lblGroup.Text = "Local group (optional):"
$lblGroup.AutoSize = $true
$lblGroup.Location = New-Object System.Drawing.Point(16, 124)
$form.Controls.Add($lblGroup)

$txtGroup = New-Object System.Windows.Forms.TextBox
$txtGroup.Text = ""
$txtGroup.Location = New-Object System.Drawing.Point(150, 120)
$txtGroup.Size = New-Object System.Drawing.Size(585, 22)
$txtGroup.ReadOnly = $false
$form.Controls.Add($txtGroup)

# Progress bar
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(16, 152)
$progress.Size = New-Object System.Drawing.Size(720, 22)
$progress.Minimum = 0
$progress.Maximum = 100
$progress.Value = 0
$form.Controls.Add($progress)

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready."
$lblStatus.AutoSize = $false
$lblStatus.Size = New-Object System.Drawing.Size(720, 18)
$lblStatus.Location = New-Object System.Drawing.Point(16, 180)
$form.Controls.Add($lblStatus)

# Log text box
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.Location = New-Object System.Drawing.Point(16, 204)
$txtLog.Size = New-Object System.Drawing.Size(720, 250)
$form.Controls.Add($txtLog)

# Reboot checkbox
$chkReboot = New-Object System.Windows.Forms.CheckBox
$chkReboot.Text = "Reboot after successful install"
$chkReboot.AutoSize = $true
$chkReboot.Location = New-Object System.Drawing.Point(16, 466)
$form.Controls.Add($chkReboot)

# Start button
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"
$btnStart.Size = New-Object System.Drawing.Size(120, 30)
$btnStart.Location = New-Object System.Drawing.Point(370, 462)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = "Flat"
$btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnStart)

# Copy Log button
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy Log"
$btnCopy.Size = New-Object System.Drawing.Size(120, 30)
$btnCopy.Location = New-Object System.Drawing.Point(500, 462)
$btnCopy.FlatStyle = "Flat"
$form.Controls.Add($btnCopy)

# Close button
$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Size = New-Object System.Drawing.Size(120, 30)
$btnClose.Location = New-Object System.Drawing.Point(616, 462)
$btnClose.FlatStyle = "Flat"
$form.Controls.Add($btnClose)

#endregion

#region Logging Functions

# Local log file (in addition to BepozLogger)
$Script:LogFile = Join-Path $Script:DownloadDir ("tsplus_install_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

function Append-Log {
    <#
    .SYNOPSIS
        Append message to both GUI log and file log
    .DESCRIPTION
        Dual logging: updates GUI textbox AND writes to local log file
        Also integrates with BepozLogger if available
    #>
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message

    # Update GUI log
    UI-Invoke $txtLog { $txtLog.AppendText($line + [Environment]::NewLine) }

    # Write to local file
    try {
        New-Item -ItemType Directory -Path $Script:DownloadDir -Force -ErrorAction SilentlyContinue | Out-Null
        Add-Content -Path $Script:LogFile -Value $line -ErrorAction SilentlyContinue
    } catch {}

    # Log to BepozLogger if available
    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction $Message
    }
}

function Set-Status {
    <#
    .SYNOPSIS
        Update status label (thread-safe)
    #>
    param([string]$Message)
    UI-Invoke $lblStatus { $lblStatus.Text = $Message }
}

#endregion

#region State Variables

$Script:ShouldReboot   = $false
$Script:HadError       = $false
$Script:LastErrorMessage = $null
$Script:WebClient      = $null
$Script:InstallTimer   = $null
$Script:InstallProcess = $null
$Script:InstallStart   = $null

#endregion

#region UI State Functions

function Reset-UiState {
    <#
    .SYNOPSIS
        Re-enable UI controls after operation completes
    #>
    UI-Invoke $progress {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
        $progress.Value = 0
    }
    $btnStart.Enabled = $true
    $txtUrl.Enabled = $true
    $txtGroup.Enabled = $true
    $chkReboot.Enabled = $true

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "UI state reset - controls re-enabled"
    }
}

function Complete-WithError {
    <#
    .SYNOPSIS
        Handle installation failure
    .DESCRIPTION
        Logs error, displays message box, resets UI state
    #>
    param([string]$Message)

    $Script:HadError = $true
    $Script:LastErrorMessage = $Message
    Set-Status "Failed."
    Append-Log ("ERROR: {0}" -f $Message)

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogError -Message "Installation failed: $Message"
    }

    [System.Windows.Forms.MessageBox]::Show(
        "TSPlus install failed:`r`n`r`n$Message`r`n`r`nLog files:`r`n$($Script:LogFile)`r`n$($script:CentralLogFile)",
        "TSPlus Install - Failed",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null

    Reset-UiState
}

function Complete-WithSuccess {
    <#
    .SYNOPSIS
        Handle successful installation
    .DESCRIPTION
        Updates progress, displays success message, optionally reboots
    #>
    UI-Invoke $progress {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
        $progress.Value = 100
    }
    Set-Status "Completed successfully."
    Append-Log "Completed successfully."

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "TSPlus installation completed successfully"
    }

    $logFiles = $Script:LogFile
    if ($script:CentralLogFile) {
        $logFiles += "`r`n$($script:CentralLogFile)"
    }

    $msg = "TSPlus install completed successfully.`r`n`r`nLog files:`r`n$logFiles`r`n`r`nA reboot is recommended."
    [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "TSPlus Install - Success",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null

    if ($Script:ShouldReboot) {
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Reboot now?",
            "TSPlus Install",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
            Append-Log "Rebooting system as requested by user..."
            if ($script:BepozLoggerAvailable) {
                Write-BepozLogAction "System reboot initiated by user"
            }
            Restart-Computer -Force
        } else {
            Append-Log "Reboot skipped by user."
            if ($script:BepozLoggerAvailable) {
                Write-BepozLogAction "User declined reboot"
            }
        }
    }

    Reset-UiState
}

#endregion

#region Installation Functions

function Post-InstallCheck {
    <#
    .SYNOPSIS
        Verify TSPlus installed correctly by checking for AdminTool.exe
    #>
    Set-Status "Final checks..."
    Append-Log "Checking AdminTool path: $Script:AdminToolPath"

    if (-not (Test-Path $Script:AdminToolPath)) {
        Append-Log "Warning: AdminTool.exe not found at expected path."
        Append-Log "TSPlus may be installed to a different path on this machine, or the install did not complete as expected."

        if ($script:BepozLoggerAvailable) {
            Write-BepozLogAction "WARNING: AdminTool.exe not found at $Script:AdminToolPath"
        }
    } else {
        Append-Log "AdminTool.exe found - installation validated."

        if ($script:BepozLoggerAvailable) {
            Write-BepozLogAction "Post-install check passed: AdminTool.exe exists"
        }
    }
}

function Start-Install {
    <#
    .SYNOPSIS
        Launch TSPlus silent installation
    .DESCRIPTION
        Starts installer process with silent flags, monitors progress with timer
    #>
    UI-Invoke $progress {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        $progress.MarqueeAnimationSpeed = 30
    }
    Set-Status "Installing TSPlus... (this can take up to ~10 minutes)"
    Append-Log ("Installing silently: {0} {1}" -f $Script:InstallerExe, ($Script:InstallArgs -join " "))

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "Starting silent installation: $Script:InstallerExe $($Script:InstallArgs -join ' ')"
    }

    $Script:InstallStart = Get-Date
    try {
        $Script:InstallProcess = Start-Process -FilePath $Script:InstallerExe -ArgumentList $Script:InstallArgs -PassThru

        if ($script:BepozLoggerAvailable) {
            Write-BepozLogAction "Installation process started (PID: $($Script:InstallProcess.Id))"
        }
    } catch {
        Complete-WithError($_.Exception.Message)
        if ($script:BepozLoggerAvailable) {
            Write-BepozLogError -Message "Failed to start installer process" -Exception $_.Exception
        }
        return
    }

    # Create timer to monitor installation progress
    if ($Script:InstallTimer) { $Script:InstallTimer.Stop(); $Script:InstallTimer.Dispose() }
    $Script:InstallTimer = New-Object System.Windows.Forms.Timer
    $Script:InstallTimer.Interval = 1000  # Check every 1 second
    $Script:InstallTimer.add_Tick({
        try {
            if (-not $Script:InstallProcess.HasExited) {
                # Still running - update elapsed time
                $elapsedText = if ($Script:InstallStart) {
                    ((Get-Date) - $Script:InstallStart).ToString("mm':'ss")
                } else { "00:00" }
                Set-Status ("Installing TSPlus... elapsed {0} (up to ~10 minutes is normal)" -f $elapsedText)
            } else {
                # Process completed
                $Script:InstallTimer.Stop()
                $Script:InstallTimer.Dispose()
                $Script:InstallTimer = $null

                $exitCode = $Script:InstallProcess.ExitCode
                Append-Log ("Installer exit code: {0}" -f $exitCode)

                if ($script:BepozLoggerAvailable) {
                    Write-BepozLogAction "Installer process completed with exit code: $exitCode"
                }

                if ($exitCode -ne 0) {
                    Complete-WithError("Installer returned non-zero exit code ($exitCode).")
                    return
                }

                Post-InstallCheck
                Complete-WithSuccess
            }
        } catch {
            Append-Log ("Timer error: {0}" -f $_.Exception.Message)
            if ($Script:InstallTimer) { $Script:InstallTimer.Stop(); $Script:InstallTimer.Dispose(); $Script:InstallTimer = $null }
            Complete-WithError("Unexpected error during install monitoring: $($_.Exception.Message)")
        }
    })
    $Script:InstallTimer.Start()
}

function Test-InstallerSignature {
    <#
    .SYNOPSIS
        Validate Authenticode signature of downloaded installer
    .DESCRIPTION
        Security check: ensures installer is properly signed before execution
        Refuses to run unsigned or invalidly signed installers
    .OUTPUTS
        Boolean - $true if signature is valid, $false otherwise
    #>
    Set-Status "Validating installer signature..."
    Append-Log "Validating Authenticode signature..."

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "Starting Authenticode signature validation"
    }

    try {
        $sig = Get-AuthenticodeSignature -FilePath $Script:InstallerExe
        Append-Log ("Signature status: {0}" -f $sig.Status)

        if ($sig.Status -ne "Valid") {
            Complete-WithError("Installer signature is not valid (Status: $($sig.Status)). Refusing to execute for security reasons.")

            if ($script:BepozLoggerAvailable) {
                Write-BepozLogError -Message "SECURITY: Invalid installer signature - Status: $($sig.Status)"
            }
            return $false
        }

        if ($sig.SignerCertificate) {
            Append-Log ("Signed by: {0}" -f $sig.SignerCertificate.Subject)
            Append-Log ("Thumbprint: {0}" -f $sig.SignerCertificate.Thumbprint)

            if ($script:BepozLoggerAvailable) {
                Write-BepozLogAction "Signature valid - Signed by: $($sig.SignerCertificate.Subject)"
                Write-BepozLogAction "Certificate thumbprint: $($sig.SignerCertificate.Thumbprint)"
            }
        }

        return $true
    } catch {
        Complete-WithError("Signature validation failed: $($_.Exception.Message)")

        if ($script:BepozLoggerAvailable) {
            Write-BepozLogError -Message "Signature validation error" -Exception $_.Exception
        }
        return $false
    }
}

function Start-Download {
    <#
    .SYNOPSIS
        Download TSPlus installer from URL with progress tracking
    .DESCRIPTION
        Downloads installer using WebClient with async progress updates
        Validates signature after download completes
    #>
    param(
        [string]$Url,
        [bool]$Reboot
    )

    Ensure-Tls12
    $Script:ShouldReboot = $Reboot

    New-Item -ItemType Directory -Path $Script:DownloadDir -Force | Out-Null

    Append-Log "Starting TSPlus deployment."
    Append-Log "Download directory: $Script:DownloadDir"
    Append-Log "Installer URL: $Url"
    Append-Log "Reboot after install: $Reboot"

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "Download initiated from URL: $Url"
        Write-BepozLogAction "Target directory: $Script:DownloadDir"
        Write-BepozLogAction "Auto-reboot: $Reboot"
    }

    UI-Invoke $progress {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
        $progress.Value = 0
    }
    Set-Status "Downloading installer..."

    # Clean up any existing WebClient
    if ($Script:WebClient) { $Script:WebClient.Dispose() }
    $Script:WebClient = New-Object System.Net.WebClient

    # Download progress event
    $Script:WebClient.add_DownloadProgressChanged({
        param($s, $eventArgs)
        $pct = [int]$eventArgs.ProgressPercentage
        UI-Invoke $progress {
            $val = [Math]::Max(0, [Math]::Min(100, $pct))
            $progress.Value = $val
        }
        Set-Status ("Downloading installer... {0}%" -f $pct)
    })

    # Download completed event
    $Script:WebClient.add_DownloadFileCompleted({
        param($s, $eventArgs)
        try {
            if ($eventArgs.Cancelled) {
                Complete-WithError("Download was cancelled.")
                if ($script:BepozLoggerAvailable) {
                    Write-BepozLogAction "Download cancelled by user or system"
                }
                return
            }
            if ($eventArgs.Error) {
                Complete-WithError($eventArgs.Error.Message)
                if ($script:BepozLoggerAvailable) {
                    Write-BepozLogError -Message "Download failed" -Exception $eventArgs.Error
                }
                return
            }

            Append-Log "Download completed."
            if ($script:BepozLoggerAvailable) {
                $fileSize = (Get-Item $Script:InstallerExe).Length
                Write-BepozLogAction "Download completed - File size: $([math]::Round($fileSize / 1MB, 2)) MB"
            }

            # Validate signature before running
            if (-not (Test-InstallerSignature)) { return }

            Start-Install
        } catch {
            Complete-WithError($_.Exception.Message)
        } finally {
            if ($Script:WebClient) { $Script:WebClient.Dispose(); $Script:WebClient = $null }
        }
    })

    # Start async download
    try {
        if (Test-Path $Script:InstallerExe) {
            Remove-Item $Script:InstallerExe -Force
            Append-Log "Removed existing installer file"
        }
        $Script:WebClient.DownloadFileAsync([Uri]$Url, $Script:InstallerExe)
    } catch {
        Complete-WithError($_.Exception.Message)
        if ($script:BepozLoggerAvailable) {
            Write-BepozLogError -Message "Failed to start download" -Exception $_.Exception
        }
    }
}

#endregion

#region Event Handlers

# Close button
$btnClose.Add_Click({
    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "User clicked Close button"
    }
    $form.Close()
})

# Copy Log button
$btnCopy.Add_Click({
    UI-Invoke $txtLog {
        if ($txtLog.TextLength -gt 0) {
            [System.Windows.Forms.Clipboard]::SetText($txtLog.Text)
            Append-Log "Log copied to clipboard"
        }
    }
})

# Start button
$btnStart.Add_Click({
    # Verify admin privileges
    if (-not (Test-IsAdmin)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please run PowerShell as Administrator.`n`nThis tool requires Administrator privileges to install software.",
            "Admin privileges required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null

        if ($script:BepozLoggerAvailable) {
            Write-BepozLogError -Message "User attempted to run without Administrator privileges"
        }
        return
    }

    # Validate URL
    $url = $txtUrl.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($url)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a valid URL.", "Missing URL") | Out-Null
        return
    }

    $groupName = $txtGroup.Text.Trim()

    # Disable UI during operation
    $btnStart.Enabled = $false
    $txtUrl.Enabled = $false
    $txtGroup.Enabled = $false
    $chkReboot.Enabled = $false
    $progress.Value = 0
    Set-Status "Starting..."
    Append-Log "----------------------------------------"
    Append-Log "User clicked Start."
    Append-Log "User: $env:USERNAME"
    Append-Log "Computer: $env:COMPUTERNAME"

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "Installation initiated by user"
        Write-BepozLogAction "Computer: $env:COMPUTERNAME"
        Write-BepozLogAction "User: $env:USERNAME"
        Write-BepozLogAction "URL: $url"
        if ($groupName) {
            Write-BepozLogAction "Local group requested: $groupName"
        }
    }

    # Create required Bepoz directory
    if (-not (Ensure-Directory -PathToCreate $Script:RequiredBepozDir)) { return }

    # Create optional local group
    if (-not (Ensure-LocalGroup -GroupName $groupName)) { return }

    # Start download and installation
    Start-Download -Url $url -Reboot $chkReboot.Checked
})

# Form shown event
$form.Add_Shown({
    Append-Log "TSPlus Remote Access Installer v2.0"
    Append-Log "=========================================="
    Append-Log "Ready to download and install TSPlus."
    Append-Log "Required: Administrator privileges"
    Append-Log "Expected duration: 5-10 minutes"
    Append-Log ""
    Append-Log "Configuration:"
    Append-Log "  Installer URL: $Script:InstallerUrl"
    Append-Log "  Download Dir: $Script:DownloadDir"
    Append-Log "  Required Dir: $Script:RequiredBepozDir"
    Append-Log "  Install Args: $($Script:InstallArgs -join ' ')"
    Append-Log ""
    Append-Log "Local log file: $Script:LogFile"
    if ($script:CentralLogFile) {
        Append-Log "Central log file: $script:CentralLogFile"
    }
    Append-Log ""
    Append-Log "Click 'Start' to begin."

    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "GUI displayed to user - Ready for installation"
    }
})

# Form closing event
$form.Add_FormClosed({
    if ($script:BepozLoggerAvailable) {
        Write-BepozLogAction "Tool closed by user"
    }
})

#endregion

#region Launch

# Show the form
[void]$form.ShowDialog()

# Cleanup
if ($Script:WebClient) { $Script:WebClient.Dispose() }
if ($Script:InstallTimer) { $Script:InstallTimer.Stop(); $Script:InstallTimer.Dispose() }

#endregion
