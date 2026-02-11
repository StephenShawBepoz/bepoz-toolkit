<#
.SYNOPSIS
    [Tool Name] - Brief description of what this tool does
.DESCRIPTION
    Detailed description of the tool's purpose and functionality.
    Include any important notes about prerequisites, behavior, or limitations.
.PARAMETER ExampleParam
    Description of any parameters the tool accepts
.EXAMPLE
    .\Tool-Template.ps1
    Runs the tool interactively
.EXAMPLE
    .\Tool-Template.ps1 -ExampleParam "Value"
    Runs the tool with a specific parameter
.NOTES
    Version: 1.0.0
    Author: Your Name
    Last Updated: 2026-02-11
    Category: [scheduling|smartposmobile|kiosk|tsplus|database|workstation]

    Requirements:
    - PowerShell 5.1+
    - Bepoz database access (reads HKCU:\SOFTWARE\Backoffice)
    - BepozDbCore.ps1 module (auto-downloaded by toolkit)
#>

[CmdletBinding()]
param(
    [string]$ExampleParam = ""
)

#region Configuration
$ErrorActionPreference = 'Stop'
$Script:ToolVersion = "1.0.0"
$Script:ToolName = "Tool Template"
#endregion

#region Helper Functions
function Write-ToolMessage {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Type = 'INFO'
    )

    $color = switch ($Type) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        default   { 'White' }
    }

    $prefix = switch ($Type) {
        'SUCCESS' { '[✓]' }
        'WARNING' { '[!]' }
        'ERROR'   { '[✗]' }
        default   { '[i]' }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates that all prerequisites are met before running the tool
    #>

    Write-ToolMessage "Checking prerequisites..." -Type INFO

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
        Write-ToolMessage "PowerShell 5.1 or higher required. Current: $($psVersion.ToString())" -Type ERROR
        return $false
    }

    # Check Bepoz registry keys
    $regPath = 'HKCU:\SOFTWARE\Backoffice'
    if (-not (Test-Path $regPath)) {
        Write-ToolMessage "Bepoz registry keys not found at: $regPath" -Type ERROR
        Write-ToolMessage "This tool must run on a Bepoz POS workstation" -Type ERROR
        return $false
    }

    try {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $sqlServer = $props.SQL_Server
        $sqlDb = $props.SQL_DSN

        if ([string]::IsNullOrWhiteSpace($sqlServer) -or [string]::IsNullOrWhiteSpace($sqlDb)) {
            Write-ToolMessage "Bepoz registry keys are incomplete" -Type ERROR
            Write-ToolMessage "Missing SQL_Server or SQL_DSN values" -Type ERROR
            return $false
        }

        Write-ToolMessage "Registry check passed: $sqlServer\$sqlDb" -Type SUCCESS

    } catch {
        Write-ToolMessage "Failed to read Bepoz registry: $($_.Exception.Message)" -Type ERROR
        return $false
    }

    return $true
}

function Get-BepozDbModule {
    <#
    .SYNOPSIS
        Attempts to load BepozDbCore module (downloaded by toolkit or from local path)
    #>

    # Check if already loaded
    if (Get-Command -Name Invoke-BepozQuery -ErrorAction SilentlyContinue) {
        Write-ToolMessage "BepozDbCore module already loaded" -Type SUCCESS
        return $true
    }

    # Try to find module in temp directory (downloaded by toolkit)
    $tempModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

    if ($tempModule) {
        try {
            . $tempModule.FullName
            Write-ToolMessage "Loaded BepozDbCore from: $($tempModule.FullName)" -Type SUCCESS
            return $true
        } catch {
            Write-ToolMessage "Failed to load BepozDbCore: $($_.Exception.Message)" -Type ERROR
            return $false
        }
    }

    # Module not found
    Write-ToolMessage "BepozDbCore module not found" -Type WARNING
    Write-ToolMessage "This tool requires BepozDbCore.ps1 to be available" -Type WARNING

    # For now, return true to allow tool to run without DB functions
    # Individual DB operations will fail gracefully
    return $true
}
#endregion

#region Main Tool Logic
function Start-Tool {
    <#
    .SYNOPSIS
        Main entry point for the tool
    #>

    try {
        # Display header
        Write-Host ""
        Write-Host ("=" * 70) -ForegroundColor Cyan
        Write-Host "  $Script:ToolName v$Script:ToolVersion" -ForegroundColor Cyan
        Write-Host ("=" * 70) -ForegroundColor Cyan
        Write-Host ""

        # Validate prerequisites
        if (-not (Test-Prerequisites)) {
            Write-Host ""
            Write-ToolMessage "Prerequisites check failed. Cannot continue." -Type ERROR
            return 1
        }

        # Load database module
        $dbLoaded = Get-BepozDbModule

        # --- START YOUR TOOL LOGIC HERE ---

        Write-Host ""
        Write-ToolMessage "Tool execution started..." -Type INFO

        # Example: Get venue information (requires BepozDbCore)
        if ($dbLoaded -and (Get-Command -Name Invoke-BepozQuery -ErrorAction SilentlyContinue)) {
            Write-Host ""
            Write-ToolMessage "Querying venue information..." -Type INFO

            $sql = "SELECT TOP 5 VenueID, Name, Active FROM dbo.Venue ORDER BY VenueID"
            $venues = Invoke-BepozQuery -Query $sql

            if ($venues -and $venues.Rows.Count -gt 0) {
                Write-ToolMessage "Found $($venues.Rows.Count) venues:" -Type SUCCESS
                foreach ($row in $venues.Rows) {
                    Write-Host ("  - VenueID {0}: {1} (Active: {2})" -f $row.VenueID, $row.Name, $row.Active)
                }
            } else {
                Write-ToolMessage "No venues found" -Type WARNING
            }
        }

        # Example: Interactive user input
        Write-Host ""
        $userInput = Read-Host "Enter a test value (or press Enter to skip)"

        if (-not [string]::IsNullOrWhiteSpace($userInput)) {
            Write-ToolMessage "You entered: $userInput" -Type SUCCESS
        } else {
            Write-ToolMessage "No input provided" -Type INFO
        }

        # --- END YOUR TOOL LOGIC HERE ---

        Write-Host ""
        Write-ToolMessage "Tool completed successfully!" -Type SUCCESS
        Write-Host ""

        return 0

    } catch {
        Write-Host ""
        Write-ToolMessage "Unexpected error: $($_.Exception.Message)" -Type ERROR
        Write-Host ""
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        Write-Host ""
        return 2
    }
}
#endregion

#region Entry Point
# Run the tool and exit with appropriate code
$exitCode = Start-Tool

# Return exit code for toolkit logging
exit $exitCode
#endregion
