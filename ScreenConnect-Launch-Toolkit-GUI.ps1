<#
.SYNOPSIS
    ScreenConnect Launcher for Bepoz Toolkit GUI
.DESCRIPTION
    Launches the graphical user interface version of the Bepoz Toolkit.
    Downloads and executes the GUI bootstrap from GitHub.

    Perfect for support staff who prefer point-and-click over command-line menus.
.NOTES
    Save this as a ScreenConnect script named "Bepoz Toolkit (GUI)"
    Requires Windows Forms (built into Windows)
#>

# GitHub repository configuration
$GitHubOrg = "StephenShawBepoz"
$GitHubRepo = "bepoz-toolkit"
$Branch = "main"

# Build URL to GUI bootstrap script
$BootstrapUrl = "https://raw.githubusercontent.com/$GitHubOrg/$GitHubRepo/$Branch/bootstrap/Invoke-BepozToolkit-GUI.ps1"

Write-Host "Bepoz Toolkit GUI - ScreenConnect Launcher" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Downloading GUI bootstrap from GitHub..." -ForegroundColor Yellow
Write-Host "URL: $BootstrapUrl" -ForegroundColor Gray
Write-Host ""

try {
    # Download and execute GUI bootstrap
    $ProgressPreference = 'SilentlyContinue'
    Invoke-Expression (Invoke-RestMethod -Uri $BootstrapUrl -UseBasicParsing -ErrorAction Stop)
    $ProgressPreference = 'Continue'
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to download or execute toolkit GUI" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. No internet connection on this machine" -ForegroundColor Gray
    Write-Host "  2. GitHub repository not accessible" -ForegroundColor Gray
    Write-Host "  3. Incorrect GitHub org/repo/branch" -ForegroundColor Gray
    Write-Host "  4. Windows Forms not available (unlikely)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Verify URL in browser: $BootstrapUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
