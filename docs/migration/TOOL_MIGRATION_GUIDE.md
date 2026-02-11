# Tool Migration Guide - Using Centralized BepozDbCore

**How to update existing tools to use the GitHub-based BepozDbCore module**

This guide shows you how to convert tools with embedded database code to use the centralized BepozDbCore.ps1 module from GitHub.

---

## Why Migrate?

### Before (Old Way):
- Each tool has its own DB connection code
- Registry discovery duplicated in every tool
- Inconsistent error handling
- Hard to maintain (update 10 tools = 10 places to change)
- Large tool files

### After (New Way):
- Tools use centralized BepozDbCore module
- Downloaded fresh from GitHub every run
- Consistent patterns across all tools
- Single place to update DB logic
- Smaller tool files

---

## Migration Process

### Step 1: Identify What to Remove

Look for these patterns in your existing tools that should be **deleted**:

#### ❌ Remove: Registry Discovery Code
```powershell
# DELETE THIS:
$regPath = 'HKCU:\SOFTWARE\Backoffice'
$props = Get-ItemProperty -Path $regPath
$sqlServer = $props.SQL_Server
$sqlDb = $props.SQL_DSN
```

#### ❌ Remove: Connection String Building
```powershell
# DELETE THIS:
$connStr = "Server=$sqlServer;Database=$sqlDb;Integrated Security=True;..."
```

#### ❌ Remove: Query Functions
```powershell
# DELETE THIS:
function Invoke-DatabaseQuery {
    param([string]$Query)
    # ... SqlConnection, SqlCommand, SqlDataAdapter code ...
}
```

#### ❌ Remove: ExecuteNonQuery Functions
```powershell
# DELETE THIS:
function Execute-DatabaseCommand {
    param([string]$Command)
    # ... ExecuteNonQuery code ...
}
```

#### ❌ Remove: Manual SqlConnection Objects
```powershell
# DELETE THIS:
$conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
$cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
# etc...
```

---

## Step 2: Add Module Loading

### ✅ Add This to Your Tool

Add this section **after** your script header but **before** your main logic:

```powershell
#region BepozDbCore Module Loading
function Get-BepozDbModule {
    <#
    .SYNOPSIS
        Loads BepozDbCore module (downloaded by toolkit)
    #>

    # Check if already loaded
    if (Get-Command -Name Invoke-BepozQuery -ErrorAction SilentlyContinue) {
        Write-Host "[✓] BepozDbCore module already loaded" -ForegroundColor Green
        return $true
    }

    # Try to find module in temp directory (downloaded by toolkit)
    $tempModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

    if ($tempModule) {
        try {
            . $tempModule.FullName
            Write-Host "[✓] Loaded BepozDbCore from: $($tempModule.FullName)" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "[✗] Failed to load BepozDbCore: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    # Module not found
    Write-Host "[!] BepozDbCore module not found in temp" -ForegroundColor Yellow
    Write-Host "[!] Tool may not function correctly without database access" -ForegroundColor Yellow
    return $false
}

# Load the module
$dbLoaded = Get-BepozDbModule
if (-not $dbLoaded) {
    Write-Host ""
    Write-Host "WARNING: Database module not available" -ForegroundColor Yellow
    Write-Host "This tool requires BepozDbCore.ps1 to access the database" -ForegroundColor Yellow
    Write-Host ""
    # Optionally exit or continue with limited functionality
}
#endregion
```

---

## Step 3: Update Database Calls

### ✅ Replace Old Queries

**Old Way:**
```powershell
# OLD CODE - DELETE THIS
$conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
$conn.Open()
$cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
$dt = New-Object System.Data.DataTable
$adapter.Fill($dt) | Out-Null
$conn.Close()

foreach ($row in $dt.Rows) {
    # Process rows
}
```

**New Way:**
```powershell
# NEW CODE - USE THIS
$query = "SELECT VenueID, Name FROM dbo.Venue WHERE Active = 1"
$result = Invoke-BepozQuery -Query $query

if ($result -and $result.Rows.Count -gt 0) {
    foreach ($row in $result.Rows) {
        Write-Host "$($row.VenueID): $($row.Name)"
    }
} else {
    Write-Host "No results found"
}
```

### ✅ Replace Parameterized Queries

**Old Way:**
```powershell
# OLD CODE - DELETE THIS
$cmd.Parameters.AddWithValue("@VenueID", $venueId)
$cmd.Parameters.AddWithValue("@Name", $venueName)
```

**New Way:**
```powershell
# NEW CODE - USE THIS
$params = @{
    "@VenueID" = $venueId
    "@Name" = $venueName
}
$result = Invoke-BepozQuery -Query $query -Parameters $params
```

### ✅ Replace UPDATE/INSERT/DELETE Commands

**Old Way:**
```powershell
# OLD CODE - DELETE THIS
$cmd = New-Object System.Data.SqlClient.SqlCommand($updateQuery, $conn)
$cmd.Parameters.AddWithValue("@VenueID", $venueId)
$rowsAffected = $cmd.ExecuteNonQuery()
```

**New Way:**
```powershell
# NEW CODE - USE THIS
$params = @{"@VenueID" = $venueId}
$rowsAffected = Invoke-BepozNonQuery -Query $updateQuery -Parameters $params

if ($rowsAffected -gt 0) {
    Write-Host "Updated $rowsAffected rows successfully"
}
```

### ✅ Replace Stored Procedure Calls

**Old Way:**
```powershell
# OLD CODE - DELETE THIS
$cmd.CommandType = [System.Data.CommandType]::StoredProcedure
$cmd.CommandText = "dbo.GetVenueDetails"
```

**New Way:**
```powershell
# NEW CODE - USE THIS
$params = @{"@VenueID" = $venueId}
$result = Invoke-BepozStoredProc -ProcedureName "dbo.GetVenueDetails" -Parameters $params
```

---

## Complete Before/After Example

### Before (Old Tool - 150 lines):

```powershell
<#
.SYNOPSIS
    Weekly Schedule Tool (OLD VERSION)
#>

[CmdletBinding()]
param()

# Embedded DB code (50 lines)
$regPath = 'HKCU:\SOFTWARE\Backoffice'
$props = Get-ItemProperty -Path $regPath
$sqlServer = $props.SQL_Server
$sqlDb = $props.SQL_DSN
$connStr = "Server=$sqlServer;Database=$sqlDb;Integrated Security=True;"

function Get-Venues {
    $conn = New-Object System.Data.SqlClient.SqlConnection($connStr)
    $conn.Open()
    $query = "SELECT * FROM dbo.Venue"
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $conn)
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    $adapter.Fill($dt) | Out-Null
    $conn.Close()
    return $dt
}

# Main logic (100 lines)
Write-Host "Weekly Schedule Tool" -ForegroundColor Cyan
$venues = Get-Venues

foreach ($row in $venues.Rows) {
    Write-Host "Venue: $($row.Name)"
}

# ... rest of tool logic ...
```

### After (New Tool - 80 lines):

```powershell
<#
.SYNOPSIS
    Weekly Schedule Tool (NEW VERSION - uses BepozDbCore)
.NOTES
    Version: 2.0.0
    Migrated to use centralized BepozDbCore module
#>

[CmdletBinding()]
param()

#region BepozDbCore Module Loading
function Get-BepozDbModule {
    if (Get-Command -Name Invoke-BepozQuery -ErrorAction SilentlyContinue) {
        return $true
    }

    $tempModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

    if ($tempModule) {
        . $tempModule.FullName
        return $true
    }

    Write-Host "[!] BepozDbCore module not found" -ForegroundColor Yellow
    return $false
}

$dbLoaded = Get-BepozDbModule
if (-not $dbLoaded) {
    Write-Host "ERROR: Database module required" -ForegroundColor Red
    exit 2
}
#endregion

# Main logic (50 lines - much simpler!)
Write-Host "Weekly Schedule Tool" -ForegroundColor Cyan

$query = "SELECT VenueID, Name, Active FROM dbo.Venue ORDER BY Name"
$venues = Invoke-BepozQuery -Query $query

if ($venues -and $venues.Rows.Count -gt 0) {
    foreach ($row in $venues.Rows) {
        Write-Host "Venue: $($row.Name) (ID: $($row.VenueID))"
    }
} else {
    Write-Host "No venues found" -ForegroundColor Yellow
}

# ... rest of tool logic (simpler now!) ...
```

**Result:** 70 lines removed, cleaner code, centralized maintenance!

---

## Migration Checklist

For each tool you migrate:

### 1. Backup First
- [ ] Copy original tool to `.bak` file
- [ ] Commit to git (if using version control)

### 2. Remove Old Code
- [ ] Delete registry discovery code
- [ ] Delete connection string building
- [ ] Delete custom query functions
- [ ] Delete SqlConnection/SqlCommand objects
- [ ] Delete ExecuteNonQuery functions

### 3. Add New Code
- [ ] Add `Get-BepozDbModule` function
- [ ] Call module loading at start
- [ ] Handle module load failure gracefully

### 4. Update Queries
- [ ] Replace direct SqlConnection with `Invoke-BepozQuery`
- [ ] Replace ExecuteNonQuery with `Invoke-BepozNonQuery`
- [ ] Replace stored proc calls with `Invoke-BepozStoredProc`
- [ ] Convert parameters to hashtable format

### 5. Test
- [ ] Test with toolkit (CLI or GUI)
- [ ] Verify database connection works
- [ ] Verify queries return expected data
- [ ] Test error handling (disconnect network, test)
- [ ] Verify cleanup happens

### 6. Update Metadata
- [ ] Increment tool version in header
- [ ] Update version in `manifest.json`
- [ ] Add note: "Uses centralized BepozDbCore"
- [ ] Commit and push to GitHub

---

## Testing Your Migrated Tool

### Test Script:

```powershell
# 1. Download the tool locally
$toolUrl = "https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/tools/Your-Tool.ps1"
$toolPath = "$env:TEMP\Your-Tool.ps1"
Invoke-WebRequest -Uri $toolUrl -OutFile $toolPath

# 2. Download BepozDbCore to temp (simulate toolkit)
$moduleUrl = "https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/modules/BepozDbCore.ps1"
$modulePath = "$env:TEMP\BepozDbCore.ps1"
Invoke-WebRequest -Uri $moduleUrl -OutFile $modulePath

# 3. Run the tool
& $toolPath

# 4. Check exit code
if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: Tool ran correctly" -ForegroundColor Green
} else {
    Write-Host "ERROR: Tool failed with exit code $LASTEXITCODE" -ForegroundColor Red
}

# 5. Cleanup
Remove-Item $toolPath, $modulePath -Force
```

---

## Common Issues During Migration

### Issue 1: "BepozDbCore module not found"

**Cause:** Module not in temp or not downloaded by toolkit

**Fix:**
- Ensure module is in temp: `ls $env:TEMP\BepozDbCore.ps1`
- Toolkit should download it - check manifest.json
- Test by downloading manually (see test script above)

### Issue 2: "Invoke-BepozQuery not recognized"

**Cause:** Module didn't load or wrong function name

**Fix:**
- Check module loaded: `Get-Command Invoke-BepozQuery`
- Verify dot-sourcing worked: Add `-Verbose` to Get-BepozDbModule
- Check for typos in function name

### Issue 3: "Rows property not found"

**Cause:** Query returned null or not a DataTable

**Fix:**
```powershell
# ALWAYS check for null before accessing .Rows
$result = Invoke-BepozQuery -Query $query

if ($null -eq $result) {
    Write-Host "Query failed"
    exit 2
}

if ($result.Rows.Count -eq 0) {
    Write-Host "No results"
} else {
    foreach ($row in $result.Rows) {
        # Process...
    }
}
```

### Issue 4: Old code still being called

**Cause:** Didn't remove old functions completely

**Fix:**
- Search for `SqlConnection` in your tool - should find ZERO
- Search for `SqlCommand` - should find ZERO
- Search for `SqlDataAdapter` - should find ZERO
- If found, you missed some old code - delete it

### Issue 5: Parameters not working

**Cause:** Incorrect hashtable format

**Fix:**
```powershell
# CORRECT:
$params = @{
    "@VenueID" = $venueId  # ← Include @ prefix
    "@Name" = $name
}

# WRONG:
$params = @{
    "VenueID" = $venueId  # ← Missing @ prefix
}
```

---

## Quick Migration Script

Want to semi-automate the migration? Here's a helper script:

```powershell
<#
.SYNOPSIS
    Semi-automated tool migration helper
.DESCRIPTION
    Scans a tool file and identifies code that should be removed/updated
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ToolPath
)

Write-Host "Scanning tool for migration opportunities..." -ForegroundColor Cyan
Write-Host ""

$content = Get-Content $ToolPath -Raw

# Check for old DB patterns
$findings = @()

if ($content -match 'SqlConnection') {
    $findings += "❌ Found 'SqlConnection' - Replace with Invoke-BepozQuery"
}

if ($content -match 'SqlCommand') {
    $findings += "❌ Found 'SqlCommand' - Replace with Invoke-BepozQuery"
}

if ($content -match 'SqlDataAdapter') {
    $findings += "❌ Found 'SqlDataAdapter' - Replace with Invoke-BepozQuery"
}

if ($content -match 'HKCU:\\SOFTWARE\\Backoffice') {
    $findings += "❌ Found registry discovery - Remove (BepozDbCore handles this)"
}

if ($content -match 'ExecuteNonQuery') {
    $findings += "❌ Found ExecuteNonQuery - Replace with Invoke-BepozNonQuery"
}

if ($content -match 'CommandType.*StoredProcedure') {
    $findings += "❌ Found stored proc call - Replace with Invoke-BepozStoredProc"
}

if ($content -match 'Invoke-BepozQuery') {
    $findings += "✓ Already uses Invoke-BepozQuery"
}

if ($content -match 'Get-BepozDbModule') {
    $findings += "✓ Already has module loading function"
}

# Display results
if ($findings.Count -eq 0) {
    Write-Host "✓ No migration needed - tool looks good!" -ForegroundColor Green
} else {
    Write-Host "Migration required:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($finding in $findings) {
        Write-Host "  $finding"
    }
    Write-Host ""
    Write-Host "See TOOL_MIGRATION_GUIDE.md for step-by-step instructions" -ForegroundColor Cyan
}
```

Save as `Check-ToolMigration.ps1` and run:
```powershell
.\Check-ToolMigration.ps1 -ToolPath "C:\Path\To\Your-Tool.ps1"
```

---

## Summary

**Migration Steps:**
1. ✅ Remove all embedded DB code (registry, connections, queries)
2. ✅ Add `Get-BepozDbModule` function
3. ✅ Replace queries with `Invoke-BepozQuery`
4. ✅ Replace updates with `Invoke-BepozNonQuery`
5. ✅ Test thoroughly
6. ✅ Update version and push to GitHub

**Benefits:**
- 📉 Smaller tool files (30-50% reduction)
- 🔄 Centralized maintenance
- ✅ Consistent error handling
- 📦 Single source of truth
- 🚀 Easier to update DB logic

**Time Estimate:**
- Simple tool: 15-30 minutes
- Complex tool: 1-2 hours
- Testing per tool: 15 minutes

---

Need help migrating a specific tool? Share the code and I can help you refactor it!
