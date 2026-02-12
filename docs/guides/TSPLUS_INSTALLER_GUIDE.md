# TSPlus Installer Tool - User Guide

**Tool:** TSPlusInstaller.ps1
**Version:** 2.0.0
**Category:** TSPlus
**Requires:** Administrator privileges
**Database:** Not required

---

## Overview

The TSPlus Installer is a GUI tool that automates the download, validation, and silent installation of TSPlus Remote Access software.

### Key Features

✅ **Secure Download** - Downloads installer from configurable URL with TLS 1.2
✅ **Signature Validation** - Validates Authenticode signature before execution
✅ **Silent Installation** - Installs without user interaction (5-10 minutes)
✅ **Progress Monitoring** - Real-time progress bar and status updates
✅ **Comprehensive Logging** - Dual logging (GUI + file + BepozLogger)
✅ **Pre-requisites Setup** - Creates required directories and groups
✅ **Post-Install Validation** - Verifies installation completed successfully
✅ **Optional Reboot** - Can automatically reboot after installation

---

## What The Tool Does

### 1. Pre-Installation Setup

**Creates Required Directory:**
- Path: `C:\Bepoz\Back Office Cloud - Uploads`
- Purpose: Required for Bepoz operations
- Action: Creates if doesn't exist

**Creates Local Group (Optional):**
- User can specify local Windows group name
- Purpose: TSPlus user management
- Action: Creates group if doesn't exist

### 2. Download Phase

**Downloads Installer:**
- URL: Configurable (default: `https://dl-files.com/classic/Setup-TSplus.exe`)
- Target: `C:\ProgramData\TSPlus\Install\Setup-TSplus.exe`
- Protocol: TLS 1.2 enforced
- Progress: Real-time percentage displayed

### 3. Security Validation

**Authenticode Signature Check:**
- Validates digital signature using `Get-AuthenticodeSignature`
- **CRITICAL:** Refuses to run if signature is invalid
- Logs: Signer certificate subject and thumbprint
- Purpose: Prevents execution of tampered/malicious installers

**Why This Matters:**
- Protects against man-in-the-middle attacks
- Ensures installer hasn't been modified
- Validates publisher identity

### 4. Silent Installation

**Installation Process:**
- Command: `Setup-TSplus.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART`
- Duration: Typically 5-10 minutes
- Antivirus: May extend duration during scanning
- Monitoring: Timer checks process status every second
- Progress: Elapsed time displayed

**What Happens:**
1. Installer runs in background (no UI prompts)
2. TSPlus components installed to default location
3. Services configured and started
4. Registry entries created

### 5. Post-Installation

**Validation Check:**
- Checks: `C:\Program Files (x86)\TSplus\UserDesktop\files\AdminTool.exe`
- Result: Warning if not found (may indicate custom install path)

**Completion:**
- Success message displayed
- Log files saved
- Optional reboot prompt

---

## How to Use

### Running Through Toolkit (Recommended)

1. **Launch Bepoz Toolkit**
   ```powershell
   irm https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit-GUI.ps1 | iex
   ```

2. **Select Category**
   - Click "TSPlus" in categories list

3. **Select Tool**
   - Click "TSPlus Installer" in tools list

4. **Run Tool**
   - Click "Run Tool" button
   - Tool launches in new window (console hidden)

### Configuration Options

**Installer URL:**
- Default: `https://dl-files.com/classic/Setup-TSplus.exe`
- Editable: Change if you have a different source
- Format: Must be valid HTTPS URL

**Local Group (Optional):**
- Leave blank if not needed
- Example: `TSPlusUsers`
- Purpose: Windows group for TSPlus user management

**Reboot After Install:**
- Checkbox: Check to enable auto-reboot
- Behavior: Prompts for confirmation before reboot
- Recommended: Yes (TSPlus benefits from reboot)

### Operation Steps

1. **Start**
   - Click "Start" button
   - Confirms admin privileges
   - Validates URL not empty
   - Disables UI controls

2. **Watch Progress**
   - Download progress: 0-100%
   - Installation progress: Elapsed time
   - Status: Updated in real-time
   - Log: Scrolling text display

3. **Completion**
   - Success: Green message box
   - Failure: Red error dialog with details
   - Logs: Both local and central log paths shown

4. **Reboot (If Selected)**
   - Prompt: "Reboot now?"
   - Yes: Immediate reboot
   - No: Manual reboot later

---

## Logging

### Triple Logging System

**1. GUI Log (Real-time)**
- Display: Text box in tool
- Format: `[YYYY-MM-DD HH:mm:ss] Message`
- Purpose: Immediate visual feedback
- Feature: Copy to clipboard button

**2. Local Log File**
- Path: `C:\ProgramData\TSPlus\Install\tsplus_install_YYYYMMDD_HHmmss.log`
- Format: Same as GUI log
- Retention: Manual (not auto-deleted)
- Purpose: Persistent record of installation

**3. Central Log (BepozLogger)**
- Path: `C:\Bepoz\Toolkit\Logs\TSPlusInstaller_YYYYMMDD.log`
- Format: BepozLogger format with context
- Retention: 30 days automatic
- Purpose: Centralized audit trail

### What Gets Logged

**Pre-Installation:**
- Tool startup
- Admin privilege check
- TLS 1.2 enablement
- Directory creation
- Local group creation

**Download:**
- Download initiated
- Download URL
- Download progress (percentage)
- Download completion
- File size

**Security:**
- Signature validation start
- Signature status (Valid/Invalid)
- Certificate subject
- Certificate thumbprint
- Validation result

**Installation:**
- Installation command
- Process ID
- Elapsed time
- Exit code
- Completion status

**Post-Installation:**
- AdminTool.exe check
- Validation result

**User Actions:**
- Start button clicked
- Close button clicked
- Reboot selection
- Reboot confirmation

**Errors:**
- Full error messages
- Exception details
- Stack traces (when available)

---

## Security Features

### 1. Administrator Requirement

**Why Required:**
- Installing software requires elevated privileges
- Creating system directories
- Creating local groups
- Modifying registry

**Enforcement:**
- Checked at runtime via `Test-IsAdmin`
- Warning displayed if not admin
- Installation blocked until run as admin

### 2. Authenticode Validation

**Process:**
```powershell
$sig = Get-AuthenticodeSignature -FilePath $InstallerExe
if ($sig.Status -ne "Valid") {
    # REFUSE TO RUN
}
```

**What It Checks:**
- Digital signature present
- Signature valid (not tampered)
- Certificate not expired
- Certificate chain trusted

**Logged Information:**
- Signature status
- Signer certificate subject
- Certificate thumbprint

**Security Impact:**
- Prevents running modified installers
- Verifies publisher identity
- Protects against supply chain attacks

### 3. TLS 1.2 Enforcement

**Implementation:**
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

**Why Important:**
- Older protocols (SSL 3.0, TLS 1.0, TLS 1.1) are insecure
- TLS 1.2+ encrypts download traffic
- Prevents man-in-the-middle attacks

### 4. Console Window Hiding

**Purpose:**
- Cleaner user experience (GUI only)
- Prevents accidental console closure
- Professional appearance

**Method:**
- P/Invoke to Windows API
- Hides console without closing it
- PowerShell process still running

---

## Troubleshooting

### Issue: "Admin privileges required"

**Cause:** Tool not run as Administrator

**Solution:**
1. Close tool
2. Right-click PowerShell
3. Select "Run as Administrator"
4. Re-launch toolkit
5. Run tool again

---

### Issue: "Installer signature is not valid"

**Cause:** Downloaded file has invalid/missing signature

**Possible Reasons:**
- Download corrupted
- File modified/tampered
- Unsigned installer
- Certificate expired

**Solution:**
1. Check download URL is correct
2. Try downloading again
3. Verify URL with TSPlus support
4. Contact Bepoz support if persists

---

### Issue: Installation takes longer than 10 minutes

**Cause:** Slow server, antivirus scanning, or system load

**Not Necessarily an Error:**
- Some systems take longer
- Antivirus deep scan adds time
- Slow disk I/O

**Actions:**
1. Wait up to 15-20 minutes
2. Check Task Manager for Setup-TSplus.exe process
3. Check if antivirus is scanning
4. Review log for errors
5. If stuck > 20 minutes, contact support

---

### Issue: "AdminTool.exe not found" warning

**Cause:** TSPlus installed to non-standard location OR installation failed

**Check:**
1. Search for `AdminTool.exe` on C: drive
2. If found elsewhere: Installation succeeded (just different path)
3. If not found: Installation may have failed

**Solution:**
1. Check installation exit code in log (should be 0)
2. If exit code = 0 but no AdminTool.exe: Contact TSPlus support
3. If exit code ≠ 0: Installation failed, review logs

---

### Issue: Download fails

**Cause:** Network connectivity, firewall, or invalid URL

**Check:**
1. Verify internet connectivity
2. Check firewall allows HTTPS
3. Verify URL is accessible in browser
4. Check proxy settings

**Solution:**
1. Test URL in web browser
2. Check corporate firewall rules
3. Verify no proxy blocking
4. Try alternate network if available

---

## File Locations

**Tool Script:**
```
tools/TSPlusInstaller.ps1
```

**Installer Download:**
```
C:\ProgramData\TSPlus\Install\Setup-TSplus.exe
```

**Local Log:**
```
C:\ProgramData\TSPlus\Install\tsplus_install_YYYYMMDD_HHmmss.log
```

**Central Log:**
```
C:\Bepoz\Toolkit\Logs\TSPlusInstaller_YYYYMMDD.log
```

**Expected Install Path:**
```
C:\Program Files (x86)\TSplus\UserDesktop\files\AdminTool.exe
```

**Required Bepoz Directory:**
```
C:\Bepoz\Back Office Cloud - Uploads
```

---

## Technical Details

### Installation Arguments

**Silent Flags:**
- `/VERYSILENT` - No UI shown during install
- `/SUPPRESSMSGBOXES` - No message boxes
- `/NORESTART` - Don't reboot automatically (we handle this)

### Process Monitoring

**Timer-based:**
- Interval: 1000ms (1 second)
- Check: `Process.HasExited`
- Display: Elapsed time
- Timeout: None (user monitors visually)

**Exit Codes:**
- `0` = Success
- Non-zero = Error (specific meaning varies)

### Async Download

**Method:** `WebClient.DownloadFileAsync`

**Events:**
- `DownloadProgressChanged` - Updates progress bar
- `DownloadFileCompleted` - Triggers signature validation

**Thread Safety:**
- UI updates via `UI-Invoke` helper
- Ensures cross-thread operations safe

---

## Best Practices

### Before Installation

✅ **Ensure system requirements met:**
- Windows Server 2012 R2 or later (typically)
- Adequate disk space (~500 MB)
- Internet connectivity
- Administrator access

✅ **Plan for reboot:**
- Schedule during maintenance window
- Notify users if workstation
- Save all open work

✅ **Check URL:**
- Verify installer URL is correct
- Test URL accessibility
- Confirm with TSPlus if unsure

### During Installation

✅ **Monitor progress:**
- Watch elapsed time
- Check for errors in log
- Don't close window prematurely

✅ **Be patient:**
- 5-10 minutes is normal
- Up to 15-20 minutes acceptable
- Antivirus scanning adds time

### After Installation

✅ **Verify success:**
- Check for AdminTool.exe
- Review log files
- Test TSPlus functionality

✅ **Reboot:**
- Recommended even if optional
- Ensures services start properly
- Completes installation

✅ **Save logs:**
- Archive logs for troubleshooting
- Include in support tickets if needed

---

## Comparison: v1.0 vs v2.0

| Feature | v1.0 (Standalone) | v2.0 (Toolkit) |
|---------|------------------|----------------|
| **Module Loading** | Local paths | Toolkit temp directory |
| **Logging** | GUI + File | GUI + File + BepozLogger |
| **Log Location** | Local only | Local + Central |
| **Audit Trail** | Basic | Comprehensive |
| **Error Detail** | Standard | Enhanced with stack traces |
| **Performance Metrics** | No | Yes (via BepozLogger) |
| **Deployment** | Manual | Via toolkit |
| **Updates** | Manual download | Auto-download from GitHub |

---

## Frequently Asked Questions

**Q: Do I need a TSPlus license key?**
A: This tool only installs the software. Licensing is handled separately through TSPlus portal.

**Q: Can I customize the installer URL?**
A: Yes, edit the URL field before clicking Start.

**Q: What if I don't want to reboot?**
A: Uncheck the "Reboot after install" box. You can reboot manually later.

**Q: Is the download secure?**
A: Yes - TLS 1.2 enforced + Authenticode signature validation.

**Q: Can I run this on workstations?**
A: Yes, but typically installed on servers for remote access.

**Q: What if the signature check fails?**
A: The tool will refuse to run the installer. Contact support.

**Q: Can I monitor installation remotely?**
A: Yes via ScreenConnect - watch the GUI or check log files.

**Q: What happens if installation fails?**
A: Error dialog displayed, logs saved, UI re-enabled for retry.

---

## Support

**For Issues:**
- Check logs: `C:\ProgramData\TSPlus\Install\` and `C:\Bepoz\Toolkit\Logs\`
- Include both log files in support ticket
- Note exact error message
- Document steps to reproduce

**Contact:**
- Bepoz Support Team
- Include: Log files, screenshots, error messages

---

**Version:** 2.0.0
**Last Updated:** 2026-02-12
**Author:** Bepoz Administration Team
