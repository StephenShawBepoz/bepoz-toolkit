# Bepoz Toolkit - Centralized Logging Guide

**Production logging for all toolkit tools**

All tools can now write to centralized logs at `C:\Bepoz\Toolkit\Logs\` with automatic query logging, performance metrics, and user action tracking.

---

## Quick Start

### 1. Load BepozLogger in Your Tool

```powershell
# At the top of your tool (after loading BepozDbCore)
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if ($loggerModule) {
    . $loggerModule.FullName
    Initialize-BepozLogger -ToolName "MyToolName"
}
```

### 2. Database Queries Are Logged Automatically

**No code changes needed!** BepozDbCore v1.3.0+ automatically logs all queries:

```powershell
# This query gets logged automatically with performance metrics
$venues = Invoke-BepozQuery -Query "SELECT * FROM Venue WHERE Active = 1"

# Log entry created:
# [2026-02-11 14:32:15.123] [steve] [QUERY] SQL: SELECT * FROM Venue WHERE Active = 1
#   Details: Duration: 45ms | Rows: 12
```

### 3. Log User Actions

```powershell
# Log when user clicks buttons or selects items
Write-BepozLogAction "User clicked 'Run Tool' button"
Write-BepozLogAction "Selected venue: $($venueName) (ID: $venueId)"
Write-BepozLogAction "Bulk operation started: 150 workstations"
```

### 4. Log Performance Metrics

```powershell
# Manually log performance for specific operations
$result = Measure-BepozOperation -Name "Bulk insert WeekSchedule" -ScriptBlock {
    # Your code here
    foreach ($ws in $workstations) {
        Insert-WeekSchedule -WorkstationID $ws.ID -Data $scheduleData
    }
}

# Or log manually
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
# ... do work ...
$stopwatch.Stop()
Write-BepozLogPerformance -Operation "Load GUI data" -DurationMs $stopwatch.ElapsedMilliseconds -ItemCount 50
```

### 5. Log Errors

```powershell
try {
    # Your code
}
catch {
    Write-BepozLogError -Message "Failed to process venue" -Exception $_.Exception
    # Or with stack trace
    Write-BepozLogError -Message "Critical error" -Exception $_.Exception -StackTrace $_.ScriptStackTrace
}
```

---

## Log Location

### Primary Location
```
C:\Bepoz\Toolkit\Logs\
├── MyTool_20260211.log
├── WeekScheduleBulkManager_20260211.log
├── UserTool_20260211.log
└── ... (one file per tool per day)
```

### Fallback Location
If `C:\Bepoz\Toolkit\Logs\` cannot be created (permissions), logs fallback to:
```
C:\Temp\BepozToolkit\Logs\
```

---

## Log Format

```
[YYYY-MM-DD HH:MM:SS.fff] [username] [LEVEL] Message
  Details: Additional information
```

**Example:**
```
[2026-02-11 14:32:15.123] [steve] [ACTION] User clicked 'Run Tool' button
[2026-02-11 14:32:15.456] [steve] [QUERY] SQL: SELECT VenueID, Name FROM Venue WHERE Active = 1
  Details: Duration: 45ms | Rows: 12 | Params: @Active=1
[2026-02-11 14:32:18.789] [steve] [PERF] PERF: Bulk insert completed in 3234ms
  Details: Items: 150 | Avg: 21.56ms/item
[2026-02-11 14:35:22.111] [steve] [ERROR] Database connection failed
  Details: Exception: SqlException
  Message: A network-related or instance-specific error occurred...
```

---

## Log Levels

| Level | Purpose | Example |
|-------|---------|---------|
| **INFO** | General information | "Tool started", "Configuration loaded" |
| **ACTION** | User interactions | "User clicked button", "Selected venue" |
| **QUERY** | Database queries (auto-logged) | "SQL: SELECT * FROM Venue" |
| **PERF** | Performance metrics | "Operation completed in 123ms" |
| **SUCCESS** | Successful operations | "Tool completed successfully" |
| **WARN** | Warnings | "Feature not available in this version" |
| **ERROR** | Errors and exceptions | "Failed to connect to database" |

---

## Available Functions

### Core Logging

#### `Initialize-BepozLogger`
**Required** - Call at tool startup
```powershell
Initialize-BepozLogger -ToolName "MyTool"
# Returns: Path to log file
```

#### `Write-BepozLog`
Generic logging function
```powershell
Write-BepozLog -Message "Something happened" -Level INFO -Details "Extra info"
```

### Specialized Logging

#### `Write-BepozLogAction`
Log user actions
```powershell
Write-BepozLogAction "User opened tool"
Write-BepozLogAction "Selected workstation: ID=5"
```

#### `Write-BepozLogQuery`
Log database queries (usually auto-logged by BepozDbCore)
```powershell
Write-BepozLogQuery -Query $sql -Parameters $params -DurationMs 45 -RowCount 12
```

#### `Write-BepozLogPerformance`
Log performance metrics
```powershell
Write-BepozLogPerformance -Operation "Data load" -DurationMs 1234 -ItemCount 100
```

#### `Write-BepozLogError`
Log errors with full details
```powershell
Write-BepozLogError -Message "Operation failed" -Exception $_.Exception
```

### Helper Functions

#### `Measure-BepozOperation`
Automatically measure and log operation timing
```powershell
$result = Measure-BepozOperation -Name "Load venues" -ScriptBlock {
    Invoke-BepozQuery -Query "SELECT * FROM Venue"
}
# Automatically logs performance
```

#### `Get-BepozLogPath`
Get current log file path
```powershell
$logPath = Get-BepozLogPath
Write-Host "Logs: $logPath"
```

---

## Complete Tool Example

```powershell
<#
.SYNOPSIS
    Example tool with full logging
#>

#region Load Modules
# Load BepozDbCore
$dbModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" | Select-Object -First 1
if ($dbModule) { . $dbModule.FullName }

# Load BepozLogger
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" | Select-Object -First 1
if ($loggerModule) {
    . $loggerModule.FullName
    $logFile = Initialize-BepozLogger -ToolName "ExampleTool"
    Write-Host "Logging to: $logFile" -ForegroundColor Gray
}
#endregion

#region Main Tool Logic
try {
    Write-BepozLogAction "Tool started"

    # Database queries are auto-logged by BepozDbCore
    $venues = Invoke-BepozQuery -Query "SELECT * FROM Venue WHERE Active = 1"
    Write-BepozLogAction "Loaded $($venues.Rows.Count) active venues"

    # Measure performance of operation
    $result = Measure-BepozOperation -Name "Process venues" -ScriptBlock {
        foreach ($row in $venues.Rows) {
            # Process each venue
            Write-Host "Processing: $($row.Name)"
        }
    }

    Write-BepozLogAction "Tool completed successfully"

} catch {
    Write-BepozLogError -Message "Tool failed" -Exception $_.Exception
    throw
}
#endregion
```

**Log Output:**
```
=== LOG STARTED ===
Tool: ExampleTool
Date: 2026-02-11 14:32:15
User: DOMAIN\steve
Computer: POS-WORKSTATION-01
PowerShell: 5.1.19041.1682
Log File: C:\Bepoz\Toolkit\Logs\ExampleTool_20260211.log

[2026-02-11 14:32:15.123] [steve] [ACTION] Tool started
[2026-02-11 14:32:15.456] [steve] [QUERY] SQL: SELECT * FROM Venue WHERE Active = 1
  Details: Duration: 45ms | Rows: 12
[2026-02-11 14:32:15.500] [steve] [ACTION] Loaded 12 active venues
[2026-02-11 14:32:18.789] [steve] [PERF] PERF: Process venues completed in 3289ms
[2026-02-11 14:32:18.800] [steve] [ACTION] Tool completed successfully
```

---

## Log Rotation

**Automatic:** Old logs are deleted after 30 days

**Manual cleanup:**
```powershell
# Delete logs older than 7 days
Get-ChildItem C:\Bepoz\Toolkit\Logs -Filter *.log |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
    Remove-Item -Force
```

---

## Viewing Logs

### Via ScreenConnect
```powershell
# Show last 50 lines of today's log
Get-Content "C:\Bepoz\Toolkit\Logs\MyTool_20260211.log" -Tail 50
```

### Via PowerShell
```powershell
# Open log in notepad
notepad "C:\Bepoz\Toolkit\Logs\MyTool_20260211.log"

# Search for errors
Select-String -Path "C:\Bepoz\Toolkit\Logs\*.log" -Pattern "\[ERROR\]"

# Show all queries
Select-String -Path "C:\Bepoz\Toolkit\Logs\*.log" -Pattern "\[QUERY\]"
```

### Via Log Analyzer (Optional)
Create a simple log viewer tool that parses and displays logs in a GUI.

---

## Benefits

### For Support Teams:
✅ **Troubleshooting** - See exactly what happened when tool failed
✅ **User Activity** - Know what users clicked/selected
✅ **Performance** - Identify slow operations
✅ **Auditing** - Track who ran what and when

### For Developers:
✅ **Debugging** - Full query and error details
✅ **Optimization** - Performance metrics show bottlenecks
✅ **Consistency** - All tools log the same way
✅ **Centralized** - One place to look for all logs

### For Management:
✅ **Usage Analytics** - See which tools are used most
✅ **Performance Trends** - Track system performance over time
✅ **Compliance** - Complete audit trail
✅ **Support Efficiency** - Faster issue resolution

---

## Integration with Existing Tools

### For New Tools:
1. Copy template from `Tool-Template.ps1`
2. Initialize logger at startup
3. Log user actions as appropriate
4. Database queries auto-logged ✅

### For Existing Tools (Migration):
1. Add BepozLogger loading code (10 lines)
2. Call `Initialize-BepozLogger` at startup
3. Add `Write-BepozLogAction` for user interactions
4. Database queries auto-logged ✅ (if using BepozDbCore v1.3.0+)
5. Optionally wrap operations in `Measure-BepozOperation`

**Time to add logging to existing tool:** 15-30 minutes

---

## FAQ

**Q: Do I have to use logging?**
A: No, it's optional. But highly recommended for production tools.

**Q: Will logging slow down my tool?**
A: Minimal impact. Logging is asynchronous and typically adds < 1ms per entry.

**Q: What if C:\Bepoz\Toolkit\Logs\ can't be created?**
A: Automatically falls back to C:\Temp\BepozToolkit\Logs\

**Q: Are database queries logged even if I don't call Write-BepozLogQuery?**
A: Yes! BepozDbCore v1.3.0+ auto-logs all queries if BepozLogger is loaded.

**Q: Can I disable logging temporarily?**
A: Yes, just don't load BepozLogger module. Tools work fine without it.

**Q: How big do log files get?**
A: Depends on tool usage. Typical tool: 1-5 MB per day. Heavy tools: 10-50 MB per day.

**Q: Can I log to a network share instead?**
A: Not currently, but planned for v2.0. You can manually copy logs to network share.

**Q: What about sensitive data (passwords, credit cards)?**
A: Never log sensitive data! BepozLogger doesn't automatically sanitize. You're responsible for not logging sensitive info.

---

## Troubleshooting

### Logs not being created

**Check:**
1. Is BepozLogger module loaded? `Get-Command Write-BepozLog`
2. Did you call `Initialize-BepozLogger`?
3. Check fallback location: `C:\Temp\BepozToolkit\Logs\`

### Queries not being logged

**Check:**
1. Is BepozLogger loaded before BepozDbCore queries run?
2. Is BepozDbCore v1.3.0 or higher? `(Get-Module BepozDbCore).Version`
3. Check if log file exists and is writable

### Permission errors

**Solution:**
- Run tool as logged-in user (not SYSTEM)
- Or use fallback temp location
- Or manually create `C:\Bepoz\Toolkit\Logs\` with write permissions

---

## Summary

**Adding logging to your tool:**
1. Load BepozLogger module (5 lines)
2. Call `Initialize-BepozLogger` (1 line)
3. Log user actions with `Write-BepozLogAction` (as needed)
4. Database queries auto-logged ✅
5. Done!

**Log location:** `C:\Bepoz\Toolkit\Logs\ToolName_YYYYMMDD.log`

**Log retention:** 30 days (automatic)

**What's logged:**
- ✅ User actions (manual)
- ✅ Database queries (automatic)
- ✅ Performance metrics (manual or automatic)
- ✅ Errors and warnings (manual)

**Questions?** See examples in updated `Tool-Template.ps1`
