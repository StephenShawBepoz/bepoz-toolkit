<#
.SYNOPSIS
    Bepoz Toolkit Bootstrap - Downloads and executes Bepoz PowerShell tools from GitHub
.DESCRIPTION
    Production-ready bootstrap script for ScreenConnect deployment
    - Auto-updates itself on every run
    - Downloads tools on-demand from GitHub
    - Hierarchical category menu
    - Cleans up after execution
    - Full logging and error handling
.PARAMETER GitHubOrg
    GitHub organization/user name (default: your-org)
.PARAMETER GitHubRepo
    GitHub repository name (default: bepoz-toolkit)
.PARAMETER Branch
    Git branch to use (default: main)
.NOTES
    Version: 1.0.0
    Author: Bepoz Support Team
    Last Updated: 2026-02-11
#>

[CmdletBinding()]
param(
    [string]$GitHubOrg = "your-github-org",
    [string]$GitHubRepo = "bepoz-toolkit",
    [string]$Branch = "main"
)

#region Configuration
$Script:Version = "1.0.0"
$Script:TempDir = Join-Path $env:TEMP "BepozToolkit_$([guid]::NewGuid().ToString().Substring(0,8))"
$Script:LogFile = Join-Path $env:TEMP "BepozToolkit.log"
$Script:BaseUrl = "https://raw.githubusercontent.com/$GitHubOrg/$GitHubRepo/$Branch"
$Script:DownloadedFiles = @()
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

    # Write to console with color
    $color = switch ($Level) {
        'ERROR'   { 'Red' }
        'WARN'    { 'Yellow' }
        'SUCCESS' { 'Green' }
        default   { 'White' }
    }

    Write-Host $logEntry -ForegroundColor $color
}

function Write-LogSection {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
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
                Write-Log "Deleted: $file" -Level INFO
            } catch {
                Write-Log "Failed to delete: $file - $($_.Exception.Message)" -Level WARN
            }
        }
    }

    if (Test-Path $Script:TempDir) {
        try {
            Remove-Item $Script:TempDir -Recurse -Force -ErrorAction Stop
            Write-Log "Deleted temp directory: $Script:TempDir" -Level INFO
        } catch {
            Write-Log "Failed to delete temp directory: $($_.Exception.Message)" -Level WARN
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
            throw "File not found after download: $Destination"
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
            Write-Log "Could not check for updates - manifest download failed" -Level WARN
            return $false
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $remoteVersion = [version]$manifest.bootstrap.version
        $currentVersion = [version]$Script:Version

        if ($remoteVersion -gt $currentVersion) {
            Write-Log "Update available: v$currentVersion -> v$remoteVersion" -Level WARN
            return $manifest.bootstrap.file
        } else {
            Write-Log "Bootstrap is up to date (v$currentVersion)" -Level SUCCESS
            return $false
        }
    } catch {
        Write-Log "Update check failed: $($_.Exception.Message)" -Level WARN
        return $false
    }
}

function Update-Bootstrap {
    param([string]$BootstrapFile)

    Write-Log "Downloading updated bootstrap..." -Level INFO

    $newBootstrapPath = Join-Path $Script:TempDir "Invoke-BepozToolkit-New.ps1"
    $downloadSuccess = Get-FileFromGitHub -RelativePath $BootstrapFile -Destination $newBootstrapPath

    if (-not $downloadSuccess) {
        Write-Log "Bootstrap update failed - continuing with current version" -Level ERROR
        return $false
    }

    Write-Log "Bootstrap updated successfully - restarting..." -Level SUCCESS
    Write-Host ""
    Write-Host "Press any key to restart with new version..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

    # Relaunch with new version
    & $newBootstrapPath -GitHubOrg $GitHubOrg -GitHubRepo $GitHubRepo -Branch $Branch
    exit 0
}
#endregion

#region Menu Functions
function Show-CategoryMenu {
    param($Categories)

    Write-LogSection "Bepoz Toolkit - Select Category"

    for ($i = 0; $i -lt $Categories.Count; $i++) {
        $cat = $Categories[$i]
        Write-Host ("{0,2}) {1}" -f ($i + 1), $cat.name) -ForegroundColor Cyan
        Write-Host ("     {0}" -f $cat.description) -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host " 0) Exit" -ForegroundColor Red
    Write-Host ""

    do {
        $selection = Read-Host "Select category (0-$($Categories.Count))"
        $valid = $selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -le $Categories.Count
        if (-not $valid) {
            Write-Host "Invalid selection. Please enter a number between 0 and $($Categories.Count)." -ForegroundColor Red
        }
    } while (-not $valid)

    return [int]$selection
}

function Show-ToolMenu {
    param(
        $Tools,
        $CategoryName
    )

    Write-LogSection "$CategoryName - Select Tool"

    for ($i = 0; $i -lt $Tools.Count; $i++) {
        $tool = $Tools[$i]
        Write-Host ("{0,2}) {1} (v{2})" -f ($i + 1), $tool.name, $tool.version) -ForegroundColor Green
        Write-Host ("     {0}" -f $tool.description) -ForegroundColor Gray

        $badges = @()
        if ($tool.requiresAdmin) { $badges += "Admin Required" }
        if ($tool.requiresDatabase) { $badges += "Database Access" }
        if ($badges.Count -gt 0) {
            Write-Host ("     [{0}]" -f ($badges -join ", ")) -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host " 0) Back to Categories" -ForegroundColor Red
    Write-Host ""

    do {
        $selection = Read-Host "Select tool (0-$($Tools.Count))"
        $valid = $selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -le $Tools.Count
        if (-not $valid) {
            Write-Host "Invalid selection. Please enter a number between 0 and $($Tools.Count)." -ForegroundColor Red
        }
    } while (-not $valid)

    return [int]$selection
}

function Confirm-ToolExecution {
    param($Tool)

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Yellow
    Write-Host "  READY TO RUN TOOL" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Tool:        " -NoNewline; Write-Host $Tool.name -ForegroundColor Green
    Write-Host "Version:     " -NoNewline; Write-Host $Tool.version -ForegroundColor Green
    Write-Host "Category:    " -NoNewline; Write-Host $Tool.category -ForegroundColor Green
    Write-Host "Description: " -NoNewline; Write-Host $Tool.description -ForegroundColor Gray
    Write-Host ""

    do {
        $response = Read-Host "Continue? (Y/N)"
        $valid = $response -match '^[YN]$'
        if (-not $valid) {
            Write-Host "Please enter Y or N" -ForegroundColor Red
        }
    } while (-not $valid)

    return $response -eq 'Y'
}
#endregion

#region Tool Execution
function Invoke-Tool {
    param($Tool)

    Write-Log "User selected tool: $($Tool.name) v$($Tool.version)" -Level INFO

    # Download tool
    $toolPath = Join-Path $Script:TempDir (Split-Path $Tool.file -Leaf)
    Write-Log "Downloading tool: $($Tool.file)" -Level INFO

    $downloadSuccess = Get-FileFromGitHub -RelativePath $Tool.file -Destination $toolPath
    if (-not $downloadSuccess) {
        Write-Log "Failed to download tool" -Level ERROR
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # Confirm execution
    $confirmed = Confirm-ToolExecution -Tool $Tool
    if (-not $confirmed) {
        Write-Log "User cancelled tool execution" -Level WARN
        return
    }

    # Execute tool
    Write-Log "Executing tool: $toolPath" -Level INFO
    Write-LogSection "TOOL OUTPUT - $($Tool.name)"

    try {
        & $toolPath
        $exitCode = $LASTEXITCODE

        if ($null -eq $exitCode) { $exitCode = 0 }

        Write-Host ""
        if ($exitCode -eq 0) {
            Write-Log "Tool completed successfully (exit code: $exitCode)" -Level SUCCESS
        } else {
            Write-Log "Tool completed with exit code: $exitCode" -Level WARN
        }
    } catch {
        Write-Log "Tool execution failed: $($_.Exception.Message)" -Level ERROR
    }

    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
#endregion

#region Main Script
function Start-Toolkit {
    try {
        # Create temp directory
        if (-not (Test-Path $Script:TempDir)) {
            New-Item -Path $Script:TempDir -ItemType Directory -Force | Out-Null
        }

        Write-LogSection "Bepoz Toolkit Bootstrap v$Script:Version"
        Write-Log "Toolkit started" -Level INFO
        Write-Log "Temp directory: $Script:TempDir" -Level INFO
        Write-Log "Log file: $Script:LogFile" -Level INFO

        # Check for updates
        $updateFile = Test-BootstrapUpdate
        if ($updateFile) {
            Update-Bootstrap -BootstrapFile $updateFile
            return
        }

        # Download manifest (reuse if already downloaded during update check)
        $manifestPath = Join-Path $Script:TempDir "manifest.json"
        if (-not (Test-Path $manifestPath)) {
            Write-Log "Downloading manifest..." -Level INFO
            $downloadSuccess = Get-FileFromGitHub -RelativePath "manifest.json" -Destination $manifestPath
            if (-not $downloadSuccess) {
                throw "Failed to download manifest.json"
            }
        }

        # Parse manifest
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-Log "Manifest loaded: $($manifest.tools.Count) tools in $($manifest.categories.Count) categories" -Level SUCCESS

        # Main menu loop
        do {
            $categorySelection = Show-CategoryMenu -Categories $manifest.categories

            if ($categorySelection -eq 0) {
                Write-Log "User exited toolkit" -Level INFO
                break
            }

            $selectedCategory = $manifest.categories[$categorySelection - 1]
            $categoryTools = $manifest.tools | Where-Object { $_.category -eq $selectedCategory.id }

            if ($categoryTools.Count -eq 0) {
                Write-Host "No tools available in this category yet." -ForegroundColor Yellow
                Write-Host "Press any key to continue..." -ForegroundColor Yellow
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            do {
                $toolSelection = Show-ToolMenu -Tools $categoryTools -CategoryName $selectedCategory.name

                if ($toolSelection -eq 0) {
                    break
                }

                $selectedTool = $categoryTools[$toolSelection - 1]
                Invoke-Tool -Tool $selectedTool

            } while ($true)

        } while ($true)

    } catch {
        Write-Log "Fatal error: $($_.Exception.Message)" -Level ERROR
        Write-Host ""
        Write-Host "A fatal error occurred. Check the log file for details: $Script:LogFile" -ForegroundColor Red
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } finally {
        Remove-TempFiles
        Write-Log "Toolkit finished" -Level INFO
    }
}

# Entry point
Start-Toolkit
#endregion
