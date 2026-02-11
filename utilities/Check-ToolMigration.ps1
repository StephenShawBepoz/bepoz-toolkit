<#
.SYNOPSIS
    Tool Migration Checker - Identifies code that needs updating
.DESCRIPTION
    Scans a PowerShell tool file and identifies patterns that should be
    migrated to use the centralized BepozDbCore module instead of
    embedded database code.
.PARAMETER ToolPath
    Path to the tool file to analyze
.PARAMETER ShowDetails
    Show detailed line numbers and code snippets
.EXAMPLE
    .\Check-ToolMigration.ps1 -ToolPath "C:\Tools\Weekly-Schedule-Tool.ps1"
.EXAMPLE
    .\Check-ToolMigration.ps1 -ToolPath ".\User-Tool.ps1" -ShowDetails
.NOTES
    Version: 1.0.0
    Author: Bepoz Support Team
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ToolPath,

    [Parameter(Mandatory=$false)]
    [switch]$ShowDetails
)

# Validate file exists
if (-not (Test-Path $ToolPath)) {
    Write-Host "ERROR: File not found: $ToolPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  Tool Migration Checker" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "Analyzing: $ToolPath" -ForegroundColor White
Write-Host ""

# Read file
$content = Get-Content $ToolPath -Raw
$lines = Get-Content $ToolPath

# Initialize findings
$issues = @()
$positives = @()
$lineFindings = @()

#region Pattern Detection

# Check for old SqlClient patterns
if ($content -match 'System\.Data\.SqlClient\.SqlConnection') {
    $issues += @{
        Severity = "HIGH"
        Pattern = "SqlConnection"
        Message = "Found SqlConnection - Replace with Invoke-BepozQuery"
        Fix = "Remove SqlConnection code, use: Invoke-BepozQuery -Query `$query"
    }

    if ($ShowDetails) {
        $lineNum = 1
        foreach ($line in $lines) {
            if ($line -match 'SqlConnection') {
                $lineFindings += "  Line $lineNum`: $($line.Trim())"
            }
            $lineNum++
        }
    }
}

if ($content -match 'System\.Data\.SqlClient\.SqlCommand') {
    $issues += @{
        Severity = "HIGH"
        Pattern = "SqlCommand"
        Message = "Found SqlCommand - Replace with Invoke-BepozQuery"
        Fix = "Remove SqlCommand code, use Invoke-BepozQuery or Invoke-BepozNonQuery"
    }
}

if ($content -match 'System\.Data\.SqlClient\.SqlDataAdapter') {
    $issues += @{
        Severity = "HIGH"
        Pattern = "SqlDataAdapter"
        Message = "Found SqlDataAdapter - Replace with Invoke-BepozQuery"
        Fix = "Remove DataAdapter code, Invoke-BepozQuery returns DataTable directly"
    }
}

# Check for registry discovery
if ($content -match 'HKCU:\\SOFTWARE\\Backoffice') {
    $issues += @{
        Severity = "MEDIUM"
        Pattern = "Registry Discovery"
        Message = "Found registry discovery code - Remove (BepozDbCore handles this)"
        Fix = "Delete registry reading code, BepozDbCore does this automatically"
    }

    if ($ShowDetails) {
        $lineNum = 1
        foreach ($line in $lines) {
            if ($line -match 'Backoffice') {
                $lineFindings += "  Line $lineNum`: $($line.Trim())"
            }
            $lineNum++
        }
    }
}

# Check for connection string building
if ($content -match 'Server=.*Database=.*Integrated Security') {
    $issues += @{
        Severity = "MEDIUM"
        Pattern = "Connection String"
        Message = "Found connection string building - Remove (BepozDbCore handles this)"
        Fix = "Delete connection string code, use Get-BepozConnectionString if needed"
    }
}

# Check for ExecuteNonQuery
if ($content -match 'ExecuteNonQuery') {
    $issues += @{
        Severity = "MEDIUM"
        Pattern = "ExecuteNonQuery"
        Message = "Found ExecuteNonQuery - Replace with Invoke-BepozNonQuery"
        Fix = "Replace with: Invoke-BepozNonQuery -Query `$query -Parameters `$params"
    }
}

# Check for stored procedure patterns
if ($content -match 'CommandType.*StoredProcedure') {
    $issues += @{
        Severity = "MEDIUM"
        Pattern = "Stored Procedure"
        Message = "Found stored proc call - Replace with Invoke-BepozStoredProc"
        Fix = "Replace with: Invoke-BepozStoredProc -ProcedureName 'dbo.ProcName' -Parameters `$params"
    }
}

# Check for manual parameter addition
if ($content -match 'Parameters\.AddWithValue') {
    $issues += @{
        Severity = "LOW"
        Pattern = "Parameter Addition"
        Message = "Found manual parameter addition - Use hashtable instead"
        Fix = "Use: `$params = @{'@ParamName' = `$value}"
    }
}

# Check for positive patterns (already migrated)
if ($content -match 'Invoke-BepozQuery') {
    $positives += "✓ Already uses Invoke-BepozQuery"
}

if ($content -match 'Invoke-BepozNonQuery') {
    $positives += "✓ Already uses Invoke-BepozNonQuery"
}

if ($content -match 'Invoke-BepozStoredProc') {
    $positives += "✓ Already uses Invoke-BepozStoredProc"
}

if ($content -match 'Get-BepozDbModule') {
    $positives += "✓ Already has module loading function"
}

if ($content -match 'Get-BepozDatabaseConfig') {
    $positives += "✓ Uses BepozDbCore for configuration"
}

#endregion

#region Display Results

$totalIssues = $issues.Count

if ($totalIssues -eq 0 -and $positives.Count -gt 0) {
    Write-Host "✓ MIGRATION COMPLETE - Tool is already using BepozDbCore!" -ForegroundColor Green
    Write-Host ""
    foreach ($positive in $positives) {
        Write-Host "  $positive" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "No migration needed. Great job!" -ForegroundColor Green
    Write-Host ""
    exit 0
}

if ($totalIssues -eq 0) {
    Write-Host "✓ No obvious migration issues found" -ForegroundColor Green
    Write-Host ""
    Write-Host "However, manually verify that:" -ForegroundColor Yellow
    Write-Host "  1. Tool loads BepozDbCore module" -ForegroundColor Yellow
    Write-Host "  2. Tool uses Invoke-BepozQuery for SELECT queries" -ForegroundColor Yellow
    Write-Host "  3. Tool uses Invoke-BepozNonQuery for INSERT/UPDATE/DELETE" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# Display issues
Write-Host "MIGRATION REQUIRED - Found $totalIssues issue(s):" -ForegroundColor Yellow
Write-Host ""

$highCount = ($issues | Where-Object { $_.Severity -eq 'HIGH' }).Count
$medCount = ($issues | Where-Object { $_.Severity -eq 'MEDIUM' }).Count
$lowCount = ($issues | Where-Object { $_.Severity -eq 'LOW' }).Count

if ($highCount -gt 0) {
    Write-Host "HIGH PRIORITY ($highCount):" -ForegroundColor Red
    $issues | Where-Object { $_.Severity -eq 'HIGH' } | ForEach-Object {
        Write-Host "  ❌ $($_.Message)" -ForegroundColor Red
        Write-Host "     Fix: $($_.Fix)" -ForegroundColor Gray
        Write-Host ""
    }
}

if ($medCount -gt 0) {
    Write-Host "MEDIUM PRIORITY ($medCount):" -ForegroundColor Yellow
    $issues | Where-Object { $_.Severity -eq 'MEDIUM' } | ForEach-Object {
        Write-Host "  ⚠ $($_.Message)" -ForegroundColor Yellow
        Write-Host "     Fix: $($_.Fix)" -ForegroundColor Gray
        Write-Host ""
    }
}

if ($lowCount -gt 0) {
    Write-Host "LOW PRIORITY ($lowCount):" -ForegroundColor Cyan
    $issues | Where-Object { $_.Severity -eq 'LOW' } | ForEach-Object {
        Write-Host "  ℹ $($_.Message)" -ForegroundColor Cyan
        Write-Host "     Fix: $($_.Fix)" -ForegroundColor Gray
        Write-Host ""
    }
}

# Show positive patterns found
if ($positives.Count -gt 0) {
    Write-Host "GOOD NEWS - Already Migrated:" -ForegroundColor Green
    foreach ($positive in $positives) {
        Write-Host "  $positive" -ForegroundColor Green
    }
    Write-Host ""
}

# Show detailed line findings if requested
if ($ShowDetails -and $lineFindings.Count -gt 0) {
    Write-Host "DETAILED FINDINGS:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($finding in $lineFindings) {
        Write-Host $finding -ForegroundColor Gray
    }
    Write-Host ""
}

# Migration steps
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open TOOL_MIGRATION_GUIDE.md for detailed instructions" -ForegroundColor White
Write-Host "2. Backup this tool before making changes" -ForegroundColor White
Write-Host "3. Remove old database code (SqlConnection, registry, etc.)" -ForegroundColor White
Write-Host "4. Add Get-BepozDbModule function" -ForegroundColor White
Write-Host "5. Replace queries with Invoke-BepozQuery" -ForegroundColor White
Write-Host "6. Test thoroughly" -ForegroundColor White
Write-Host "7. Update version and push to GitHub" -ForegroundColor White
Write-Host ""

# Estimate complexity
if ($highCount -gt 3) {
    Write-Host "Estimated migration time: 1-2 hours (complex)" -ForegroundColor Yellow
} elseif ($highCount -gt 0) {
    Write-Host "Estimated migration time: 30-60 minutes (moderate)" -ForegroundColor Yellow
} else {
    Write-Host "Estimated migration time: 15-30 minutes (simple)" -ForegroundColor Green
}

Write-Host ""

#endregion

exit $totalIssues
