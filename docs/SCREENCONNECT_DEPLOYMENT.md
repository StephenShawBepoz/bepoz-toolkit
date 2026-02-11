# ScreenConnect Deployment Guide

Quick guide for deploying Bepoz Toolkit via ScreenConnect.

---

## Option 1: ScreenConnect Launcher Script (Recommended)

This is the **easiest** way to deploy. Save the launcher as a ScreenConnect script for one-click access.

### Setup Steps:

1. **Open ScreenConnect** → Scripts section
2. **Create New Script**:
   - Name: `Bepoz Toolkit`
   - Type: PowerShell
3. **Copy/Paste** the contents of `ScreenConnect-Launch-Toolkit.ps1`
4. **Save**

### Usage:

1. Connect to customer machine via ScreenConnect
2. Select the **"Bepoz Toolkit"** script from your list
3. Click **Run**
4. Toolkit launches automatically!

### What It Does:

```
ScreenConnect Script
    ↓
Downloads Bootstrap from GitHub
    ↓
Executes Bootstrap
    ↓
Shows Category Menu
    ↓
User Selects Tool
    ↓
Tool Runs
    ↓
Cleanup
```

---

## Option 2: One-Line Command

If you prefer not to save a script, you can run this command directly in ScreenConnect PowerShell:

```powershell
irm https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit.ps1 | iex
```

**Pros:**
- No script management needed
- Always runs latest version

**Cons:**
- Have to copy/paste every time
- Longer command to type

---

## Option 3: Direct Bootstrap Execution

Download the bootstrap script first, then run it:

```powershell
# Download to temp
$url = "https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit.ps1"
$dest = "$env:TEMP\Invoke-BepozToolkit.ps1"
Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing

# Execute
& $dest
```

**Pros:**
- Can inspect script before running
- Works if Invoke-Expression is blocked

**Cons:**
- Two-step process

---

## Testing Your Deployment

Before rolling out to production, test on a dev/test machine:

### Test Checklist:

1. ✅ Run the ScreenConnect launcher script
2. ✅ Verify auto-update check runs
3. ✅ See category menu appear
4. ✅ Select a category (e.g., "Database Tools")
5. ✅ Select a tool (e.g., "Venue Query Tool")
6. ✅ Confirm execution when prompted
7. ✅ Tool executes successfully
8. ✅ Check log file: `$env:TEMP\BepozToolkit.log`
9. ✅ Verify cleanup (temp files deleted)

### Expected Output:

```
Bepoz Toolkit - ScreenConnect Launcher
=======================================

Downloading bootstrap from GitHub...
URL: https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit.ps1

======================================================================
  Bepoz Toolkit Bootstrap v1.0.0
======================================================================

[INFO] Toolkit started
[INFO] Checking for bootstrap updates...
[SUCCESS] Bootstrap is up to date (v1.0.0)
[INFO] Downloading manifest...
[SUCCESS] Manifest loaded: 4 tools in 6 categories

======================================================================
  Bepoz Toolkit - Select Category
======================================================================

 1) Scheduling
    Tools for managing schedules and time-based operations
 2) SmartPOS Mobile
    SmartPOS Mobile configuration and management tools
 3) Kiosk
    Kiosk setup and maintenance tools
 4) TSPlus
    Terminal Services Plus configuration tools
 5) Database Tools
    Direct database query and maintenance utilities
 6) Workstation Setup
    Workstation and device configuration tools

 0) Exit

Select category (0-6):
```

---

## Troubleshooting

### "Failed to download or execute toolkit"

**Cause:** Network issue or incorrect GitHub URL

**Fix:**
1. Verify internet connectivity on client machine
2. Test URL in browser: `https://github.com/StephenShawBepoz/bepoz-toolkit`
3. Ensure repository is public (or add authentication for private)
4. Check firewall/proxy settings

### "Execution Policy Blocked"

**Cause:** PowerShell execution policy restriction

**Fix (Temporary):**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**Fix (Permanent - Admin Required):**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**Or run with bypass flag:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\ScreenConnect-Launch-Toolkit.ps1
```

### "Module BepozDbCore not found"

**Cause:** Module download failed or GitHub repo incomplete

**Fix:**
1. Verify `modules/BepozDbCore.ps1` exists in GitHub repo
2. Check network connectivity
3. Review log file: `$env:TEMP\BepozToolkit.log`
4. Ensure all files uploaded to correct folders

### Script runs but no menu appears

**Cause:** Error in bootstrap or manifest

**Fix:**
1. Check log file: `$env:TEMP\BepozToolkit.log`
2. Verify `manifest.json` is valid JSON (use JSONLint.com)
3. Check bootstrap script for syntax errors
4. Test bootstrap locally first

---

## Running as Different User

**Important:** The toolkit reads `HKCU:\SOFTWARE\Backoffice` registry keys, which are **user-specific**.

### Best Practice:
- Run as the **logged-in user** (not SYSTEM or different user)
- Use ScreenConnect's "Run as logged-in user" option

### If Running as SYSTEM:
The registry keys will not be available, and database tools will fail with:
```
[ERROR] Bepoz registry keys not found at: HKCU:\SOFTWARE\Backoffice
```

---

## Performance Tips

### Fast Deployment:
1. Save launcher script in ScreenConnect (one-time setup)
2. Connect to customer machine
3. Run saved script
4. Total time: **< 15 seconds** from connection to menu

### Bulk Deployment:
To run on multiple machines simultaneously:
1. Use ScreenConnect's "Send Command" feature
2. Select multiple machines
3. Execute launcher script on all

---

## Updating the Toolkit

When you push updates to GitHub:

1. **Bootstrap updates** → Users get automatically (checks every run)
2. **Tool updates** → Downloaded fresh every run
3. **Manifest updates** → Applied immediately

**No action needed** from support team or customers!

---

## Security Notes

### Current Setup (Public Repo):
- ✅ Tools are visible on GitHub (anyone can view)
- ✅ No credentials or secrets in code
- ✅ Safe for public exposure

### If You Switch to Private Repo:
1. Generate GitHub Personal Access Token (PAT)
2. Update launcher script to include authentication
3. Store PAT securely (not in plain text)

See `README.md` for details on private repo setup.

---

## ScreenConnect Script Template

Copy this into ScreenConnect as-is:

```powershell
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
```

---

## Summary

**Recommended Setup:**
1. ✅ Upload all files to GitHub: `https://github.com/StephenShawBepoz/bepoz-toolkit`
2. ✅ Save `ScreenConnect-Launch-Toolkit.ps1` as a ScreenConnect script
3. ✅ Test on a dev machine
4. ✅ Roll out to support team

**Usage:**
- Connect to customer via ScreenConnect
- Run "Bepoz Toolkit" script
- Select category and tool
- Done!

**Maintenance:**
- Update tools on GitHub → Users get automatically
- No reinstallation or redeployment needed

---

**Ready to deploy!** Upload to GitHub and test from ScreenConnect.
