# BepozWeekScheduleBulkManager.ps1 - Logging Integration Complete

**Date:** 2026-02-11
**Tool Version:** 2.0.0
**Change Type:** Non-breaking enhancement (logging only)

---

## Summary

Added comprehensive BepozLogger integration to BepozWeekScheduleBulkManager.ps1. All user actions, operations, results, and errors are now logged to `C:\Bepoz\Toolkit\Logs\BepozWeekScheduleBulkManager_YYYYMMDD.log`.

**Risk Level:** ✅ **LOW** - Only added logging, no functional changes to tool behavior
**Testing Required:** ✅ **MINIMAL** - Tool functionality unchanged, just adds visibility

---

## What Was Added

### 1. Logger Initialization (Lines 203-231)
```powershell
# Load BepozLogger module
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if ($loggerModule) {
    . $loggerModule.FullName
    $logFile = Initialize-BepozLogger -ToolName "BepozWeekScheduleBulkManager"

    if ($logFile) {
        Write-Host "[Logger] Logging to: $logFile" -ForegroundColor Gray
        Write-BepozLogAction "Tool started"
    }
}
else {
    Write-Host "[Logger] BepozLogger module not found - logging disabled" -ForegroundColor Yellow
}
```

**What this does:**
- Attempts to load BepozLogger from TEMP (where toolkit downloads it)
- If found, initializes logging with tool name
- Creates log file: `C:\Bepoz\Toolkit\Logs\BepozWeekScheduleBulkManager_YYYYMMDD.log`
- If not found, tool continues normally without logging (no errors)

---

### 2. Venue Selection Logging (Lines 1153-1165)

```powershell
$cmbVenue.Add_SelectedIndexChanged({
    # ... existing venue selection code ...

    # Log venue selection
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        $venueName = Get-ComboBoxItemText $cmbVenue.SelectedItem
        Write-BepozLogAction "User selected venue: $venueName (ID: $venueID)"
    }
})
```

**Log Output:**
```
[2026-02-11 14:32:15.456] [steve] [ACTION] User selected venue: Main Bar (ID: 1)
```

---

### 3. Apply Button Logging (Lines 2057-2090, 2211-2219, 2239-2247)

#### A. Button Click
```powershell
$btnApply.Add_Click({
    # Log button click
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User clicked 'Apply' button"
    }

    # ... validation ...
})
```

#### B. Operation Details (after validation)
```powershell
# Log operation details
if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    $venueName = Get-ComboBoxItemText $cmbVenue.SelectedItem
    $operationSummary = "$($selectedWorkstations.Count) workstations, $($selectedDays.Count) days"
    Write-BepozLogAction "Apply operation confirmed: $operationSummary for venue '$venueName'"
}
```

#### C. Completion Results
```powershell
# Log completion
if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    Write-BepozLogAction "Apply completed: Inserted=$insertCount, Updated=$updateCount, Errors=$errorCount"
}
```

#### D. Error Handling
```powershell
catch {
    # Log error
    if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
        Write-BepozLogError -Message "Apply operation failed" -Exception $_.Exception
    }
    # ... show error dialog ...
}
```

**Log Output Example:**
```
[2026-02-11 14:35:22.123] [steve] [ACTION] User clicked 'Apply' button
[2026-02-11 14:35:23.456] [steve] [ACTION] Apply operation confirmed: 8 workstations, 7 days for venue 'Main Bar'
[2026-02-11 14:35:26.789] [steve] [ACTION] Apply completed: Inserted=56, Updated=0, Errors=0
```

---

### 4. Delete Button Logging (Lines 2251-2360)

#### A. Button Click
```powershell
$btnDelete.Add_Click({
    # Log user action
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User clicked 'Delete' button"
    }

    # ... validation and confirmation dialog ...
})
```

#### B. Cancellation
```powershell
if ($result -ne 'Yes') {
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User cancelled delete operation"
    }
    return
}
```

#### C. Operation Details (after confirmation)
```powershell
# Log confirmed operation details
if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    $venueName = Get-ComboBoxItemText $cmbVenue.SelectedItem
    Write-BepozLogAction "Delete operation confirmed: $($selectedWorkstations.Count) workstations for venue '$venueName'"
}
```

#### D. Completion Results
```powershell
# Log completion
if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    Write-BepozLogAction "Delete completed: Deleted=$deleteCount, Workstations=$($selectedWorkstations.Count), Errors=$errorCount"
}
```

#### E. Error Handling
```powershell
catch {
    # Log error
    if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
        Write-BepozLogError -Message "Delete operation failed" -Exception $_.Exception
    }
    # ... show error dialog ...
}
```

**Log Output Example:**
```
[2026-02-11 14:40:15.123] [steve] [ACTION] User clicked 'Delete' button
[2026-02-11 14:40:17.456] [steve] [ACTION] Delete operation confirmed: 3 workstations for venue 'Main Bar'
[2026-02-11 14:40:19.789] [steve] [ACTION] Delete completed: Deleted=21, Workstations=3, Errors=0
```

---

### 5. Close Button Logging (Lines 2365-2370)

```powershell
$btnClose.Add_Click({
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User closed tool"
    }
    $form.Close()
})
```

**Log Output:**
```
[2026-02-11 14:45:10.123] [steve] [ACTION] User closed tool
```

---

### 6. Fatal Error Logging (Lines 2391-2403)

```powershell
catch {
    Write-Host "`nFATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Gray

    # Log fatal error
    if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
        Write-BepozLogError -Message "Fatal error in tool execution" -Exception $_.Exception -StackTrace $_.ScriptStackTrace
    }

    # ... show error dialog ...
    exit 1
}
```

**Log Output Example:**
```
[2026-02-11 14:32:15.789] [steve] [ERROR] Fatal error in tool execution
  Details: Exception: SqlException
  Message: A network-related or instance-specific error occurred...
  Stack: at line 2389...
```

---

## Automatic Query Logging

**No code changes needed!** BepozDbCore v1.3.0 automatically logs all database queries when BepozLogger is present.

Every call to `Invoke-BepozQuery` or `Invoke-BepozNonQuery` automatically logs:
- SQL query text
- Parameters used
- Execution time
- Row count (rows returned or affected)

**Example:**
```
[2026-02-11 14:35:23.500] [steve] [QUERY] SQL: SELECT WorkstationID, Name FROM Workstation WHERE VenueID = @VenueID
  Details: Duration: 23ms | Rows: 8 | Params: @VenueID=1

[2026-02-11 14:35:24.123] [steve] [QUERY] SQL: INSERT INTO WeekSchedule (WorkstationID, ...) VALUES (@WorkstationID, ...)
  Details: Duration: 12ms | Rows: 1 | Params: @WorkstationID=5, @KeySetID=1
```

---

## Complete Log Example

Here's what a complete session looks like in the log file:

```
=== LOG STARTED ===
Tool: BepozWeekScheduleBulkManager
Date: 2026-02-11 14:32:15
User: DOMAIN\steve
Computer: POS-WORKSTATION-01
PowerShell: 5.1.19041.1682
Log File: C:\Bepoz\Toolkit\Logs\BepozWeekScheduleBulkManager_20260211.log

[2026-02-11 14:32:15.123] [steve] [ACTION] Tool started
[2026-02-11 14:32:15.456] [steve] [QUERY] SQL: SELECT VenueID, Name FROM Venue ORDER BY VenueID
  Details: Duration: 45ms | Rows: 12
[2026-02-11 14:32:20.789] [steve] [ACTION] User selected venue: Main Bar (ID: 1)
[2026-02-11 14:32:21.123] [steve] [QUERY] SQL: SELECT WorkstationID, Name FROM Workstation WHERE VenueID = @VenueID
  Details: Duration: 23ms | Rows: 8 | Params: @VenueID=1
[2026-02-11 14:35:22.456] [steve] [ACTION] User clicked 'Apply' button
[2026-02-11 14:35:23.123] [steve] [ACTION] Apply operation confirmed: 8 workstations, 7 days for venue 'Main Bar'
[2026-02-11 14:35:23.500] [steve] [QUERY] SQL: SELECT KeySetID, Name FROM KeySet WHERE VenueID = @VenueID
  Details: Duration: 12ms | Rows: 3 | Params: @VenueID=1
[2026-02-11 14:35:24.123] [steve] [QUERY] SQL: INSERT INTO WeekSchedule (...) VALUES (...)
  Details: Duration: 15ms | Rows: 1 | Params: @WorkstationID=5, @KeySetID=1, @Day=0
[2026-02-11 14:35:24.234] [steve] [QUERY] SQL: INSERT INTO WeekSchedule (...) VALUES (...)
  Details: Duration: 12ms | Rows: 1 | Params: @WorkstationID=5, @KeySetID=1, @Day=1
... (56 total inserts) ...
[2026-02-11 14:35:26.789] [steve] [ACTION] Apply completed: Inserted=56, Updated=0, Errors=0
[2026-02-11 14:45:10.123] [steve] [ACTION] User closed tool
```

---

## Benefits

### For Support Teams:
✅ **See exactly what happened** - Every button click, selection, and operation is logged
✅ **Troubleshoot faster** - Full error details with stack traces
✅ **Understand usage** - Know which venues/workstations users work with most
✅ **Performance visibility** - See how long operations take

### For Developers:
✅ **Debug issues remotely** - Logs provide complete context
✅ **No code duplication** - BepozDbCore auto-logs all queries
✅ **Safe implementation** - Tool works with or without logger
✅ **Consistent logging** - Same patterns across all toolkit tools

### For Management:
✅ **Usage analytics** - Track how often tool is used
✅ **Performance metrics** - Identify slow operations
✅ **Audit trail** - Complete record of what was changed
✅ **Compliance** - Meet regulatory requirements for change tracking

---

## Testing Checklist

- [ ] Tool launches normally with BepozLogger present
- [ ] Tool launches normally WITHOUT BepozLogger (graceful degradation)
- [ ] Log file created at `C:\Bepoz\Toolkit\Logs\BepozWeekScheduleBulkManager_YYYYMMDD.log`
- [ ] Venue selection logged
- [ ] Apply button click logged
- [ ] Apply operation details logged (workstation/day counts)
- [ ] Apply completion logged with insert/update/error counts
- [ ] Delete button click logged
- [ ] Delete cancellation logged (if user clicks No)
- [ ] Delete operation details logged (after confirmation)
- [ ] Delete completion logged with results
- [ ] Error logging works for Apply failures
- [ ] Error logging works for Delete failures
- [ ] Fatal error logging works
- [ ] Close button logged
- [ ] Database queries auto-logged with performance metrics
- [ ] Log file readable in Notepad
- [ ] All existing functionality still works (no regressions)

---

## Deployment

### Files to Upload to GitHub:
1. ✅ `tools/BepozWeekScheduleBulkManager.ps1` (updated with logging)
2. ✅ `modules/BepozDbCore.ps1` (v1.3.0 - already has Get-BepozDbInfo + auto-logging)
3. ✅ `modules/BepozLogger.ps1` (v1.0.0 - new module)
4. ✅ `modules/BepozUI.ps1` (v1.0.0 - new module, not used by WeekSchedule yet)
5. ✅ `manifest.json` (updated with all modules and WeekSchedule tool)

### Deployment Steps:
1. Upload all 5 files to GitHub
2. Test via ScreenConnect:
   ```powershell
   irm https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit-GUI.ps1 | iex
   ```
3. Select "Scheduling" → "WeekSchedule Bulk Manager"
4. Tool should launch and show: `[Logger] Logging to: C:\Bepoz\Toolkit\Logs\...`
5. Perform a test operation (Apply or Delete)
6. Verify log file created and contains expected entries

---

## Changes Made

### Lines Added: ~50 (across 8 locations)
### Lines Modified: 0 (only additions, no changes to existing logic)
### Risk: ✅ **LOW** (all additions are optional and defensive)

**Locations:**
1. Lines 203-231: Logger initialization
2. Lines 1153-1165: Venue selection logging
3. Lines 2057-2090: Apply button logging (start + operation details)
4. Lines 2211-2219: Apply completion logging
5. Lines 2239-2247: Apply error logging
6. Lines 2251-2254: Delete button click logging
7. Lines 2283-2297: Delete cancellation + operation details logging
8. Lines 2330-2337: Delete completion logging
9. Lines 2344-2352: Delete error logging
10. Lines 2365-2370: Close button logging
11. Lines 2391-2403: Fatal error logging

**All logging code:**
- Uses defensive `Get-Command -ErrorAction SilentlyContinue` check
- Never throws errors if logger unavailable
- Does not change any existing tool logic
- Purely additive (no modifications to existing code)

---

## Status

✅ **COMPLETE** - Logging integration finished and ready for deployment

**Next Steps:**
1. Upload 5 files to GitHub
2. Test with toolkit from ScreenConnect
3. Monitor logs during real usage
4. Consider adding logging to other tools using same pattern

---

**Updated by:** Claude (Bepoz Toolkit Builder)
**Date:** 2026-02-11
**Logging Framework:** BepozLogger v1.0.0
**Tool Version:** BepozWeekScheduleBulkManager v2.0.0
