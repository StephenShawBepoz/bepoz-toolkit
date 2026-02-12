<#
.SYNOPSIS
    Bepoz Toolkit GUI - Windows Forms interface for PowerShell tools
.DESCRIPTION
    Graphical user interface for the Bepoz Toolkit
    - Windows Forms GUI (no command-line interaction needed)
    - Auto-updates itself on every run
    - Downloads tools on-demand from GitHub
    - Visual category and tool selection
    - Progress indicators and log display
    - Full logging and error handling
.PARAMETER GitHubOrg
    GitHub organization/user name
.PARAMETER GitHubRepo
    GitHub repository name
.PARAMETER Branch
    Git branch to use (default: main)
.NOTES
    Version: 1.3.0
    Author: Bepoz Support Team
    Last Updated: 2026-02-11
    Requires: PowerShell 5.1+, Windows Forms

    Changes in v1.3.0:
    - Fixed View Logs button rendering (was showing as 2 lines instead of box)
    - Added automatic module downloading for tools requiring database access
    - BepozDbCore and BepozLogger modules now downloaded before tool execution
    - Tools with requiresDatabase flag now work properly from GUI

    Changes in v1.2.0:
    - Added official Bepoz color palette to all buttons
    - Added View Logs button (purple)
    - Added View Documentation button (purple)
    - Run Tool button now uses Bepoz green
    - All buttons have Bepoz light blue hover states
#>

[CmdletBinding()]
param(
    [string]$GitHubOrg = "StephenShawBepoz",
    [string]$GitHubRepo = "bepoz-toolkit",
    [string]$Branch = "main"
)

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Configuration
$Script:Version = "1.3.0"
$Script:TempDir = Join-Path $env:TEMP "BepozToolkit_$([guid]::NewGuid().ToString().Substring(0,8))"
$Script:LogFile = Join-Path $env:TEMP "BepozToolkit.log"
$Script:BaseUrl = "https://raw.githubusercontent.com/$GitHubOrg/$GitHubRepo/$Branch"
$Script:DownloadedFiles = @()
$Script:Manifest = $null
$Script:SelectedCategory = $null
$Script:SelectedTool = $null
#endregion

#region Logging Functions
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $logEntry = "$timestamp | $user | [$Level] $Message"

    # Write to log file
    try {
        Add-Content -Path $Script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
    } catch {
        # Silent fail on logging errors
    }

    # Update GUI log if available
    if ($Script:LogTextBox) {
        $Script:LogTextBox.AppendText("$logEntry`r`n")
        $Script:LogTextBox.SelectionStart = $Script:LogTextBox.Text.Length
        $Script:LogTextBox.ScrollToCaret()
    }
}
#endregion

#region Cleanup Functions
function Register-TempFile {
    param([string]$FilePath)
    $Script:DownloadedFiles += $FilePath
}

function Remove-TempFiles {
    Write-Log "Cleaning up temporary files..." -Level INFO

    foreach ($file in $Script:DownloadedFiles) {
        if (Test-Path $file) {
            try {
                Remove-Item $file -Force -ErrorAction Stop
            } catch {
                Write-Log "Failed to delete: $file" -Level WARN
            }
        }
    }

    if (Test-Path $Script:TempDir) {
        try {
            Remove-Item $Script:TempDir -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Log "Failed to delete temp directory" -Level WARN
        }
    }
}
#endregion

#region Download Functions
function Get-FileFromGitHub {
    param(
        [string]$RelativePath,
        [string]$Destination
    )

    $url = "$Script:BaseUrl/$RelativePath"
    Write-Log "Downloading: $url" -Level INFO

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
        $ProgressPreference = 'Continue'

        if (-not (Test-Path $Destination)) {
            throw "File not found after download"
        }

        Register-TempFile -FilePath $Destination
        Write-Log "Downloaded successfully: $Destination" -Level SUCCESS
        return $true
    } catch {
        Write-Log "Download failed: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}
#endregion

#region Auto-Update Functions
function Test-BootstrapUpdate {
    Write-Log "Checking for bootstrap updates..." -Level INFO

    try {
        $manifestPath = Join-Path $Script:TempDir "manifest.json"
        $downloadSuccess = Get-FileFromGitHub -RelativePath "manifest.json" -Destination $manifestPath

        if (-not $downloadSuccess) {
            Write-Log "Could not check for updates" -Level WARN
            return $false
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $remoteVersion = [version]$manifest.bootstrap.version
        $currentVersion = [version]$Script:Version

        if ($remoteVersion -gt $currentVersion) {
            Write-Log "Update available: v$currentVersion -> v$remoteVersion" -Level WARN
            return $manifest.bootstrap.file -replace 'Invoke-BepozToolkit\.ps1', 'Invoke-BepozToolkit-GUI.ps1'
        } else {
            Write-Log "Bootstrap is up to date (v$currentVersion)" -Level SUCCESS
            return $false
        }
    } catch {
        Write-Log "Update check failed: $($_.Exception.Message)" -Level WARN
        return $false
    }
}
#endregion

#region GUI Functions
function Initialize-Manifest {
    Write-Log "Loading manifest from GitHub..." -Level INFO

    $manifestPath = Join-Path $Script:TempDir "manifest.json"
    if (-not (Test-Path $manifestPath)) {
        $downloadSuccess = Get-FileFromGitHub -RelativePath "manifest.json" -Destination $manifestPath
        if (-not $downloadSuccess) {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to download manifest from GitHub.`n`nCheck internet connection and repository URL.",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
    }

    try {
        $Script:Manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-Log "Manifest loaded: $($Script:Manifest.tools.Count) tools in $($Script:Manifest.categories.Count) categories" -Level SUCCESS
        return $true
    } catch {
        Write-Log "Failed to parse manifest: $($_.Exception.Message)" -Level ERROR
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to parse manifest.json.`n`nError: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
}

function Populate-Categories {
    $Script:CategoryListBox.Items.Clear()

    foreach ($category in $Script:Manifest.categories) {
        [void]$Script:CategoryListBox.Items.Add($category)
    }

    if ($Script:CategoryListBox.Items.Count -gt 0) {
        $Script:CategoryListBox.SelectedIndex = 0
    }
}

function Populate-Tools {
    param($Category)

    $Script:ToolListBox.Items.Clear()
    $Script:ToolDescriptionLabel.Text = "Select a tool to see details"
    $Script:RunButton.Enabled = $false
    $Script:ViewDocsButton.Enabled = $false

    if ($null -eq $Category) { return }

    $tools = $Script:Manifest.tools | Where-Object { $_.category -eq $Category.id }

    foreach ($tool in $tools) {
        [void]$Script:ToolListBox.Items.Add($tool)
    }

    if ($Script:ToolListBox.Items.Count -eq 0) {
        $Script:ToolDescriptionLabel.Text = "No tools available in this category yet"
    }
}

function Update-ToolDetails {
    param($Tool)

    if ($null -eq $Tool) {
        $Script:ToolDescriptionLabel.Text = "Select a tool to see details"
        $Script:RunButton.Enabled = $false
        $Script:ViewDocsButton.Enabled = $false
        return
    }

    $details = @"
$($Tool.name) v$($Tool.version)

$($Tool.description)

Author: $($Tool.author)
Category: $($Tool.category)
"@

    if ($Tool.requiresAdmin) {
        $details += "`n⚠ Requires Administrator"
    }
    if ($Tool.requiresDatabase) {
        $details += "`n🗄 Requires Database Access"
    }
    if ($Tool.documentation) {
        $details += "`n`n📚 Documentation Available"
    }

    $Script:ToolDescriptionLabel.Text = $details
    $Script:RunButton.Enabled = $true
    $Script:ViewDocsButton.Enabled = ($null -ne $Tool.documentation)
    $Script:SelectedTool = $Tool
}

function Invoke-SelectedTool {
    if ($null -eq $Script:SelectedTool) { return }

    $tool = $Script:SelectedTool

    # Confirm execution
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Run tool: $($tool.name) v$($tool.version)?`n`n$($tool.description)",
        "Confirm Execution",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "User cancelled tool execution" -Level WARN
        return
    }

    Write-Log "User selected tool: $($tool.name) v$($tool.version)" -Level INFO

    # Disable UI during execution
    $Script:RunButton.Enabled = $false
    $Script:RefreshButton.Enabled = $false
    $Script:CategoryListBox.Enabled = $false
    $Script:ToolListBox.Enabled = $false
    $Script:StatusLabel.Text = "Preparing tool..."
    $Script:MainForm.Refresh()

    # Download required modules if tool needs database access
    if ($tool.requiresDatabase) {
        Write-Log "Tool requires database access - downloading modules..." -Level INFO
        $Script:StatusLabel.Text = "Downloading required modules..."
        $Script:MainForm.Refresh()

        # Download BepozDbCore module (required for database access)
        $dbCoreModule = Join-Path $env:TEMP "BepozDbCore.ps1"
        $dbCoreSuccess = Get-FileFromGitHub -RelativePath $Script:Manifest.modules.BepozDbCore.file -Destination $dbCoreModule

        if (-not $dbCoreSuccess) {
            Write-Log "Failed to download BepozDbCore module" -Level ERROR
            $Script:StatusLabel.Text = "Ready"
            $Script:RunButton.Enabled = $true
            $Script:RefreshButton.Enabled = $true
            $Script:CategoryListBox.Enabled = $true
            $Script:ToolListBox.Enabled = $true
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to download required database module (BepozDbCore.ps1).`n`nThe tool cannot run without database access.",
                "Module Download Failed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }

        # Download BepozLogger module (optional but recommended)
        $loggerModule = Join-Path $env:TEMP "BepozLogger.ps1"
        $loggerSuccess = Get-FileFromGitHub -RelativePath $Script:Manifest.modules.BepozLogger.file -Destination $loggerModule

        if ($loggerSuccess) {
            Write-Log "Downloaded BepozLogger module" -Level SUCCESS
        } else {
            Write-Log "BepozLogger module download failed (optional - continuing)" -Level WARN
        }

        Write-Log "Required modules downloaded successfully" -Level SUCCESS
    }

    # Download tool
    $Script:StatusLabel.Text = "Downloading tool..."
    $Script:MainForm.Refresh()
    $toolPath = Join-Path $Script:TempDir (Split-Path $tool.file -Leaf)
    $downloadSuccess = Get-FileFromGitHub -RelativePath $tool.file -Destination $toolPath

    if (-not $downloadSuccess) {
        Write-Log "Failed to download tool" -Level ERROR
        $Script:StatusLabel.Text = "Ready"
        $Script:RunButton.Enabled = $true
        $Script:RefreshButton.Enabled = $true
        $Script:CategoryListBox.Enabled = $true
        $Script:ToolListBox.Enabled = $true
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to download tool from GitHub.",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }

    # Execute tool
    Write-Log "Executing tool: $toolPath" -Level INFO
    $Script:StatusLabel.Text = "Running tool..."
    $Script:MainForm.Refresh()

    try {
        # Create new PowerShell process to run tool
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$toolPath`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $false  # Show console window for tool output

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()

        Write-Log "Tool process started (PID: $($process.Id))" -Level INFO
        $Script:StatusLabel.Text = "Tool is running (see console window)..."

        # Capture output and errors
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()

        # Wait for process to complete
        $process.WaitForExit()

        $exitCode = $process.ExitCode
        Write-Log "Tool completed with exit code: $exitCode" -Level $(if ($exitCode -eq 0) { 'SUCCESS' } else { 'WARN' })

        # Log captured output
        if ($stdout) {
            Write-Log "Tool output: $stdout" -Level INFO
        }
        if ($stderr) {
            Write-Log "Tool errors: $stderr" -Level ERROR
        }

        if ($exitCode -eq 0) {
            $Script:StatusLabel.Text = "Tool completed successfully"
            [System.Windows.Forms.MessageBox]::Show(
                "Tool completed successfully!",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        } else {
            $Script:StatusLabel.Text = "Tool completed with errors"
            $errorMsg = "Tool completed with exit code: $exitCode"
            if ($stderr) {
                $errorMsg += "`n`nError details:`n$stderr"
            }
            [System.Windows.Forms.MessageBox]::Show(
                $errorMsg,
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }

    } catch {
        Write-Log "Tool execution failed: $($_.Exception.Message)" -Level ERROR
        $Script:StatusLabel.Text = "Tool execution failed"
        [System.Windows.Forms.MessageBox]::Show(
            "Tool execution failed:`n`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    } finally {
        # Re-enable UI
        $Script:StatusLabel.Text = "Ready"
        $Script:RunButton.Enabled = $true
        $Script:RefreshButton.Enabled = $true
        $Script:CategoryListBox.Enabled = $true
        $Script:ToolListBox.Enabled = $true
    }
}

function Open-ToolDocumentation {
    if ($null -eq $Script:SelectedTool) { return }

    $tool = $Script:SelectedTool
    $docUrl = $tool.documentation

    if ([string]::IsNullOrWhiteSpace($docUrl)) {
        Write-Log "No documentation available for: $($tool.name)" -Level WARN
        [System.Windows.Forms.MessageBox]::Show(
            "No documentation is available for this tool.",
            "Documentation Not Available",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }

    try {
        Write-Log "Opening documentation for $($tool.name): $docUrl" -Level INFO
        $Script:StatusLabel.Text = "Opening documentation..."

        # Determine if it's a URL or file path
        if ($docUrl -match '^https?://') {
            # It's a URL - open in default browser
            Start-Process $docUrl
            Write-Log "Opened documentation URL in browser" -Level SUCCESS
        }
        elseif (Test-Path $docUrl) {
            # It's a local file path - open with default application
            Start-Process $docUrl
            Write-Log "Opened documentation file: $docUrl" -Level SUCCESS
        }
        else {
            # Path doesn't exist - show error
            Write-Log "Documentation path not found: $docUrl" -Level ERROR
            [System.Windows.Forms.MessageBox]::Show(
                "Documentation file not found:`n`n$docUrl`n`nThis may be a broken link or the file may have been moved.",
                "Documentation Not Found",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        }

        $Script:StatusLabel.Text = "Ready"
    }
    catch {
        Write-Log "Failed to open documentation: $($_.Exception.Message)" -Level ERROR
        $Script:StatusLabel.Text = "Failed to open documentation"
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to open documentation:`n`n$($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}
#endregion

#region Main Form
function Show-ToolkitGUI {
    # Create temp directory
    if (-not (Test-Path $Script:TempDir)) {
        New-Item -Path $Script:TempDir -ItemType Directory -Force | Out-Null
    }

    Write-Log "Toolkit GUI started" -Level INFO

    # Check for updates
    $updateFile = Test-BootstrapUpdate
    if ($updateFile) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "A new version of the toolkit is available.`n`nWould you like to update now?",
            "Update Available",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Write-Log "Downloading update..." -Level INFO
            $newBootstrapPath = Join-Path $Script:TempDir "Invoke-BepozToolkit-GUI-New.ps1"
            $downloadSuccess = Get-FileFromGitHub -RelativePath $updateFile -Destination $newBootstrapPath

            if ($downloadSuccess) {
                Write-Log "Update downloaded - restarting..." -Level SUCCESS
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$newBootstrapPath`" -GitHubOrg $GitHubOrg -GitHubRepo $GitHubRepo -Branch $Branch"
                exit 0
            } else {
                Write-Log "Update download failed - continuing with current version" -Level WARN
            }
        }
    }

    # Load manifest
    if (-not (Initialize-Manifest)) {
        return
    }

    # Create main form
    $Script:MainForm = New-Object System.Windows.Forms.Form
    $Script:MainForm.Text = "Bepoz Toolkit v$Script:Version"
    $Script:MainForm.BackColor = [System.Drawing.Color]::White
    $Script:MainForm.Size = New-Object System.Drawing.Size(900, 600)
    $Script:MainForm.StartPosition = "CenterScreen"
    $Script:MainForm.FormBorderStyle = "FixedDialog"
    $Script:MainForm.MaximizeBox = $false

    # Category panel (left side)
    $categoryPanel = New-Object System.Windows.Forms.Panel
    $categoryPanel.Location = New-Object System.Drawing.Point(10, 10)
    $categoryPanel.Size = New-Object System.Drawing.Size(250, 480)
    $categoryPanel.BorderStyle = "FixedSingle"

    $categoryLabel = New-Object System.Windows.Forms.Label
    $categoryLabel.Text = "Categories"
    $categoryLabel.Location = New-Object System.Drawing.Point(5, 5)
    $categoryLabel.Size = New-Object System.Drawing.Size(240, 20)
    $categoryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $categoryPanel.Controls.Add($categoryLabel)

    $Script:CategoryListBox = New-Object System.Windows.Forms.ListBox
    $Script:CategoryListBox.Location = New-Object System.Drawing.Point(5, 30)
    $Script:CategoryListBox.Size = New-Object System.Drawing.Size(240, 445)
    $Script:CategoryListBox.DisplayMember = "name"
    $Script:CategoryListBox.Add_SelectedIndexChanged({
        $Script:SelectedCategory = $Script:CategoryListBox.SelectedItem
        Populate-Tools -Category $Script:SelectedCategory
    })
    $categoryPanel.Controls.Add($Script:CategoryListBox)

    # Tool panel (center)
    $toolPanel = New-Object System.Windows.Forms.Panel
    $toolPanel.Location = New-Object System.Drawing.Point(270, 10)
    $toolPanel.Size = New-Object System.Drawing.Size(300, 480)
    $toolPanel.BorderStyle = "FixedSingle"

    $toolLabel = New-Object System.Windows.Forms.Label
    $toolLabel.Text = "Tools"
    $toolLabel.Location = New-Object System.Drawing.Point(5, 5)
    $toolLabel.Size = New-Object System.Drawing.Size(290, 20)
    $toolLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $toolPanel.Controls.Add($toolLabel)

    $Script:ToolListBox = New-Object System.Windows.Forms.ListBox
    $Script:ToolListBox.Location = New-Object System.Drawing.Point(5, 30)
    $Script:ToolListBox.Size = New-Object System.Drawing.Size(290, 445)
    $Script:ToolListBox.DisplayMember = "name"
    $Script:ToolListBox.Add_SelectedIndexChanged({
        Update-ToolDetails -Tool $Script:ToolListBox.SelectedItem
    })
    $Script:ToolListBox.Add_DoubleClick({
        Invoke-SelectedTool
    })
    $toolPanel.Controls.Add($Script:ToolListBox)

    # Details panel (right side)
    $detailsPanel = New-Object System.Windows.Forms.Panel
    $detailsPanel.Location = New-Object System.Drawing.Point(580, 10)
    $detailsPanel.Size = New-Object System.Drawing.Size(300, 480)
    $detailsPanel.BorderStyle = "FixedSingle"

    $detailsLabel = New-Object System.Windows.Forms.Label
    $detailsLabel.Text = "Tool Details"
    $detailsLabel.Location = New-Object System.Drawing.Point(5, 5)
    $detailsLabel.Size = New-Object System.Drawing.Size(290, 20)
    $detailsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $detailsPanel.Controls.Add($detailsLabel)

    $Script:ToolDescriptionLabel = New-Object System.Windows.Forms.Label
    $Script:ToolDescriptionLabel.Location = New-Object System.Drawing.Point(5, 30)
    $Script:ToolDescriptionLabel.Size = New-Object System.Drawing.Size(290, 330)
    $Script:ToolDescriptionLabel.Text = "Select a tool to see details"
    $Script:ToolDescriptionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $detailsPanel.Controls.Add($Script:ToolDescriptionLabel)

    $Script:ViewDocsButton = New-Object System.Windows.Forms.Button
    $Script:ViewDocsButton.Location = New-Object System.Drawing.Point(5, 370)
    $Script:ViewDocsButton.Size = New-Object System.Drawing.Size(290, 40)
    $Script:ViewDocsButton.Text = "📚 View Documentation"
    $Script:ViewDocsButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $Script:ViewDocsButton.BackColor = [System.Drawing.Color]::FromArgb(103, 58, 182)  # Bepoz Purple (#673AB6)
    $Script:ViewDocsButton.ForeColor = [System.Drawing.Color]::White
    $Script:ViewDocsButton.FlatStyle = "Flat"
    $Script:ViewDocsButton.FlatAppearance.BorderSize = 0
    $Script:ViewDocsButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(138, 168, 221)  # Bepoz Light Blue (#8AA8DD)
    $Script:ViewDocsButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Script:ViewDocsButton.Enabled = $false
    $Script:ViewDocsButton.Add_Click({ Open-ToolDocumentation })
    $detailsPanel.Controls.Add($Script:ViewDocsButton)

    $Script:RunButton = New-Object System.Windows.Forms.Button
    $Script:RunButton.Location = New-Object System.Drawing.Point(5, 420)
    $Script:RunButton.Size = New-Object System.Drawing.Size(290, 50)
    $Script:RunButton.Text = "Run Tool"
    $Script:RunButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $Script:RunButton.BackColor = [System.Drawing.Color]::FromArgb(10, 124, 72)  # Bepoz Green (#0A7C48)
    $Script:RunButton.ForeColor = [System.Drawing.Color]::White
    $Script:RunButton.FlatStyle = "Flat"
    $Script:RunButton.FlatAppearance.BorderSize = 0
    $Script:RunButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(138, 168, 221)  # Bepoz Light Blue (#8AA8DD)
    $Script:RunButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Script:RunButton.Enabled = $false
    $Script:RunButton.Add_Click({ Invoke-SelectedTool })
    $detailsPanel.Controls.Add($Script:RunButton)

    # Log panel (bottom)
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Location = New-Object System.Drawing.Point(10, 500)
    $logPanel.Size = New-Object System.Drawing.Size(870, 30)

    $Script:StatusLabel = New-Object System.Windows.Forms.Label
    $Script:StatusLabel.Location = New-Object System.Drawing.Point(0, 5)
    $Script:StatusLabel.Size = New-Object System.Drawing.Size(470, 20)
    $Script:StatusLabel.Text = "Ready"
    $Script:StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $logPanel.Controls.Add($Script:StatusLabel)

    $Script:RefreshButton = New-Object System.Windows.Forms.Button
    $Script:RefreshButton.Location = New-Object System.Drawing.Point(610, 0)
    $Script:RefreshButton.Size = New-Object System.Drawing.Size(120, 30)
    $Script:RefreshButton.Text = "Refresh"
    $Script:RefreshButton.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)  # Bepoz Gray (#808080)
    $Script:RefreshButton.ForeColor = [System.Drawing.Color]::White
    $Script:RefreshButton.FlatStyle = "Flat"
    $Script:RefreshButton.FlatAppearance.BorderSize = 0
    $Script:RefreshButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(138, 168, 221)  # Bepoz Light Blue
    $Script:RefreshButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $Script:RefreshButton.Add_Click({
        Write-Log "Refreshing manifest..." -Level INFO
        Remove-Item (Join-Path $Script:TempDir "manifest.json") -Force -ErrorAction SilentlyContinue
        if (Initialize-Manifest) {
            Populate-Categories
            Write-Log "Manifest refreshed" -Level SUCCESS
        }
    })
    $logPanel.Controls.Add($Script:RefreshButton)

    $viewLogsButton = New-Object System.Windows.Forms.Button
    $viewLogsButton.Location = New-Object System.Drawing.Point(480, 0)
    $viewLogsButton.Size = New-Object System.Drawing.Size(120, 30)
    $viewLogsButton.Text = "View Logs"
    $viewLogsButton.BackColor = [System.Drawing.Color]::FromArgb(103, 58, 182)  # Bepoz Purple (#673AB6)
    $viewLogsButton.ForeColor = [System.Drawing.Color]::White
    $viewLogsButton.FlatStyle = "Flat"
    $viewLogsButton.FlatAppearance.BorderSize = 0
    $viewLogsButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(138, 168, 221)  # Bepoz Light Blue
    $viewLogsButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $viewLogsButton.Add_Click({
        $logDir = "C:\Bepoz\Toolkit\Logs"

        if (Test-Path $logDir) {
            Write-Log "Opening logs directory: $logDir" -Level INFO
            Start-Process explorer.exe -ArgumentList $logDir
        }
        else {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Logs directory does not exist yet:`n$logDir`n`nLogs are created when you run tools.`n`nWould you like to create this directory now?",
                "Logs Directory Not Found",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                try {
                    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
                    Write-Log "Created logs directory: $logDir" -Level SUCCESS
                    Start-Process explorer.exe -ArgumentList $logDir
                }
                catch {
                    Write-Log "Failed to create logs directory: $($_.Exception.Message)" -Level ERROR
                    [System.Windows.Forms.MessageBox]::Show(
                        "Failed to create logs directory:`n$($_.Exception.Message)",
                        "Error",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
        }
    })
    $logPanel.Controls.Add($viewLogsButton)

    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(740, 0)
    $closeButton.Size = New-Object System.Drawing.Size(120, 30)
    $closeButton.Text = "Close"
    $closeButton.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)  # Bepoz Gray (#808080)
    $closeButton.ForeColor = [System.Drawing.Color]::White
    $closeButton.FlatStyle = "Flat"
    $closeButton.FlatAppearance.BorderSize = 0
    $closeButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(138, 168, 221)  # Bepoz Light Blue
    $closeButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $closeButton.Add_Click({
        $Script:MainForm.Close()
    })
    $logPanel.Controls.Add($closeButton)

    # Add panels to form
    $Script:MainForm.Controls.Add($categoryPanel)
    $Script:MainForm.Controls.Add($toolPanel)
    $Script:MainForm.Controls.Add($detailsPanel)
    $Script:MainForm.Controls.Add($logPanel)

    # Form closing event
    $Script:MainForm.Add_FormClosing({
        Write-Log "Toolkit GUI closing" -Level INFO
        Remove-TempFiles
    })

    # Populate categories
    Populate-Categories

    # Show form
    [void]$Script:MainForm.ShowDialog()
}
#endregion

# Entry point
try {
    Show-ToolkitGUI
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Fatal error:`n`n$($_.Exception.Message)`n`nCheck log: $Script:LogFile",
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    Write-Log "Fatal error: $($_.Exception.Message)" -Level ERROR
    Remove-TempFiles
}
