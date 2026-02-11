# Script Migration Guide - Bepoz Toolkit Modules
**For Claude Code: Step-by-Step Script Modernization**

**Date:** 2026-02-11
**Purpose:** Update PowerShell scripts to use centralized Bepoz Toolkit modules
**Target Audience:** Claude Code (AI assistant helping with script updates)

---

## Overview

The Bepoz Toolkit now provides three centralized modules to eliminate code duplication:

1. **BepozDbCore.ps1** (v1.3.0) - Database access with auto-logging
2. **BepozLogger.ps1** (v1.0.0) - Centralized logging
3. **BepozUI.ps1** (v1.0.0) - Common Windows Forms UI helpers

**Benefits:**
- ✅ Eliminate 200-300 lines of duplicate DB code per script
- ✅ Reduce GUI code by 30-40% using UI helpers
- ✅ Automatic performance logging for all database queries
- ✅ Consistent error handling and user experience
- ✅ Easier maintenance (fix once, benefits all tools)

---

## Migration Checklist

When migrating a script, follow this order:

- [ ] **Step 1:** Add BepozDbCore module loading (replace DB code)
- [ ] **Step 2:** Add BepozLogger module loading (add logging)
- [ ] **Step 3:** Add BepozUI module loading (simplify GUI code) - Optional
- [ ] **Step 4:** Test script with modules present
- [ ] **Step 5:** Test script with modules absent (graceful degradation)
- [ ] **Step 6:** Update version number in script header
- [ ] **Step 7:** Add tool to manifest.json if not already there

---

## STEP 1: Migrate to BepozDbCore

### What to Look For (Old Patterns)

Search the script for these patterns indicating old DB code:

```powershell
# Pattern 1: Registry discovery
$regPath = 'HKCU:\SOFTWARE\Backoffice'
Get-ItemProperty -Path $regPath

# Pattern 2: Connection string building
"Server=$sqlServer;Database=$sqlDb;Integrated Security=True"

# Pattern 3: SqlConnection/SqlCommand usage
New-Object System.Data.SqlClient.SqlConnection
New-Object System.Data.SqlClient.SqlCommand
$conn.Open()
$cmd.ExecuteReader()

# Pattern 4: DataAdapter pattern
New-Object System.Data.SqlClient.SqlDataAdapter
$adapter.Fill($dt)
```

### BEFORE: Old Database Code (200-300 lines)

```powershell
#region Database Functions

function Get-DatabaseConfig {
    $regPath = 'HKCU:\SOFTWARE\Backoffice'
    try {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        return @{
            Server = $props.SQL_Server
            Database = $props.SQL_DSN
        }
    }
    catch {
        throw "Failed to read registry"
    }
}

function Get-ConnectionString {
    $config = Get-DatabaseConfig
    return "Server=$($config.Server);Database=$($config.Database);Integrated Security=True;TrustServerCertificate=True;"
}

function Invoke-SqlQuery {
    param(
        [string]$Query,
        [hashtable]$Parameters = @{},
        [string]$ConnectionString
    )

    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $conn)

    foreach ($key in $Parameters.Keys) {
        $cmd.Parameters.AddWithValue($key, $Parameters[$key]) | Out-Null
    }

    try {
        $conn.Open()
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        $adapter.Fill($dt) | Out-Null
        return $dt
    }
    finally {
        if ($conn.State -eq 'Open') { $conn.Close() }
    }
}

function Invoke-SqlNonQuery {
    param(
        [string]$Query,
        [hashtable]$Parameters = @{},
        [string]$ConnectionString
    )

    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $cmd = New-Object System.Data.SqlClient.SqlCommand($Query, $conn)

    foreach ($key in $Parameters.Keys) {
        $cmd.Parameters.AddWithValue($key, $Parameters[$key]) | Out-Null
    }

    try {
        $conn.Open()
        return $cmd.ExecuteNonQuery()
    }
    finally {
        if ($conn.State -eq 'Open') { $conn.Close() }
    }
}

#endregion

# Later in script...
$script:ConnectionString = Get-ConnectionString
$venues = Invoke-SqlQuery -Query "SELECT VenueID, Name FROM Venue" -ConnectionString $script:ConnectionString
```

### AFTER: Using BepozDbCore (15 lines)

```powershell
#region Module Loading - BepozDbCore

# Load BepozDbCore module from TEMP (downloaded by toolkit)
$dbCoreModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if (-not $dbCoreModule) {
    Write-Host "ERROR: BepozDbCore module not found in TEMP" -ForegroundColor Red
    Write-Host "This tool must be run through the Bepoz Toolkit (Invoke-BepozToolkit.ps1)" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Load the module
. $dbCoreModule.FullName

# Initialize database connection
try {
    $dbInfo = Get-BepozDbInfo -ApplicationName "YourToolName"
    $script:ConnectionString = $dbInfo.ConnectionString

    Write-Host "[Database] Connected to: $($dbInfo.Server)\$($dbInfo.Database)" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to initialize database: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

#endregion

# Later in script...
$venues = Invoke-BepozQuery -Query "SELECT VenueID, Name FROM Venue"
```

### Key Changes

| Old Code | New Code | Notes |
|----------|----------|-------|
| `Get-DatabaseConfig` | `Get-BepozDbInfo` | Returns PSCustomObject with Server, Database, ConnectionString, User, Registry |
| `Get-ConnectionString` | Use `$dbInfo.ConnectionString` | Already formatted and ready to use |
| `Invoke-SqlQuery` | `Invoke-BepozQuery` | Auto-logs queries, handles errors, uses Write-Output -NoEnumerate |
| `Invoke-SqlNonQuery` | `Invoke-BepozNonQuery` | Auto-logs operations, returns affected row count |
| Manual registry code | N/A - handled by module | No need to access registry directly |
| Manual SqlConnection | N/A - handled by module | No need to create connections manually |

### ConnectionString Usage

**Old way:**
```powershell
Invoke-SqlQuery -Query $sql -Parameters $params -ConnectionString $script:ConnectionString
```

**New way:**
```powershell
# Option 1: Let module use its internal connection (preferred)
Invoke-BepozQuery -Query $sql -Parameters $params

# Option 2: Pass connection string if needed for compatibility
Invoke-BepozQuery -Query $sql -Parameters $params -ConnectionString $script:ConnectionString
```

**Note:** BepozDbCore internally stores the connection string, so you don't need to pass it unless you have a specific reason.

---

## STEP 2: Add BepozLogger

### What to Add

Insert this section **AFTER** BepozDbCore loading:

```powershell
#region Module Loading - BepozLogger

# Load BepozLogger module from TEMP (downloaded by toolkit)
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if ($loggerModule) {
    . $loggerModule.FullName
    $logFile = Initialize-BepozLogger -ToolName "YourToolNameHere"

    if ($logFile) {
        Write-Host "[Logger] Logging to: $logFile" -ForegroundColor Gray
        Write-BepozLogAction "Tool started"
    }
    else {
        Write-Host "[Logger] Failed to initialize (logs to TEMP instead)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "[Logger] BepozLogger module not found - logging disabled" -ForegroundColor Yellow
}

#endregion
```

**Replace "YourToolNameHere" with your actual tool name** (no spaces, alphanumeric only).

### Where to Add Logging Calls

Add logging at these key points:

#### 1. User Actions (Button Clicks, Selections)

```powershell
# Example: Venue selection
$cmbVenue.Add_SelectedIndexChanged({
    $venueID = Get-ComboBoxItemValue $cmbVenue.SelectedItem

    # Log the selection
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        $venueName = Get-ComboBoxItemText $cmbVenue.SelectedItem
        Write-BepozLogAction "User selected venue: $venueName (ID: $venueID)"
    }

    # ... rest of event handler ...
})

# Example: Button click
$btnApply.Add_Click({
    # Log button click
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User clicked 'Apply' button"
    }

    # ... validation and logic ...
})
```

#### 2. Operation Details (After Validation, Before Execution)

```powershell
# After user confirms operation
if ($result -eq 'Yes') {
    # Log operation details
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        $details = "$($selectedItems.Count) items for venue '$venueName'"
        Write-BepozLogAction "Operation confirmed: $details"
    }

    # ... execute operation ...
}
```

#### 3. Completion Results

```powershell
# After operation completes
if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    Write-BepozLogAction "Operation completed: Processed=$processedCount, Errors=$errorCount"
}

[System.Windows.Forms.MessageBox]::Show("Operation complete!", "Success", "OK", "Information")
```

#### 4. Errors

```powershell
catch {
    # Log error
    if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
        Write-BepozLogError -Message "Operation failed" -Exception $_.Exception
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Error: $($_.Exception.Message)",
        "Error",
        "OK",
        "Error"
    )
}
```

#### 5. Tool Close

```powershell
$btnClose.Add_Click({
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User closed tool"
    }
    $form.Close()
})
```

### Logging Functions Reference

| Function | When to Use | Example |
|----------|-------------|---------|
| `Write-BepozLogAction` | User actions, operations | `Write-BepozLogAction "User clicked Apply"` |
| `Write-BepozLogQuery` | Manual query logging (BepozDbCore does this automatically) | Usually not needed |
| `Write-BepozLogPerformance` | Custom performance tracking | `Write-BepozLogPerformance -Operation "DataExport" -DurationMs 1234` |
| `Write-BepozLogError` | Errors and exceptions | `Write-BepozLogError -Message "Failed" -Exception $_.Exception` |
| `Measure-BepozOperation` | Wrap code blocks to measure time | `$result = Measure-BepozOperation -Name "Export" -ScriptBlock { ... }` |

### Important: Defensive Logging

**ALWAYS** use defensive checks before calling logging functions:

```powershell
# ✅ CORRECT - Checks if function exists
if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    Write-BepozLogAction "Something happened"
}

# ❌ WRONG - Will error if logger not loaded
Write-BepozLogAction "Something happened"
```

**Why?** Tools must work even if BepozLogger module is not available (graceful degradation).

---

## STEP 3: Use BepozUI Helpers (Optional)

### What to Look For (Old Patterns)

Search for repetitive Windows Forms code:

```powershell
# Pattern 1: Input dialogs
$inputForm = New-Object System.Windows.Forms.Form
$inputForm.Text = "Enter Value"
$inputForm.Size = New-Object System.Drawing.Size(400, 150)
# ... 20 more lines ...

# Pattern 2: File pickers
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.Filter = "CSV Files|*.csv|All Files|*.*"
# ... setup code ...

# Pattern 3: Confirmation dialogs
$result = [System.Windows.Forms.MessageBox]::Show("Are you sure?", "Confirm", "YesNo", "Question")

# Pattern 4: Progress dialogs
$progressForm = New-Object System.Windows.Forms.Form
$progressBar = New-Object System.Windows.Forms.ProgressBar
# ... 30 more lines ...
```

### Module Loading

Insert this section **AFTER** BepozLogger loading:

```powershell
#region Module Loading - BepozUI

# Load BepozUI module from TEMP (downloaded by toolkit)
$uiModule = Get-ChildItem -Path $env:TEMP -Filter "BepozUI.ps1" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

if ($uiModule) {
    . $uiModule.FullName
    Write-Host "[UI] BepozUI helpers loaded" -ForegroundColor Gray
}
else {
    Write-Host "[UI] BepozUI module not found - using standard controls" -ForegroundColor Yellow
}

#endregion
```

### UI Helper Examples

#### Input Dialogs

**BEFORE (20 lines):**
```powershell
$inputForm = New-Object System.Windows.Forms.Form
$inputForm.Text = "Enter Name"
$inputForm.Size = New-Object System.Drawing.Size(400, 150)
$inputForm.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10, 10)
$label.Size = New-Object System.Drawing.Size(380, 20)
$label.Text = "Please enter the name:"
$inputForm.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10, 35)
$textBox.Size = New-Object System.Drawing.Size(360, 20)
$inputForm.Controls.Add($textBox)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(210, 70)
$okButton.Size = New-Object System.Drawing.Size(75, 25)
$okButton.Text = "OK"
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$inputForm.Controls.Add($okButton)

$inputForm.AcceptButton = $okButton
$result = $inputForm.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $userName = $textBox.Text
}
```

**AFTER (3 lines):**
```powershell
if (Get-Command -Name Show-BepozInputDialog -ErrorAction SilentlyContinue) {
    $userName = Show-BepozInputDialog -Title "Enter Name" -Prompt "Please enter the name:"
}
```

#### File Picker

**BEFORE (10 lines):**
```powershell
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.Title = "Select CSV File"
$openFileDialog.Filter = "CSV Files|*.csv|All Files|*.*"
$openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

$result = $openFileDialog.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $filePath = $openFileDialog.FileName
}
```

**AFTER (3 lines):**
```powershell
if (Get-Command -Name Show-BepozFilePicker -ErrorAction SilentlyContinue) {
    $filePath = Show-BepozFilePicker -Title "Select CSV File" -Filter "CSV Files|*.csv|All Files|*.*"
}
```

#### Confirmation Dialog

**BEFORE:**
```powershell
$result = [System.Windows.Forms.MessageBox]::Show(
    "Are you sure you want to delete this?",
    "Confirm Deletion",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
    # Delete
}
```

**AFTER:**
```powershell
if (Get-Command -Name Show-BepozConfirmDialog -ErrorAction SilentlyContinue) {
    $confirmed = Show-BepozConfirmDialog -Title "Confirm Deletion" -Message "Are you sure you want to delete this?"
    if ($confirmed) {
        # Delete
    }
}
```

#### Progress Dialog

**BEFORE (30+ lines):**
```powershell
$progressForm = New-Object System.Windows.Forms.Form
$progressForm.Text = "Processing..."
$progressForm.Size = New-Object System.Drawing.Size(400, 120)
$progressForm.FormBorderStyle = "FixedDialog"
$progressForm.StartPosition = "CenterScreen"

$progressLabel = New-Object System.Windows.Forms.Label
$progressLabel.Location = New-Object System.Drawing.Point(10, 10)
$progressLabel.Size = New-Object System.Drawing.Size(380, 20)
$progressLabel.Text = "Please wait..."
$progressForm.Controls.Add($progressLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 40)
$progressBar.Size = New-Object System.Drawing.Size(370, 30)
$progressBar.Style = "Marquee"
$progressForm.Controls.Add($progressBar)

$progressForm.Show()
$progressForm.Refresh()

# ... do work ...

$progressForm.Close()
```

**AFTER (5 lines):**
```powershell
if (Get-Command -Name Show-BepozProgressDialog -ErrorAction SilentlyContinue) {
    $progress = Show-BepozProgressDialog -Title "Processing..." -Message "Please wait..."

    # ... do work ...

    $progress.Close()
}
```

### BepozUI Functions Reference

| Function | Purpose | Returns |
|----------|---------|---------|
| `Show-BepozInputDialog` | Get text input from user | String or $null if cancelled |
| `Show-BepozNumberDialog` | Get numeric input with spinner | Int or $null if cancelled |
| `Show-BepozDropdownDialog` | Get selection from dropdown | Selected item or $null if cancelled |
| `Show-BepozFilePicker` | Open file dialog | File path or $null if cancelled |
| `Show-BepozFileSavePicker` | Save file dialog | File path or $null if cancelled |
| `Show-BepozFolderPicker` | Folder browser dialog | Folder path or $null if cancelled |
| `Show-BepozConfirmDialog` | Yes/No confirmation | $true or $false |
| `Show-BepozMessageBox` | Custom message box | DialogResult value |
| `Show-BepozProgressDialog` | Progress indicator | Form object (must close it) |
| `Update-BepozProgressDialog` | Update progress dialog text | N/A |
| `Show-BepozDataGrid` | Display DataTable in grid | N/A |

---

## STEP 4: Testing

### Test With Modules (Normal Operation)

1. Run tool through toolkit:
   ```powershell
   & "C:\Path\To\Invoke-BepozToolkit.ps1"
   ```

2. Select your tool and run it

3. Verify:
   - ✅ Tool loads without errors
   - ✅ Database queries work
   - ✅ Logs created in `C:\Bepoz\Toolkit\Logs\ToolName_YYYYMMDD.log`
   - ✅ UI helpers work (if using BepozUI)
   - ✅ All functionality works as before

### Test Without Modules (Graceful Degradation)

1. Run tool directly (NOT through toolkit):
   ```powershell
   & "C:\Path\To\YourTool.ps1"
   ```

2. Verify:
   - ✅ Tool shows clear error message about missing BepozDbCore
   - ✅ Tool exits gracefully (no crashes)
   - ⚠️ This is expected behavior - tools require BepozDbCore

**Note:** BepozDbCore is **REQUIRED** (tools must be run through toolkit). BepozLogger and BepozUI are optional (tools work without them but with reduced functionality).

---

## STEP 5: Update Version and Manifest

### Update Script Header

Change version number to indicate migration:

```powershell
<#
.SYNOPSIS
    Your Tool Name

.DESCRIPTION
    Tool description here

.NOTES
    Version: 2.0.0  # <-- Increment major version for module migration
    Author: Your Name
    Updated: 2026-02-11
    Dependencies: BepozDbCore.ps1 (v1.3.0+), BepozLogger.ps1 (v1.0.0+), BepozUI.ps1 (v1.0.0+)
#>
```

### Add Tool to manifest.json

If not already in manifest, add your tool:

```json
{
  "tools": [
    {
      "id": "your-tool-id",
      "name": "Your Tool Name",
      "category": "appropriate-category",
      "file": "tools/YourToolName.ps1",
      "version": "2.0.0",
      "description": "Brief description of what your tool does"
    }
  ]
}
```

Categories available:
- `scheduling` - Week schedule, shift management, etc.
- `smartposmobile` - SmartPOS Mobile configuration
- `kiosk` - Kiosk setup and management
- `tsplus` - TSPlus related tools
- `database` - Database utilities
- `workstation` - Workstation setup and configuration

---

## Common Migration Patterns

### Pattern 1: Simple Query Function

**BEFORE:**
```powershell
function Get-Venues {
    param([string]$ConnectionString)

    $query = "SELECT VenueID, Name FROM Venue ORDER BY Name"

    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)

    try {
        $conn.Open()
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        $adapter.Fill($dt) | Out-Null
        return $dt
    }
    finally {
        if ($conn.State -eq 'Open') { $conn.Close() }
    }
}
```

**AFTER:**
```powershell
function Get-Venues {
    $query = "SELECT VenueID, Name FROM Venue ORDER BY Name"
    return Invoke-BepozQuery -Query $query
}
```

### Pattern 2: Parameterized Query Function

**BEFORE:**
```powershell
function Get-Workstations {
    param(
        [int]$VenueID,
        [string]$ConnectionString
    )

    $query = "SELECT WorkstationID, Name FROM Workstation WHERE VenueID = @VenueID ORDER BY Name"

    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
    $cmd.Parameters.AddWithValue("@VenueID", $VenueID) | Out-Null

    try {
        $conn.Open()
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        $adapter.Fill($dt) | Out-Null
        return $dt
    }
    finally {
        if ($conn.State -eq 'Open') { $conn.Close() }
    }
}
```

**AFTER:**
```powershell
function Get-Workstations {
    param([int]$VenueID)

    $query = "SELECT WorkstationID, Name FROM Workstation WHERE VenueID = @VenueID ORDER BY Name"
    $params = @{ VenueID = $VenueID }

    return Invoke-BepozQuery -Query $query -Parameters $params
}
```

### Pattern 3: Insert/Update Function

**BEFORE:**
```powershell
function Insert-WeekSchedule {
    param(
        [int]$WorkstationID,
        [int]$KeySetID,
        [int]$Day,
        [string]$ConnectionString
    )

    $query = @"
        INSERT INTO WeekSchedule (WorkstationID, KeySetID, Day)
        VALUES (@WorkstationID, @KeySetID, @Day)
"@

    $conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
    $cmd.Parameters.AddWithValue("@WorkstationID", $WorkstationID) | Out-Null
    $cmd.Parameters.AddWithValue("@KeySetID", $KeySetID) | Out-Null
    $cmd.Parameters.AddWithValue("@Day", $Day) | Out-Null

    try {
        $conn.Open()
        return $cmd.ExecuteNonQuery()
    }
    finally {
        if ($conn.State -eq 'Open') { $conn.Close() }
    }
}
```

**AFTER:**
```powershell
function Insert-WeekSchedule {
    param(
        [int]$WorkstationID,
        [int]$KeySetID,
        [int]$Day
    )

    $query = @"
        INSERT INTO WeekSchedule (WorkstationID, KeySetID, Day)
        VALUES (@WorkstationID, @KeySetID, @Day)
"@

    $params = @{
        WorkstationID = $WorkstationID
        KeySetID      = $KeySetID
        Day           = $Day
    }

    return Invoke-BepozNonQuery -Query $query -Parameters $params
}
```

---

## Quick Reference Card

### Module Loading Template

```powershell
#region Module Loading

# === BepozDbCore (REQUIRED) ===
$dbCoreModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $dbCoreModule) {
    Write-Host "ERROR: BepozDbCore module not found" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

. $dbCoreModule.FullName

try {
    $dbInfo = Get-BepozDbInfo -ApplicationName "TOOLNAME"
    $script:ConnectionString = $dbInfo.ConnectionString
    Write-Host "[Database] Connected to: $($dbInfo.Server)\$($dbInfo.Database)" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# === BepozLogger (OPTIONAL) ===
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($loggerModule) {
    . $loggerModule.FullName
    $logFile = Initialize-BepozLogger -ToolName "TOOLNAME"
    if ($logFile) {
        Write-Host "[Logger] Logging to: $logFile" -ForegroundColor Gray
        Write-BepozLogAction "Tool started"
    }
}
else {
    Write-Host "[Logger] BepozLogger not found - logging disabled" -ForegroundColor Yellow
}

# === BepozUI (OPTIONAL) ===
$uiModule = Get-ChildItem -Path $env:TEMP -Filter "BepozUI.ps1" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($uiModule) {
    . $uiModule.FullName
    Write-Host "[UI] BepozUI helpers loaded" -ForegroundColor Gray
}
else {
    Write-Host "[UI] BepozUI not found - using standard controls" -ForegroundColor Yellow
}

#endregion
```

**Remember to replace "TOOLNAME" with your actual tool name!**

---

## Troubleshooting

### Issue: "BepozDbCore module not found"

**Cause:** Tool run directly instead of through toolkit

**Solution:** Tools must be run through `Invoke-BepozToolkit.ps1` or `Invoke-BepozToolkit-GUI.ps1`

### Issue: Logging not working

**Cause:** BepozLogger module not uploaded to GitHub yet

**Solution:**
1. Upload `modules/BepozLogger.ps1` to GitHub
2. Update `manifest.json` to include BepozLogger
3. Run toolkit to download the module

### Issue: "The term 'Invoke-BepozQuery' is not recognized"

**Cause:** BepozDbCore module failed to load or old version

**Solution:**
1. Verify module loading code is correct
2. Check that GitHub has latest BepozDbCore v1.3.0
3. Clear TEMP and rerun toolkit to re-download

### Issue: DataTable has no rows after migration

**Cause:** Missing `Write-Output -NoEnumerate` in module

**Solution:** Verify you're using BepozDbCore v1.3.0+ which includes this fix

---

## Files to Update on GitHub

After migrating a script, update these files on GitHub:

1. **tools/YourToolName.ps1** - The migrated script
2. **manifest.json** - Add/update tool entry with new version
3. **modules/BepozDbCore.ps1** - Ensure v1.3.0+ is uploaded
4. **modules/BepozLogger.ps1** - Ensure v1.0.0+ is uploaded
5. **modules/BepozUI.ps1** - Ensure v1.0.0+ is uploaded (if used)

---

## Summary

**Migration reduces code by:**
- 200-300 lines of DB code → 15 lines (BepozDbCore)
- 30-50 lines per UI dialog → 3-5 lines (BepozUI)
- Adds comprehensive logging with minimal code

**Migration time per script:**
- Simple script: 10-15 minutes
- Complex script: 30-45 minutes

**Benefits:**
- ✅ Less code to maintain
- ✅ Consistent behavior across tools
- ✅ Automatic performance logging
- ✅ Better error handling
- ✅ Easier troubleshooting

---

**For Claude Code:** Follow this guide step-by-step to migrate scripts efficiently and safely.
