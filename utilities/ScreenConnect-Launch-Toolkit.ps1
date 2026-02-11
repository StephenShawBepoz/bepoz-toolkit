<#
.SYNOPSIS
    ScreenConnect Launcher for Bepoz Toolkit
.DESCRIPTION
    Simple wrapper script to save in ScreenConnect for one-click toolkit access.
    Downloads and executes the bootstrap from GitHub.
.NOTES
    Save this as a ScreenConnect script named "Bepoz Toolkit"
    Run it on customer machines to launch the toolkit instantly
#>

# GitHub repository configuration
$GitHubOrg = "StephenShawBepoz"
$GitHubRepo = "bepoz-toolkit"
$Branch = "main"

# Build URL to bootstrap script
$BootstrapUrl = "https://raw.githubusercontent.com/$GitHubOrg/$GitHubRepo/$Branch/bootstrap/Invoke-BepozToolkit.ps1"

Write-Host "Bepoz Toolkit - ScreenConnect Launcher" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Downloading bootstrap from GitHub..." -ForegroundColor Yellow
Write-Host "URL: $BootstrapUrl" -ForegroundColor Gray
Write-Host ""

try {
    # Download and execute bootstrap
    $ProgressPreference = 'SilentlyContinue'
    Invoke-Expression (Invoke-RestMethod -Uri $BootstrapUrl -UseBasicParsing -ErrorAction Stop)
    $ProgressPreference = 'Continue'
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to download or execute toolkit" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. No internet connection on this machine" -ForegroundColor Gray
    Write-Host "  2. GitHub repository not accessible" -ForegroundColor Gray
    Write-Host "  3. Incorrect GitHub org/repo/branch" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Verify URL in browser: $BootstrapUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
