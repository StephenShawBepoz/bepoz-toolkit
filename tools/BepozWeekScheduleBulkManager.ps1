#Requires -Version 5.1

<#
.SYNOPSIS
    Bepoz WeekSchedule Bulk Manager
.DESCRIPTION
    GUI tool for bulk insertion/update/deletion of WeekSchedule records across multiple workstations.
    Supports venue-specific configuration (KeySets, Price Names, Points Profiles, Table Maps, Shifts).
    
    Version 2.0 - Now uses centralized BepozDbCore module for database operations.
.NOTES
    Author: Bepoz Administration Team
    Version: 2.0.0
    PowerShell Version: 5.1+
    Dependencies: BepozDbCore.ps1 (loaded from temp directory by toolkit)
    
    Changelog:
    - 2.0.0: Migrated to use centralized BepozDbCore module
    - 1.1.0: Added KioskID support for DataVer >= 4729
    - 1.0.0: Initial release with embedded database code
#>

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Helper Classes

# Define ComboBoxItem class (only if not already defined)
try {
    if (-not ([System.Management.Automation.PSTypeName]'ComboBoxItem').Type) {
        Write-Host "Defining ComboBoxItem class..." -ForegroundColor Cyan
        Add-Type -TypeDefinition @"
    public class ComboBoxItem
    {
        public string Text { get; set; }
        public int Value { get; set; }
        
        public ComboBoxItem(string text, int value)
        {
            Text = text;
            Value = value;
        }
        
        public override string ToString()
        {
            return Text;
        }
    }
"@
        Write-Host "ComboBoxItem class defined successfully" -ForegroundColor Green
    }
    else {
        Write-Host "ComboBoxItem class already exists (re-using)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR defining ComboBoxItem class: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This may cause property access errors in ComboBoxes" -ForegroundColor Red
}

#endregion

#region Helper Functions for Safe ComboBox Access

function Get-ComboBoxItemText {
    <#
    .SYNOPSIS
        Safely extracts Text property from ComboBox item
    #>
    param([object]$Item)
    
    if ($null -eq $Item) { return "" }
    
    # Try direct property access
    if ($Item.PSObject.Properties['Text']) {
        return $Item.Text
    }
    
    # Fallback to ToString()
    return $Item.ToString()
}

function Get-ComboBoxItemValue {
    <#
    .SYNOPSIS
        Safely extracts Value property from ComboBox item
    #>
    param([object]$Item)
    
    if ($null -eq $Item) { return 0 }
    
    # Try direct property access
    if ($Item.PSObject.Properties['Value']) {
        return $Item.Value
    }
    
    # Fallback to trying to cast item itself
    try {
        return [int]$Item
    }
    catch {
        return 0
    }
}

#endregion

#region BepozDbCore Module Loading

function Get-BepozDbModule {
    <#
    .SYNOPSIS
        Loads BepozDbCore module (downloaded by toolkit)
    .DESCRIPTION
        Checks if BepozDbCore module is loaded, and if not, attempts to load it from temp directory.
        The toolkit downloads this module before running tools.
    .OUTPUTS
        Boolean - $true if module loaded successfully, $false otherwise
    #>

    # Check if already loaded
    if (Get-Command -Name Invoke-BepozQuery -ErrorAction SilentlyContinue) {
        Write-Host "[✓] BepozDbCore module already loaded" -ForegroundColor Green
        return $true
    }

    Write-Host "[i] Loading BepozDbCore module..." -ForegroundColor Cyan

    # Try to find module in temp directory (downloaded by toolkit)
    $tempModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

    if ($tempModule) {
        try {
            . $tempModule.FullName
            Write-Host "[✓] Loaded BepozDbCore from: $($tempModule.FullName)" -ForegroundColor Green
            
            # Verify key functions are available
            $requiredFunctions = @('Invoke-BepozQuery', 'Invoke-BepozNonQuery', 'Get-BepozDbInfo')
            $missingFunctions = $requiredFunctions | Where-Object { 
                -not (Get-Command -Name $_ -ErrorAction SilentlyContinue) 
            }
            
            if ($missingFunctions.Count -gt 0) {
                Write-Host "[✗] Module loaded but missing functions: $($missingFunctions -join ', ')" -ForegroundColor Red
                return $false
            }
            
            return $true
        } 
        catch {
            Write-Host "[✗] Failed to load BepozDbCore: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    # Module not found
    Write-Host "NOTE:BepozDbCore module not found in temp directory" -ForegroundColor Yellow
    Write-Host "NOTE:Expected location: $env:TEMP\BepozDbCore.ps1" -ForegroundColor Yellow
    Write-Host "NOTE:This tool requires database access to function" -ForegroundColor Yellow
    return $false
}

# Load the module at startup
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Bepoz WeekSchedule Bulk Manager" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$dbModuleLoaded = Get-BepozDbModule

if (-not $dbModuleLoaded) {
    Write-Host ""
    Write-Host "ERROR: Database module not available" -ForegroundColor Red
    Write-Host "This tool requires BepozDbCore.ps1 to access the Bepoz database" -ForegroundColor Red
    Write-Host ""
    Write-Host "Solutions:" -ForegroundColor Yellow
    Write-Host "  1. Run this tool through the Bepoz Toolkit (recommended)" -ForegroundColor Yellow
    Write-Host "  2. Manually download BepozDbCore.ps1 to: $env:TEMP" -ForegroundColor Yellow
    Write-Host ""
    
    # Show message box if GUI is available
    if ([System.Environment]::UserInteractive) {
        [System.Windows.Forms.MessageBox]::Show(
            "Database module (BepozDbCore.ps1) not found.`n`nThis tool must be run through the Bepoz Toolkit, or BepozDbCore.ps1 must be present in the TEMP directory.`n`nThe tool cannot continue without database access.",
            'Module Not Found',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    
    exit 2
}

Write-Host ""

#endregion

#region BepozLogger Module Loading

# Load BepozLogger for centralized logging
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1

if ($loggerModule) {
    try {
        . $loggerModule.FullName
        $logFile = Initialize-BepozLogger -ToolName "BepozWeekScheduleBulkManager"
        Write-Host "[✓] Logging initialized: $logFile" -ForegroundColor Green
        Write-Host ""

        # Log tool startup
        Write-BepozLogAction "Tool started"
    }
    catch {
        Write-Host "NOTE:Logger module found but failed to load: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "NOTE:Continuing without logging..." -ForegroundColor Yellow
    }
}
else {
    Write-Host "NOTE:BepozLogger module not found (optional)" -ForegroundColor Yellow
    Write-Host "NOTE:Tool will run without centralized logging" -ForegroundColor Yellow
}

Write-Host ""

#endregion

#region Database Initialization

# Get database connection info from BepozDbCore
try {
    Write-Host "Initializing database connection..." -ForegroundColor Cyan
    $dbInfo = Get-BepozDbInfo -ApplicationName "BepozWeekScheduleManager"
    $script:ConnectionString = $dbInfo.ConnectionString
    
    Write-Host "[✓] Database connection initialized" -ForegroundColor Green
    Write-Host "    Server: $($dbInfo.Server)" -ForegroundColor Gray
    Write-Host "    Database: $($dbInfo.Database)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: Failed to initialize database connection" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    if ([System.Environment]::UserInteractive) {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to connect to Bepoz database.`n`nError: $($_.Exception.Message)`n`nPlease verify:`n- Bepoz Backoffice is installed`n- SQL Server is accessible`n- Windows Authentication is configured",
            'Database Connection Failed',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    
    exit 3
}

#endregion

#region Data Loading Functions

function Get-Venues {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT VenueID, Name FROM dbo.Venue ORDER BY VenueID"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-Workstations {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID,
        [int]$StoreID = -1,  # -1 = all stores
        [bool]$IncludeDisabled = $false
    )
    
    $disabledFilter = if ($IncludeDisabled) { "" } else { "AND w.Disabled = 0" }
    
    if ($StoreID -eq -1) {
        # All stores in venue
        $query = @"
SELECT 
    w.WorkstationID,
    w.Name AS WorkstationName,
    w.Disabled,
    s.Name AS StoreName,
    s.StoreID
FROM dbo.Workstation w
INNER JOIN dbo.Store s ON w.StoreID = s.StoreID
WHERE s.VenueID = @VenueID
  $disabledFilter
ORDER BY s.Name, w.Name
"@
        return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters @{ '@VenueID' = $VenueID }
    }
    else {
        # Specific store
        $query = @"
SELECT 
    w.WorkstationID,
    w.Name AS WorkstationName,
    w.Disabled,
    s.Name AS StoreName,
    s.StoreID
FROM dbo.Workstation w
INNER JOIN dbo.Store s ON w.StoreID = s.StoreID
WHERE w.StoreID = @StoreID
  $disabledFilter
ORDER BY w.Name
"@
        return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters @{ '@StoreID' = $StoreID }
    }
}

function Get-Stores {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID
    )
    
    $query = @"
SELECT StoreID, Name
FROM dbo.Store
WHERE VenueID = @VenueID
ORDER BY Name
"@
    
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters @{ '@VenueID' = $VenueID }
}

function Get-KeySets {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT KeySetID, KeySetName FROM dbo.KeySet ORDER BY KeySetID"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-VenuePriceNames {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID
    )
    
    $query = @"
SELECT 
    PriceName_1, PriceName_2, PriceName_3, PriceName_4,
    PriceName_5, PriceName_6, PriceName_7, PriceName_8
FROM dbo.Venue
WHERE VenueID = @VenueID
"@
    
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters @{ '@VenueID' = $VenueID }
}

function Get-PointsProfiles {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT PointsProfileID, Name FROM dbo.PointsProfile ORDER BY PointsProfileID"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-OverrideMaps {
    <#
    .SYNOPSIS
        Retrieves Override Maps from dbo.Map where MapType = 2
    #>
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = @"
SELECT MapID, Name
FROM dbo.Map
WHERE MapType = 2
ORDER BY Name
"@
    
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-TableMaps {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    $query = "SELECT TableMapSetID, TableMapSetName FROM dbo.TableMapSet ORDER BY TableMapSetID"
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query
}

function Get-VenueShiftNames {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID
    )
    
    $query = @"
SELECT 
    ShiftName0, ShiftName1, ShiftName2, ShiftName3, ShiftName4,
    ShiftName5, ShiftName6, ShiftName7, ShiftName8, ShiftName9
FROM dbo.Venue
WHERE VenueID = @VenueID
"@
    
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters @{ '@VenueID' = $VenueID }
}

function Get-ExistingSchedules {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID,
        [array]$WorkstationIDs
    )
    
    if ($WorkstationIDs.Count -eq 0) {
        return @()
    }
    
    $wsIDList = ($WorkstationIDs | ForEach-Object { $_ }) -join ','
    
    $query = @"
SELECT 
    VenueID, WorkstationID, MinutesOffset,
    KeySetID, PriceNumber, PointsProfile, 
    OverrideMap, TableMapSetID, ChangeShift
FROM dbo.WeekSchedule
WHERE VenueID = @VenueID
  AND WorkstationID IN ($wsIDList)
"@
    
    return Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters @{ '@VenueID' = $VenueID }
}

#endregion

#region WeekSchedule Operations

function Test-ScheduleExists {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID,
        [int]$WorkstationID,
        [int]$MinutesOffset
    )
    
    $query = @"
SELECT COUNT(*) AS RecordCount
FROM dbo.WeekSchedule
WHERE VenueID = @VenueID
  AND WorkstationID = @WorkstationID
  AND MinutesOffset = @MinutesOffset
"@
    
    $params = @{
        '@VenueID' = $VenueID
        '@WorkstationID' = $WorkstationID
        '@MinutesOffset' = $MinutesOffset
    }
    
    $result = Invoke-BepozQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
    
    return ($result.Rows[0]['RecordCount'] -gt 0)
}

function New-WeekSchedule {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID,
        [int]$WorkstationID,
        [int]$MinutesOffset,
        [int]$KeySetID,
        [int]$PriceNumber,
        [int]$PointsProfile,
        [string]$OverrideMap,
        [int]$TableMapSetID,
        [int]$ChangeShift
    )
    
    $query = @"
INSERT INTO dbo.WeekSchedule (
    VenueID, WorkstationID, MinutesOffset,
    Name, KeySetID, PriceNumber, PointsProfile,
    OverrideMap, TableMapSetID, ChangeShift, DateUpdated
)
VALUES (
    @VenueID, @WorkstationID, @MinutesOffset,
    '', @KeySetID, @PriceNumber, @PointsProfile,
    @OverrideMap, @TableMapSetID, @ChangeShift, GETDATE()
)
"@
    
    $params = @{
        '@VenueID' = $VenueID
        '@WorkstationID' = $WorkstationID
        '@MinutesOffset' = $MinutesOffset
        '@KeySetID' = $KeySetID
        '@PriceNumber' = $PriceNumber
        '@PointsProfile' = $PointsProfile
        '@OverrideMap' = if ([string]::IsNullOrWhiteSpace($OverrideMap)) { '' } else { $OverrideMap }
        '@TableMapSetID' = $TableMapSetID
        '@ChangeShift' = $ChangeShift
    }
    
    return Invoke-BepozNonQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
}

function Update-WeekSchedule {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID,
        [int]$WorkstationID,
        [int]$MinutesOffset,
        [int]$KeySetID,
        [int]$PriceNumber,
        [int]$PointsProfile,
        [string]$OverrideMap,
        [int]$TableMapSetID,
        [int]$ChangeShift
    )
    
    $query = @"
UPDATE dbo.WeekSchedule
SET KeySetID = @KeySetID,
    PriceNumber = @PriceNumber,
    PointsProfile = @PointsProfile,
    OverrideMap = @OverrideMap,
    TableMapSetID = @TableMapSetID,
    ChangeShift = @ChangeShift,
    DateUpdated = GETDATE()
WHERE VenueID = @VenueID
  AND WorkstationID = @WorkstationID
  AND MinutesOffset = @MinutesOffset
"@
    
    $params = @{
        '@VenueID' = $VenueID
        '@WorkstationID' = $WorkstationID
        '@MinutesOffset' = $MinutesOffset
        '@KeySetID' = $KeySetID
        '@PriceNumber' = $PriceNumber
        '@PointsProfile' = $PointsProfile
        '@OverrideMap' = if ([string]::IsNullOrWhiteSpace($OverrideMap)) { '' } else { $OverrideMap }
        '@TableMapSetID' = $TableMapSetID
        '@ChangeShift' = $ChangeShift
    }
    
    return Invoke-BepozNonQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
}

function Remove-WeekSchedule {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [int]$VenueID,
        [int]$WorkstationID
    )
    
    $query = @"
DELETE FROM dbo.WeekSchedule
WHERE VenueID = @VenueID
  AND WorkstationID = @WorkstationID
"@
    
    $params = @{
        '@VenueID' = $VenueID
        '@WorkstationID' = $WorkstationID
    }
    
    return Invoke-BepozNonQuery -ConnectionString $ConnectionString -Query $query -Parameters $params
}

#endregion

#region Helper Functions

function ConvertTo-TimeString {
    [CmdletBinding()]
    param([int]$MinutesOffset)
    
    if ($MinutesOffset -lt 0 -or $MinutesOffset -gt 10079) {
        return "Invalid"
    }
    
    $dayIndex = [Math]::Floor($MinutesOffset / 1440)
    $minutesInDay = $MinutesOffset % 1440
    $hours = [Math]::Floor($minutesInDay / 60)
    $minutes = $minutesInDay % 60
    
    $days = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
    $dayName = $days[$dayIndex]
    
    return "$dayName {0:D2}:{1:D2}" -f $hours, $minutes
}

function ConvertFrom-DayAndTime {
    [CmdletBinding()]
    param(
        [string]$DayName,
        [string]$TimeString
    )
    
    # Map day names to day offset multipliers
    $dayOffsets = @{
        'Monday' = 0
        'Tuesday' = 1440
        'Wednesday' = 2880
        'Thursday' = 4320
        'Friday' = 5760
        'Saturday' = 7200
        'Sunday' = 8640
    }
    
    if (-not $dayOffsets.ContainsKey($DayName)) {
        return -1
    }
    
    if ($TimeString -notmatch '^(\d{1,2}):(\d{2})$') {
        return -1
    }
    
    $hours = [int]$Matches[1]
    $minutes = [int]$Matches[2]
    
    if ($hours -gt 23 -or $minutes -gt 59) {
        return -1
    }
    
    $minutesInDay = ($hours * 60) + $minutes
    $totalOffset = $dayOffsets[$DayName] + $minutesInDay
    
    return $totalOffset
}

#endregion

#region Main GUI

function Show-WeekScheduleManager {
    [CmdletBinding()]
    param([string]$ConnectionString)
    
    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Bepoz WeekSchedule Bulk Manager'
    $form.Size = New-Object System.Drawing.Size(900, 900)
    $form.StartPosition = 'CenterScreen'
    $form.MaximizeBox = $true
    $form.MinimumSize = New-Object System.Drawing.Size(900, 600)
    $form.FormBorderStyle = 'Sizable'
    $form.AutoScroll = $true
    
    $yPos = 20
    
    # Header
    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblHeader.Size = New-Object System.Drawing.Size(850, 30)
    $lblHeader.Text = 'WeekSchedule Bulk Manager'
    $lblHeader.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lblHeader)
    
    $yPos += 40
    
    # Instructions
    $lblInstructions = New-Object System.Windows.Forms.Label
    $lblInstructions.Location = New-Object System.Drawing.Point(20, $yPos)
    $lblInstructions.Size = New-Object System.Drawing.Size(850, 30)
    $lblInstructions.Text = "Bulk insert/update/delete WeekSchedule records for multiple workstations (max 10 at once)"
    $lblInstructions.ForeColor = [System.Drawing.Color]::Gray
    $form.Controls.Add($lblInstructions)
    
    $yPos += 40
    
    # === STEP 1: Venue & Store Selection ===
    $grpVenue = New-Object System.Windows.Forms.GroupBox
    $grpVenue.Location = New-Object System.Drawing.Point(20, $yPos)
    $grpVenue.Size = New-Object System.Drawing.Size(850, 70)
    $grpVenue.Text = 'Step 1: Select Venue'
    $form.Controls.Add($grpVenue)
    
    # Venue
    $lblVenue = New-Object System.Windows.Forms.Label
    $lblVenue.Location = New-Object System.Drawing.Point(20, 30)
    $lblVenue.Size = New-Object System.Drawing.Size(80, 20)
    $lblVenue.Text = 'Venue:'
    $grpVenue.Controls.Add($lblVenue)
    
    $cmbVenue = New-Object System.Windows.Forms.ComboBox
    $cmbVenue.Location = New-Object System.Drawing.Point(110, 30)
    $cmbVenue.Size = New-Object System.Drawing.Size(350, 25)
    $cmbVenue.DropDownStyle = 'DropDownList'
    $grpVenue.Controls.Add($cmbVenue)
    
    $btnAllVenues = New-Object System.Windows.Forms.Button
    $btnAllVenues.Location = New-Object System.Drawing.Point(470, 30)
    $btnAllVenues.Size = New-Object System.Drawing.Size(90, 25)
    $btnAllVenues.Text = 'All Venues'
    $grpVenue.Controls.Add($btnAllVenues)
    
    # Store dropdown (will be moved to Workstation section)
    $cmbStore = New-Object System.Windows.Forms.ComboBox
    $cmbStore.DropDownStyle = 'DropDownList'
    
    $yPos += 80
    
    # === STEP 2: Workstation Selection ===
    $grpWorkstations = New-Object System.Windows.Forms.GroupBox
    $grpWorkstations.Location = New-Object System.Drawing.Point(20, $yPos)
    $grpWorkstations.Size = New-Object System.Drawing.Size(850, 310)
    $grpWorkstations.Text = 'Step 2: Filter by Store & Select Workstations'
    $form.Controls.Add($grpWorkstations)
    
    $wsY = 30
    
    # Store filter label
    $lblStoreFilter = New-Object System.Windows.Forms.Label
    $lblStoreFilter.Location = New-Object System.Drawing.Point(20, $wsY)
    $lblStoreFilter.Size = New-Object System.Drawing.Size(100, 20)
    $lblStoreFilter.Text = 'Filter by Store:'
    $grpWorkstations.Controls.Add($lblStoreFilter)
    
    # Store dropdown (using the one already created in Venue section)
    $cmbStore.Location = New-Object System.Drawing.Point(130, $wsY)
    $cmbStore.Size = New-Object System.Drawing.Size(400, 25)
    $grpWorkstations.Controls.Add($cmbStore)
    
    # Include Disabled checkbox
    $chkIncludeDisabled = New-Object System.Windows.Forms.CheckBox
    $chkIncludeDisabled.Location = New-Object System.Drawing.Point(550, $wsY)
    $chkIncludeDisabled.Size = New-Object System.Drawing.Size(250, 20)
    $chkIncludeDisabled.Text = 'Include Disabled Workstations'
    $chkIncludeDisabled.Checked = $false
    $grpWorkstations.Controls.Add($chkIncludeDisabled)
    
    $wsY += 40
    
    # Workstations label
    $lblWSTills = New-Object System.Windows.Forms.Label
    $lblWSTills.Location = New-Object System.Drawing.Point(20, $wsY)
    $lblWSTills.Size = New-Object System.Drawing.Size(400, 20)
    $lblWSTills.Text = 'Select Workstations (Tills):'
    $lblWSTills.Font = New-Object System.Drawing.Font($lblWSTills.Font.FontFamily, 9, [System.Drawing.FontStyle]::Bold)
    $grpWorkstations.Controls.Add($lblWSTills)
    
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Location = New-Object System.Drawing.Point(650, $wsY)
    $btnSelectAll.Size = New-Object System.Drawing.Size(80, 25)
    $btnSelectAll.Text = 'Select All'
    $grpWorkstations.Controls.Add($btnSelectAll)
    
    $btnClearAll = New-Object System.Windows.Forms.Button
    $btnClearAll.Location = New-Object System.Drawing.Point(740, $wsY)
    $btnClearAll.Size = New-Object System.Drawing.Size(80, 25)
    $btnClearAll.Text = 'Clear All'
    $grpWorkstations.Controls.Add($btnClearAll)
    
    $wsY += 35
    
    $clbWorkstations = New-Object System.Windows.Forms.CheckedListBox
    $clbWorkstations.Location = New-Object System.Drawing.Point(20, $wsY)
    $clbWorkstations.Size = New-Object System.Drawing.Size(810, 200)
    $clbWorkstations.CheckOnClick = $true
    $grpWorkstations.Controls.Add($clbWorkstations)
    
    $yPos += 320
    
    # === STEP 3: Schedule Configuration ===
    $grpConfig = New-Object System.Windows.Forms.GroupBox
    $grpConfig.Location = New-Object System.Drawing.Point(20, $yPos)
    $grpConfig.Size = New-Object System.Drawing.Size(850, 400)
    $grpConfig.Text = 'Step 3: Configure Schedule'
    $form.Controls.Add($grpConfig)
    
    $cfgY = 30
    
    # Day selection - multi-select
    $lblDay = New-Object System.Windows.Forms.Label
    $lblDay.Location = New-Object System.Drawing.Point(20, $cfgY)
    $lblDay.Size = New-Object System.Drawing.Size(120, 20)
    $lblDay.Text = 'Day(s) of Week:'
    $lblDay.Font = New-Object System.Drawing.Font($lblDay.Font.FontFamily, 9, [System.Drawing.FontStyle]::Bold)
    $grpConfig.Controls.Add($lblDay)
    
    $clbDays = New-Object System.Windows.Forms.CheckedListBox
    $clbDays.Location = New-Object System.Drawing.Point(20, ($cfgY + 25))
    $clbDays.Size = New-Object System.Drawing.Size(200, 120)
    $clbDays.CheckOnClick = $true
    $clbDays.Items.AddRange(@('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'))
    $grpConfig.Controls.Add($clbDays)
    
    # Quick select buttons (right of checkbox list)
    $btnWeekdays = New-Object System.Windows.Forms.Button
    $btnWeekdays.Location = New-Object System.Drawing.Point(230, ($cfgY + 25))
    $btnWeekdays.Size = New-Object System.Drawing.Size(80, 25)
    $btnWeekdays.Text = 'Mon-Fri'
    $grpConfig.Controls.Add($btnWeekdays)
    
    $btnWeekend = New-Object System.Windows.Forms.Button
    $btnWeekend.Location = New-Object System.Drawing.Point(230, ($cfgY + 55))
    $btnWeekend.Size = New-Object System.Drawing.Size(80, 25)
    $btnWeekend.Text = 'Sat-Sun'
    $grpConfig.Controls.Add($btnWeekend)
    
    $btnAllDays = New-Object System.Windows.Forms.Button
    $btnAllDays.Location = New-Object System.Drawing.Point(230, ($cfgY + 85))
    $btnAllDays.Size = New-Object System.Drawing.Size(80, 25)
    $btnAllDays.Text = 'All Days'
    $grpConfig.Controls.Add($btnAllDays)
    
    $btnClearDays = New-Object System.Windows.Forms.Button
    $btnClearDays.Location = New-Object System.Drawing.Point(230, ($cfgY + 115))
    $btnClearDays.Size = New-Object System.Drawing.Size(80, 25)
    $btnClearDays.Text = 'Clear'
    $grpConfig.Controls.Add($btnClearDays)
    
    # Live offset preview (right side)
    $lblOffsetPreview = New-Object System.Windows.Forms.Label
    $lblOffsetPreview.Location = New-Object System.Drawing.Point(330, ($cfgY + 25))
    $lblOffsetPreview.Size = New-Object System.Drawing.Size(500, 120)
    $lblOffsetPreview.Text = 'Select days and enter time to see MinutesOffset values'
    $lblOffsetPreview.ForeColor = [System.Drawing.Color]::Gray
    $lblOffsetPreview.Font = New-Object System.Drawing.Font('Consolas', 9)
    $lblOffsetPreview.BorderStyle = 'FixedSingle'
    $grpConfig.Controls.Add($lblOffsetPreview)
    
    $cfgY += 155
    
    # Time (HH:MM format)
    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Location = New-Object System.Drawing.Point(20, $cfgY)
    $lblTime.Size = New-Object System.Drawing.Size(120, 20)
    $lblTime.Text = 'Time (HH:MM):'
    $grpConfig.Controls.Add($lblTime)
    
    $txtTime = New-Object System.Windows.Forms.TextBox
    $txtTime.Location = New-Object System.Drawing.Point(150, $cfgY)
    $txtTime.Size = New-Object System.Drawing.Size(100, 25)
    $txtTime.Text = '05:00'
    $grpConfig.Controls.Add($txtTime)
    
    # Offset display label (for single-line display)
    $lblOffset = New-Object System.Windows.Forms.Label
    $lblOffset.Location = New-Object System.Drawing.Point(270, $cfgY)
    $lblOffset.Size = New-Object System.Drawing.Size(150, 20)
    $lblOffset.Text = 'Offset: 300'
    $lblOffset.ForeColor = [System.Drawing.Color]::Blue
    $lblOffset.Font = New-Object System.Drawing.Font($lblOffset.Font.FontFamily, 9, [System.Drawing.FontStyle]::Bold)
    $grpConfig.Controls.Add($lblOffset)
    
    $cfgY += 35
    
    $lblTimeHelp = New-Object System.Windows.Forms.Label
    $lblTimeHelp.Location = New-Object System.Drawing.Point(20, $cfgY)
    $lblTimeHelp.Size = New-Object System.Drawing.Size(800, 20)
    $lblTimeHelp.Text = 'Offset starts from Monday 00:00 (0 = Monday midnight, 1440 = Tuesday midnight, etc.)'
    $lblTimeHelp.ForeColor = [System.Drawing.Color]::Gray
    $lblTimeHelp.Font = New-Object System.Drawing.Font($lblTimeHelp.Font.FontFamily, 8, [System.Drawing.FontStyle]::Italic)
    $grpConfig.Controls.Add($lblTimeHelp)
    
    $cfgY += 30
    
    # KeySetID
    $lblKeySet = New-Object System.Windows.Forms.Label
    $lblKeySet.Location = New-Object System.Drawing.Point(20, $cfgY)
    $lblKeySet.Size = New-Object System.Drawing.Size(120, 20)
    $lblKeySet.Text = 'KeySet:'
    $grpConfig.Controls.Add($lblKeySet)
    
    $cmbKeySet = New-Object System.Windows.Forms.ComboBox
    $cmbKeySet.Location = New-Object System.Drawing.Point(150, $cfgY)
    $cmbKeySet.Size = New-Object System.Drawing.Size(300, 25)
    $cmbKeySet.DropDownStyle = 'DropDownList'
    $grpConfig.Controls.Add($cmbKeySet)
    
    # PriceNumber
    $lblPrice = New-Object System.Windows.Forms.Label
    $lblPrice.Location = New-Object System.Drawing.Point(460, $cfgY)
    $lblPrice.Size = New-Object System.Drawing.Size(80, 20)
    $lblPrice.Text = 'Price:'
    $grpConfig.Controls.Add($lblPrice)
    
    $cmbPrice = New-Object System.Windows.Forms.ComboBox
    $cmbPrice.Location = New-Object System.Drawing.Point(550, $cfgY)
    $cmbPrice.Size = New-Object System.Drawing.Size(270, 25)
    $cmbPrice.DropDownStyle = 'DropDownList'
    $grpConfig.Controls.Add($cmbPrice)
    
    $cfgY += 35
    
    # PointsProfile
    $lblPoints = New-Object System.Windows.Forms.Label
    $lblPoints.Location = New-Object System.Drawing.Point(20, $cfgY)
    $lblPoints.Size = New-Object System.Drawing.Size(120, 20)
    $lblPoints.Text = 'Points Profile:'
    $grpConfig.Controls.Add($lblPoints)
    
    $cmbPoints = New-Object System.Windows.Forms.ComboBox
    $cmbPoints.Location = New-Object System.Drawing.Point(150, $cfgY)
    $cmbPoints.Size = New-Object System.Drawing.Size(300, 25)
    $cmbPoints.DropDownStyle = 'DropDownList'
    $grpConfig.Controls.Add($cmbPoints)
    
    # TableMapSetID
    $lblTableMap = New-Object System.Windows.Forms.Label
    $lblTableMap.Location = New-Object System.Drawing.Point(460, $cfgY)
    $lblTableMap.Size = New-Object System.Drawing.Size(80, 20)
    $lblTableMap.Text = 'Table Map:'
    $grpConfig.Controls.Add($lblTableMap)
    
    $cmbTableMap = New-Object System.Windows.Forms.ComboBox
    $cmbTableMap.Location = New-Object System.Drawing.Point(550, $cfgY)
    $cmbTableMap.Size = New-Object System.Drawing.Size(270, 25)
    $cmbTableMap.DropDownStyle = 'DropDownList'
    $grpConfig.Controls.Add($cmbTableMap)
    
    $cfgY += 35
    
    # ChangeShift
    $lblShift = New-Object System.Windows.Forms.Label
    $lblShift.Location = New-Object System.Drawing.Point(20, $cfgY)
    $lblShift.Size = New-Object System.Drawing.Size(120, 20)
    $lblShift.Text = 'Change Shift:'
    $grpConfig.Controls.Add($lblShift)
    
    $cmbShift = New-Object System.Windows.Forms.ComboBox
    $cmbShift.Location = New-Object System.Drawing.Point(150, $cfgY)
    $cmbShift.Size = New-Object System.Drawing.Size(300, 25)
    $cmbShift.DropDownStyle = 'DropDownList'
    $grpConfig.Controls.Add($cmbShift)
    
    # OverrideMap
    $lblOverride = New-Object System.Windows.Forms.Label
    $lblOverride.Location = New-Object System.Drawing.Point(460, $cfgY)
    $lblOverride.Size = New-Object System.Drawing.Size(80, 20)
    $lblOverride.Text = 'Override Map:'
    $grpConfig.Controls.Add($lblOverride)
    
    $cmbOverride = New-Object System.Windows.Forms.ComboBox
    $cmbOverride.Location = New-Object System.Drawing.Point(550, $cfgY)
    $cmbOverride.Size = New-Object System.Drawing.Size(270, 25)
    $cmbOverride.DropDownStyle = 'DropDownList'
    $grpConfig.Controls.Add($cmbOverride)
    
    $cfgY += 40
    
    $lblConfigHelp = New-Object System.Windows.Forms.Label
    $lblConfigHelp.Location = New-Object System.Drawing.Point(20, $cfgY)
    $lblConfigHelp.Size = New-Object System.Drawing.Size(800, 30)
    $lblConfigHelp.Text = "All settings default to '0 - No Change'. Select a value to override that setting for the selected workstations."
    $lblConfigHelp.ForeColor = [System.Drawing.Color]::Gray
    $lblConfigHelp.Font = New-Object System.Drawing.Font($lblConfigHelp.Font.FontFamily, 8, [System.Drawing.FontStyle]::Italic)
    $grpConfig.Controls.Add($lblConfigHelp)
    
    $yPos += 410
    
    # === Action Buttons ===
    $btnViewWeek = New-Object System.Windows.Forms.Button
    $btnViewWeek.Location = New-Object System.Drawing.Point(230, $yPos)
    $btnViewWeek.Size = New-Object System.Drawing.Size(110, 35)
    $btnViewWeek.Text = 'View Week'
    $btnViewWeek.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
    $btnViewWeek.ForeColor = [System.Drawing.Color]::White
    $btnViewWeek.FlatStyle = 'Flat'
    $btnViewWeek.Enabled = $false
    $form.Controls.Add($btnViewWeek)
    
    $btnPreview = New-Object System.Windows.Forms.Button
    $btnPreview.Location = New-Object System.Drawing.Point(350, $yPos)
    $btnPreview.Size = New-Object System.Drawing.Size(110, 35)
    $btnPreview.Text = 'Preview Changes'
    $btnPreview.Enabled = $false
    $form.Controls.Add($btnPreview)
    
    $btnApply = New-Object System.Windows.Forms.Button
    $btnApply.Location = New-Object System.Drawing.Point(470, $yPos)
    $btnApply.Size = New-Object System.Drawing.Size(110, 35)
    $btnApply.Text = 'Apply Changes'
    $btnApply.Font = New-Object System.Drawing.Font($btnApply.Font.FontFamily, 9, [System.Drawing.FontStyle]::Bold)
    $btnApply.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnApply.ForeColor = [System.Drawing.Color]::White
    $btnApply.FlatStyle = 'Flat'
    $btnApply.Enabled = $false
    $form.Controls.Add($btnApply)
    
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Location = New-Object System.Drawing.Point(590, $yPos)
    $btnDelete.Size = New-Object System.Drawing.Size(110, 35)
    $btnDelete.Text = 'Delete Schedules'
    $btnDelete.BackColor = [System.Drawing.Color]::FromArgb(200, 50, 50)
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = 'Flat'
    $btnDelete.Enabled = $false
    $form.Controls.Add($btnDelete)
    
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Location = New-Object System.Drawing.Point(780, $yPos)
    $btnClose.Size = New-Object System.Drawing.Size(90, 35)
    $btnClose.Text = 'Close'
    $form.Controls.Add($btnClose)
    
    # Status Bar
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = 'Ready'
    $statusBar.Items.Add($statusLabel) | Out-Null
    $form.Controls.Add($statusBar)
    
    #region Event Handlers
    
    # Load venues
    function Load-Venues {
        try {
            $statusLabel.Text = 'Loading venues...'
            $form.Refresh()
            
            Write-Host "Loading venues..." -ForegroundColor Yellow
            
            $venues = Get-Venues -ConnectionString $ConnectionString
            
            $cmbVenue.Items.Clear()
            
            foreach ($venue in $venues.Rows) {
                $venueName = $venue['Name']
                $venueID = [int]$venue['VenueID']
                
                $item = New-Object ComboBoxItem("$venueID - $venueName", $venueID)
                Write-Host "  Created ComboBoxItem: Type=$($item.GetType().FullName), Text=$($item.Text), Value=$($item.Value)" -ForegroundColor Gray
                $cmbVenue.Items.Add($item) | Out-Null
            }
            
            if ($cmbVenue.Items.Count -gt 0) {
                $cmbVenue.SelectedIndex = 0
            }
            
            $statusLabel.Text = "Loaded $($venues.Rows.Count) venue(s)"
            Write-Host "Loaded $($venues.Rows.Count) venue(s)" -ForegroundColor Green
        }
        catch {
            $statusLabel.Text = 'Error loading venues'
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to load venues: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    }
    
    # Load stores for selected venue
    function Load-Stores {
        param([int]$VenueID)
        
        try {
            $statusLabel.Text = 'Loading stores...'
            $form.Refresh()
            
            Write-Host "Loading stores for VenueID: $VenueID..." -ForegroundColor Yellow
            
            $stores = Get-Stores -ConnectionString $ConnectionString -VenueID $VenueID
            
            $cmbStore.Items.Clear()
            
            # Add "All Stores" option first
            $allStoresItem = New-Object ComboBoxItem("All Stores", -1)
            $cmbStore.Items.Add($allStoresItem) | Out-Null
            
            foreach ($store in $stores.Rows) {
                $storeName = $store['Name']
                $storeID = [int]$store['StoreID']
                
                $item = New-Object ComboBoxItem("$storeID - $storeName", $storeID)
                $cmbStore.Items.Add($item) | Out-Null
            }
            
            if ($cmbStore.Items.Count -gt 0) {
                $cmbStore.SelectedIndex = 0
            }
            
            Write-Host "Loaded $($stores.Rows.Count) store(s)" -ForegroundColor Green
        }
        catch {
            Write-Host "Error loading stores: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Load workstations based on venue and/or store
    function Load-Workstations {
        param(
            [int]$VenueID,
            [int]$StoreID = -1
        )
        
        try {
            $statusLabel.Text = 'Loading workstations...'
            $form.Refresh()
            
            $includeDisabled = $chkIncludeDisabled.Checked
            
            Write-Host "Loading workstations (VenueID: $VenueID, StoreID: $StoreID, IncludeDisabled: $includeDisabled)..." -ForegroundColor Yellow
            
            $workstations = Get-Workstations -ConnectionString $ConnectionString -VenueID $VenueID -StoreID $StoreID -IncludeDisabled $includeDisabled
            
            $clbWorkstations.Items.Clear()
            
            foreach ($ws in $workstations.Rows) {
                $wsID = [int]$ws['WorkstationID']
                $wsName = $ws['WorkstationName']
                $storeName = $ws['StoreName']
                $wsDisabled = $ws['Disabled']
                
                # Build display text with disabled indicator
                $displayText = "$wsID - $wsName ($storeName)"
                if ($wsDisabled) {
                    $displayText += " [DISABLED]"
                }
                
                $item = [PSCustomObject]@{
                    Text = $displayText
                    WorkstationID = $wsID
                    WorkstationName = $wsName
                    StoreName = $storeName
                    Disabled = $wsDisabled
                }
                
                $clbWorkstations.Items.Add($item) | Out-Null
            }
            
            $clbWorkstations.DisplayMember = 'Text'
            
            Write-Host "  Loaded $($workstations.Rows.Count) workstation(s)" -ForegroundColor Green
        }
        catch {
            Write-Host "Error loading workstations: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Venue changed - load stores and workstations
    $cmbVenue.Add_SelectedIndexChanged({
        $venueID = Get-ComboBoxItemValue $cmbVenue.SelectedItem
        if ($cmbVenue.SelectedItem -and $venueID -gt 0) {

            # Log venue selection
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                $venueName = Get-ComboBoxItemText $cmbVenue.SelectedItem
                Write-BepozLogAction "User selected venue: $venueName (ID: $venueID)"
            }

            try {
                $statusLabel.Text = 'Loading venue configuration...'
                $form.Refresh()

                Write-Host "`nLoading configuration for VenueID: $venueID" -ForegroundColor Yellow
                
                # Load stores
                Load-Stores -VenueID $venueID
                
                # Load workstations (will be filtered by store selection)
                Load-Workstations -VenueID $venueID -StoreID (Get-ComboBoxItemValue $cmbStore.SelectedItem)
                
                # Load KeySets
                $keySets = Get-KeySets -ConnectionString $ConnectionString
                $cmbKeySet.Items.Clear()
                
                # Add "No Change" option first
                $noChangeItem = New-Object ComboBoxItem("0 - No Change", 0)
                $cmbKeySet.Items.Add($noChangeItem) | Out-Null
                
                foreach ($ks in $keySets.Rows) {
                    $ksID = [int]$ks['KeySetID']
                    $ksName = $ks['KeySetName']
                    
                    $item = New-Object ComboBoxItem("$ksID - $ksName", $ksID)
                    $cmbKeySet.Items.Add($item) | Out-Null
                }
                
                $cmbKeySet.SelectedIndex = 0
                
                # Load Price Names
                $priceNames = Get-VenuePriceNames -ConnectionString $ConnectionString -VenueID $venueID
                $cmbPrice.Items.Clear()
                
                # Add "No Change" option first
                $noChangeItem = New-Object ComboBoxItem("0 - No Change", 0)
                $cmbPrice.Items.Add($noChangeItem) | Out-Null
                
                for ($i = 1; $i -le 8; $i++) {
                    $priceName = $priceNames.Rows[0]["PriceName_$i"]
                    if (-not [string]::IsNullOrWhiteSpace($priceName)) {
                        $item = New-Object ComboBoxItem("$i - $priceName", $i)
                        $cmbPrice.Items.Add($item) | Out-Null
                    }
                }
                
                $cmbPrice.SelectedIndex = 0
                
                # Load Points Profiles
                $pointsProfiles = Get-PointsProfiles -ConnectionString $ConnectionString
                $cmbPoints.Items.Clear()
                
                # Add "No Change" option first
                $noChangeItem = New-Object ComboBoxItem("0 - No Change", 0)
                $cmbPoints.Items.Add($noChangeItem) | Out-Null
                
                foreach ($pp in $pointsProfiles.Rows) {
                    $ppID = [int]$pp['PointsProfileID']
                    $ppName = $pp['Name']
                    
                    $item = New-Object ComboBoxItem("$ppID - $ppName", $ppID)
                    $cmbPoints.Items.Add($item) | Out-Null
                }
                
                $cmbPoints.SelectedIndex = 0
                
                # Load Table Maps
                $tableMaps = Get-TableMaps -ConnectionString $ConnectionString
                $cmbTableMap.Items.Clear()
                
                # Add "No Change" option first
                $noChangeItem = New-Object ComboBoxItem("0 - No Change", 0)
                $cmbTableMap.Items.Add($noChangeItem) | Out-Null
                
                foreach ($tm in $tableMaps.Rows) {
                    $tmID = [int]$tm['TableMapSetID']
                    $tmName = $tm['TableMapSetName']
                    
                    $item = New-Object ComboBoxItem("$tmID - $tmName", $tmID)
                    $cmbTableMap.Items.Add($item) | Out-Null
                }
                
                $cmbTableMap.SelectedIndex = 0
                
                # Load Shift Names
                $shiftNames = Get-VenueShiftNames -ConnectionString $ConnectionString -VenueID $venueID
                $cmbShift.Items.Clear()
                
                # Add "No Change" option first
                $noChangeItem = New-Object ComboBoxItem("0 - No Change", 0)
                $cmbShift.Items.Add($noChangeItem) | Out-Null
                
                for ($i = 0; $i -le 9; $i++) {
                    $shiftName = $shiftNames.Rows[0]["ShiftName$i"]
                    if (-not [string]::IsNullOrWhiteSpace($shiftName)) {
                        $item = New-Object ComboBoxItem("$i - $shiftName", $i)
                        $cmbShift.Items.Add($item) | Out-Null
                    }
                }
                
                $cmbShift.SelectedIndex = 0
                
                # Load Override Maps
                $overrideMaps = Get-OverrideMaps -ConnectionString $ConnectionString
                $cmbOverride.Items.Clear()
                
                # Add "No Change" option first
                $noChangeItem = New-Object ComboBoxItem("0 - No Change", 0)
                $cmbOverride.Items.Add($noChangeItem) | Out-Null
                
                foreach ($om in $overrideMaps.Rows) {
                    $omID = [int]$om['MapID']
                    $omName = $om['Name']
                    
                    $item = New-Object ComboBoxItem("$omID - $omName", $omID)
                    $cmbOverride.Items.Add($item) | Out-Null
                }
                
                $cmbOverride.SelectedIndex = 0
                
                $btnViewWeek.Enabled = $true
                $btnPreview.Enabled = $true
                $btnApply.Enabled = $true
                $btnDelete.Enabled = $true
                
                $statusLabel.Text = 'Venue configuration loaded successfully'
                Write-Host "Venue configuration loaded successfully" -ForegroundColor Green
            }
            catch {
                $statusLabel.Text = 'Error loading venue configuration'
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to load venue configuration: $($_.Exception.Message)",
                    'Error',
                    'OK',
                    'Error'
                )
            }
        }
    })
    
    # Store changed - reload workstations filtered by store
    $cmbStore.Add_SelectedIndexChanged({
        if ($cmbStore.SelectedItem -and $cmbVenue.SelectedItem) {
            $venueID = Get-ComboBoxItemValue $cmbVenue.SelectedItem
            $storeID = Get-ComboBoxItemValue $cmbStore.SelectedItem
            
            Load-Workstations -VenueID $venueID -StoreID $storeID
        }
    })
    
    # Include Disabled checkbox - reload workstations when toggled
    $chkIncludeDisabled.Add_CheckedChanged({
        if ($cmbVenue.SelectedItem -and $cmbStore.SelectedItem) {
            $venueID = Get-ComboBoxItemValue $cmbVenue.SelectedItem
            $storeID = Get-ComboBoxItemValue $cmbStore.SelectedItem
            
            Load-Workstations -VenueID $venueID -StoreID $storeID
        }
    })
    
    # Select All Venues button - informational message
    $btnAllVenues.Add_Click({
        [System.Windows.Forms.MessageBox]::Show(
            "Multi-venue bulk updates: Please select workstations from one venue at a time.`n`n" +
            "To update multiple venues, run this tool separately for each venue.",
            'Information',
            'OK',
            'Information'
        )
    })
    
    # Select All Workstations
    $btnSelectAll.Add_Click({
        for ($i = 0; $i -lt $clbWorkstations.Items.Count; $i++) {
            $clbWorkstations.SetItemChecked($i, $true)
        }
    })
    
    # Clear All
    $btnClearAll.Add_Click({
        for ($i = 0; $i -lt $clbWorkstations.Items.Count; $i++) {
            $clbWorkstations.SetItemChecked($i, $false)
        }
    })
    
    # Day selection quick buttons
    $btnWeekdays.Add_Click({
        try {
            if (-not $clbDays) { return }
            # Clear all first
            for ($i = 0; $i -lt $clbDays.Items.Count; $i++) {
                $clbDays.SetItemChecked($i, $false)
            }
            # Select Mon-Fri (indices 0-4)
            for ($i = 0; $i -lt 5; $i++) {
                $clbDays.SetItemChecked($i, $true)
            }
        }
        catch {
            Write-Host "ERROR in btnWeekdays: $($_.Exception.Message)" -ForegroundColor Red
        }
    })
    
    $btnWeekend.Add_Click({
        try {
            if (-not $clbDays) { return }
            # Clear all first
            for ($i = 0; $i -lt $clbDays.Items.Count; $i++) {
                $clbDays.SetItemChecked($i, $false)
            }
            # Select Sat-Sun (indices 5-6)
            $clbDays.SetItemChecked(5, $true)
            $clbDays.SetItemChecked(6, $true)
        }
        catch {
            Write-Host "ERROR in btnWeekend: $($_.Exception.Message)" -ForegroundColor Red
        }
    })
    
    $btnAllDays.Add_Click({
        try {
            if (-not $clbDays) { return }
            for ($i = 0; $i -lt $clbDays.Items.Count; $i++) {
                $clbDays.SetItemChecked($i, $true)
            }
        }
        catch {
            Write-Host "ERROR in btnAllDays: $($_.Exception.Message)" -ForegroundColor Red
        }
    })
    
    $btnClearDays.Add_Click({
        try {
            if (-not $clbDays) { return }
            for ($i = 0; $i -lt $clbDays.Items.Count; $i++) {
                $clbDays.SetItemChecked($i, $false)
            }
        }
        catch {
            Write-Host "ERROR in btnClearDays: $($_.Exception.Message)" -ForegroundColor Red
        }
    })
    
    # Update offset preview when days or time changes
    function Update-OffsetPreview {
        try {
            # Null safety checks
            if (-not $clbDays -or -not $txtTime -or -not $lblOffsetPreview) {
                return
            }
            
            # Check if controls are properly initialized
            if (-not $clbDays.Items -or $clbDays.Items.Count -eq 0) {
                return
            }
            
            $selectedDays = @()
            if ($clbDays.CheckedItems -and $clbDays.CheckedItems.Count -gt 0) {
                for ($i = 0; $i -lt $clbDays.CheckedItems.Count; $i++) {
                    $selectedDays += $clbDays.CheckedItems[$i]
                }
            }
            
            if ($selectedDays.Count -eq 0) {
                $lblOffsetPreview.Text = 'Select at least one day'
                $lblOffsetPreview.ForeColor = [System.Drawing.Color]::Gray
                return
            }
            
            $timeStr = $txtTime.Text
            if (-not $timeStr) {
                $lblOffsetPreview.Text = 'Enter time'
                $lblOffsetPreview.ForeColor = [System.Drawing.Color]::Gray
                return
            }
            
            $timeStr = $timeStr.Trim()
            if ($timeStr -notmatch '^\d{1,2}:\d{2}$') {
                $lblOffsetPreview.Text = 'Enter valid time (HH:MM)'
                $lblOffsetPreview.ForeColor = [System.Drawing.Color]::Red
                return
            }
            
            $timeParts = $timeStr.Split(':')
            $hours = [int]$timeParts[0]
            $minutes = [int]$timeParts[1]
            
            if ($hours -lt 0 -or $hours -gt 23 -or $minutes -lt 0 -or $minutes -gt 59) {
                $lblOffsetPreview.Text = 'Invalid time (hours: 0-23, minutes: 0-59)'
                $lblOffsetPreview.ForeColor = [System.Drawing.Color]::Red
                return
            }
            
            $dayOffsets = @{
                'Monday' = 0
                'Tuesday' = 1440
                'Wednesday' = 2880
                'Thursday' = 4320
                'Friday' = 5760
                'Saturday' = 7200
                'Sunday' = 8640
            }
            
            $timeMinutes = ($hours * 60) + $minutes
            
            $previewText = "MinutesOffset values:`n"
            foreach ($day in $selectedDays | Sort-Object { $dayOffsets[$_] }) {
                $offset = $dayOffsets[$day] + $timeMinutes
                $previewText += "$day $timeStr = $offset`n"
            }
            
            $lblOffsetPreview.Text = $previewText
            $lblOffsetPreview.ForeColor = [System.Drawing.Color]::Blue
        }
        catch {
            Write-Host "ERROR in Update-OffsetPreview: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            # Don't throw - just log and continue
        }
    }
    
    $clbDays.Add_ItemCheck({ 
        try {
            Update-OffsetPreview
        }
        catch {
            # Silently ignore during initialization
        }
    })
    $txtTime.Add_TextChanged({ 
        try {
            Update-OffsetPreview
        }
        catch {
            # Silently ignore during initialization
        }
    })

    
    # Offset display is now handled by Update-OffsetPreview function
    
    # Limit selections to 10
    $clbWorkstations.Add_ItemCheck({
        param($sender, $e)
        
        if ($e.NewValue -eq 'Checked') {
            $currentCheckedCount = 0
            for ($i = 0; $i -lt $clbWorkstations.Items.Count; $i++) {
                if ($clbWorkstations.GetItemChecked($i)) {
                    $currentCheckedCount++
                }
            }
        }
    })
    
    # View Week Schedule button - opens week viewer
    $btnViewWeek.Add_Click({
        try {
            if (-not $cmbVenue.SelectedItem) {
                [System.Windows.Forms.MessageBox]::Show('Please select a venue first', 'Validation', 'OK', 'Warning')
                return
            }
            
            # Safely get venue details
            $selectedVenue = $cmbVenue.SelectedItem
            
            if ($selectedVenue -isnot [ComboBoxItem]) {
                Write-Host "WARNING: SelectedItem is not ComboBoxItem, type is: $($selectedVenue.GetType().FullName)" -ForegroundColor Yellow
            }
            
            $venueID = Get-ComboBoxItemValue $selectedVenue
            $venueName = Get-ComboBoxItemText $selectedVenue
            if ([string]::IsNullOrWhiteSpace($venueName)) {
                $venueName = "Venue $venueID"
            }
            
            Write-Host "View Week - VenueID: $venueID, Name: $venueName" -ForegroundColor Cyan
            
            # Check DataVer from Global table to determine if KioskID column exists
            $dataVerQuery = "SELECT DataVer FROM dbo.Global"
            $dataVerResult = Invoke-BepozQuery -ConnectionString $ConnectionString -Query $dataVerQuery
            $dataVer = if ($dataVerResult.Rows.Count -gt 0) { [int]$dataVerResult.Rows[0]['DataVer'] } else { 0 }
            $supportsKiosk = ($dataVer -ge 4729)
            
            Write-Host "Database version: $dataVer $(if ($supportsKiosk) { '(Kiosk support enabled)' } else { '(No Kiosk support)' })" -ForegroundColor Gray
            
            # Build query with conditional KioskID column
            $kioskColumns = if ($supportsKiosk) {
                @"
    ws.KioskID,
    ISNULL(k.Name, CASE WHEN ws.KioskID = 0 THEN 'None' ELSE 'Kiosk ' + CAST(ws.KioskID AS VARCHAR) END) AS KioskName,
"@
            } else { "" }
            
            $kioskJoin = if ($supportsKiosk) {
                "LEFT JOIN dbo.Kiosk k ON ws.KioskID = k.KioskID"
            } else { "" }
            
            # Get all WeekSchedule records for this venue with configuration names
            $query = @"
SELECT 
    ws.VenueID,
    ws.WorkstationID,
    ws.MinutesOffset,
    ws.KeySetID,
    ws.PriceNumber,
    ws.PointsProfile,
    ws.OverrideMap,
    ws.TableMapSetID,
    ws.ChangeShift,
    $kioskColumns
    w.Name AS WorkstationName,
    s.Name AS StoreName,
    CASE WHEN ws.KeySetID = 0 THEN 'Default' ELSE 'KeySet ' + CAST(ws.KeySetID AS VARCHAR) END AS KeySetName,
    CASE 
        WHEN ws.PriceNumber = 0 THEN 'Default'
        WHEN ws.PriceNumber = 1 THEN ISNULL(v.PriceName_1, 'Price 1')
        WHEN ws.PriceNumber = 2 THEN ISNULL(v.PriceName_2, 'Price 2')
        WHEN ws.PriceNumber = 3 THEN ISNULL(v.PriceName_3, 'Price 3')
        WHEN ws.PriceNumber = 4 THEN ISNULL(v.PriceName_4, 'Price 4')
        WHEN ws.PriceNumber = 5 THEN ISNULL(v.PriceName_5, 'Price 5')
        WHEN ws.PriceNumber = 6 THEN ISNULL(v.PriceName_6, 'Price 6')
        WHEN ws.PriceNumber = 7 THEN ISNULL(v.PriceName_7, 'Price 7')
        WHEN ws.PriceNumber = 8 THEN ISNULL(v.PriceName_8, 'Price 8')
        ELSE 'Price ' + CAST(ws.PriceNumber AS VARCHAR)
    END AS PriceName,
    CASE WHEN ws.PointsProfile = 0 THEN 'None' ELSE 'Points ' + CAST(ws.PointsProfile AS VARCHAR) END AS PointsProfileName,
    CASE WHEN ws.OverrideMap = 0 THEN 'None' ELSE 'Override ' + CAST(ws.OverrideMap AS VARCHAR) END AS OverrideMapName,
    CASE WHEN ws.TableMapSetID = 0 THEN 'None' ELSE 'TableMap ' + CAST(ws.TableMapSetID AS VARCHAR) END AS TableMapName,
    CASE
        WHEN ws.ChangeShift = 0 THEN 'No Change'
        WHEN ws.ChangeShift = 1 THEN ISNULL(v.ShiftName0, 'Shift 1')
        WHEN ws.ChangeShift = 2 THEN ISNULL(v.ShiftName1, 'Shift 2')
        WHEN ws.ChangeShift = 3 THEN ISNULL(v.ShiftName2, 'Shift 3')
        WHEN ws.ChangeShift = 4 THEN ISNULL(v.ShiftName3, 'Shift 4')
        WHEN ws.ChangeShift = 5 THEN ISNULL(v.ShiftName4, 'Shift 5')
        WHEN ws.ChangeShift = 6 THEN ISNULL(v.ShiftName5, 'Shift 6')
        WHEN ws.ChangeShift = 7 THEN ISNULL(v.ShiftName6, 'Shift 7')
        WHEN ws.ChangeShift = 8 THEN ISNULL(v.ShiftName7, 'Shift 8')
        WHEN ws.ChangeShift = 9 THEN ISNULL(v.ShiftName8, 'Shift 9')
        WHEN ws.ChangeShift = 10 THEN ISNULL(v.ShiftName9, 'Shift 10')
        ELSE 'Shift ' + CAST(ws.ChangeShift AS VARCHAR)
    END AS ShiftName
FROM dbo.WeekSchedule ws
INNER JOIN dbo.Workstation w ON ws.WorkstationID = w.WorkstationID
INNER JOIN dbo.Store s ON w.StoreID = s.StoreID
INNER JOIN dbo.Venue v ON ws.VenueID = v.VenueID
$kioskJoin
WHERE ws.VenueID = @VenueID
ORDER BY ws.MinutesOffset, w.Name
"@
            
            $schedules = Invoke-BepozQuery -ConnectionString $ConnectionString `
                -Query $query -Parameters @{ '@VenueID' = $venueID }
            
            if ($schedules.Rows.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "No WeekSchedule records found for venue: $venueName",
                    'No Data',
                    'OK',
                    'Information'
                )
                return
            }
            
            # Create week viewer form
            $weekForm = New-Object System.Windows.Forms.Form
            $weekForm.Text = "Week Schedule Viewer - $venueName"
            
            # Adjust width if Kiosk column is present (add 120px for Kiosk column)
            $formWidth = if ($supportsKiosk) { 1720 } else { 1600 }
            $minWidth = if ($supportsKiosk) { 1520 } else { 1400 }
            $dgvWidth = if ($supportsKiosk) { 1680 } else { 1560 }
            
            $weekForm.Size = New-Object System.Drawing.Size($formWidth, 750)
            $weekForm.StartPosition = 'CenterScreen'
            $weekForm.FormBorderStyle = 'Sizable'
            $weekForm.MinimumSize = New-Object System.Drawing.Size($minWidth, 600)
            
            # Add search/filter panel
            $pnlFilter = New-Object System.Windows.Forms.Panel
            $pnlFilter.Location = New-Object System.Drawing.Point(10, 10)
            $pnlFilter.Size = New-Object System.Drawing.Size(1360, 40)
            $pnlFilter.Anchor = 'Top,Left,Right'
            $weekForm.Controls.Add($pnlFilter)
            
            $lblFilter = New-Object System.Windows.Forms.Label
            $lblFilter.Location = New-Object System.Drawing.Point(5, 12)
            $lblFilter.Size = New-Object System.Drawing.Size(120, 20)
            $lblFilter.Text = 'Filter Workstation:'
            $pnlFilter.Controls.Add($lblFilter)
            
            $txtFilter = New-Object System.Windows.Forms.TextBox
            $txtFilter.Location = New-Object System.Drawing.Point(130, 10)
            $txtFilter.Size = New-Object System.Drawing.Size(300, 25)
            $pnlFilter.Controls.Add($txtFilter)
            
            $lblFilterHelp = New-Object System.Windows.Forms.Label
            $lblFilterHelp.Location = New-Object System.Drawing.Point(440, 12)
            $lblFilterHelp.Size = New-Object System.Drawing.Size(400, 20)
            $lblFilterHelp.Text = '(Type to filter by workstation or store name)'
            $lblFilterHelp.ForeColor = [System.Drawing.Color]::Gray
            $pnlFilter.Controls.Add($lblFilterHelp)
            
            # Create DataGridView
            $dgv = New-Object System.Windows.Forms.DataGridView
            $dgv.Location = New-Object System.Drawing.Point(10, 60)
            $dgv.Size = New-Object System.Drawing.Size($dgvWidth, 600)
            $dgv.AutoSizeColumnsMode = 'None'
            $dgv.ReadOnly = $true
            $dgv.AllowUserToAddRows = $false
            $dgv.SelectionMode = 'FullRowSelect'
            $dgv.AllowUserToResizeRows = $false
            $dgv.RowHeadersVisible = $false
            $dgv.MultiSelect = $true
            $dgv.Anchor = 'Top,Bottom,Left,Right'
            $dgv.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
            $dgv.DefaultCellStyle.Font = New-Object System.Drawing.Font('Consolas', 9)
            $dgv.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
            $dgv.ColumnHeadersHeight = 30
            $dgv.RowTemplate.Height = 24
            $dgv.EnableHeadersVisualStyles = $false
            $dgv.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
            $dgv.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
            
            # Add columns with specific widths
            $dgv.Columns.Add('Day', 'Day') | Out-Null
            $dgv.Columns['Day'].Width = 100
            $dgv.Columns['Day'].DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
            
            $dgv.Columns.Add('Time', 'Time') | Out-Null
            $dgv.Columns['Time'].Width = 80
            $dgv.Columns['Time'].DefaultCellStyle.Alignment = 'MiddleCenter'
            $dgv.Columns['Time'].DefaultCellStyle.Font = New-Object System.Drawing.Font('Consolas', 10, [System.Drawing.FontStyle]::Bold)
            
            $dgv.Columns.Add('Workstation', 'Workstation') | Out-Null
            $dgv.Columns['Workstation'].Width = 200
            
            $dgv.Columns.Add('Store', 'Store') | Out-Null
            $dgv.Columns['Store'].Width = 150
            
            $dgv.Columns.Add('Offset', 'Offset') | Out-Null
            $dgv.Columns['Offset'].Width = 70
            $dgv.Columns['Offset'].DefaultCellStyle.Alignment = 'MiddleCenter'
            $dgv.Columns['Offset'].DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray
            
            $dgv.Columns.Add('KeySet', 'KeySet') | Out-Null
            $dgv.Columns['KeySet'].Width = 150
            
            $dgv.Columns.Add('Price', 'Price') | Out-Null
            $dgv.Columns['Price'].Width = 100
            
            $dgv.Columns.Add('Points', 'Points') | Out-Null
            $dgv.Columns['Points'].Width = 120
            
            $dgv.Columns.Add('Override', 'Override Map') | Out-Null
            $dgv.Columns['Override'].Width = 150
            
            $dgv.Columns.Add('TableMap', 'Table Map') | Out-Null
            $dgv.Columns['TableMap'].Width = 150
            
            $dgv.Columns.Add('Shift', 'Shift') | Out-Null
            $dgv.Columns['Shift'].Width = 120
            
            # Add Kiosk column if database version supports it
            if ($supportsKiosk) {
                $dgv.Columns.Add('Kiosk', 'Kiosk') | Out-Null
                $dgv.Columns['Kiosk'].Width = 120
            }
            
            # Day color scheme for visual grouping
            $dayColors = @{
                'Monday'    = [System.Drawing.Color]::FromArgb(255, 245, 245)  # Light red
                'Tuesday'   = [System.Drawing.Color]::FromArgb(255, 250, 240)  # Light orange
                'Wednesday' = [System.Drawing.Color]::FromArgb(255, 255, 240)  # Light yellow
                'Thursday'  = [System.Drawing.Color]::FromArgb(245, 255, 245)  # Light green
                'Friday'    = [System.Drawing.Color]::FromArgb(240, 248, 255)  # Light blue
                'Saturday'  = [System.Drawing.Color]::FromArgb(248, 240, 255)  # Light purple
                'Sunday'    = [System.Drawing.Color]::FromArgb(255, 240, 245)  # Light pink
            }
            
            # Store all rows for filtering
            $script:allScheduleRows = @()
            
            # Populate data
            foreach ($sched in $schedules.Rows) {
                $offset = [int]$sched['MinutesOffset']
                
                # Calculate day and time from offset
                $dayIndex = [Math]::Floor($offset / 1440)
                $dayNames = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
                $day = if ($dayIndex -ge 0 -and $dayIndex -lt 7) { $dayNames[$dayIndex] } else { 'Invalid' }
                
                $minutesInDay = $offset % 1440
                $hours = [int][Math]::Floor($minutesInDay / 60)
                $minutes = [int]($minutesInDay % 60)
                $time = "{0:D2}:{1:D2}" -f $hours, $minutes
                
                # Store row data for filtering
                $rowData = [PSCustomObject]@{
                    Day = $day
                    Time = $time
                    Offset = $offset
                    Workstation = $sched['WorkstationName']
                    Store = $sched['StoreName']
                    KeySet = if ([DBNull]::Value.Equals($sched['KeySetName'])) { 'None' } else { $sched['KeySetName'] }
                    Price = if ([DBNull]::Value.Equals($sched['PriceName'])) { 'Default' } else { $sched['PriceName'] }
                    Points = if ([DBNull]::Value.Equals($sched['PointsProfileName'])) { 'None' } else { $sched['PointsProfileName'] }
                    Override = if ([DBNull]::Value.Equals($sched['OverrideMapName'])) { 'None' } else { $sched['OverrideMapName'] }
                    TableMap = if ([DBNull]::Value.Equals($sched['TableMapName'])) { 'None' } else { $sched['TableMapName'] }
                    Shift = if ([DBNull]::Value.Equals($sched['ShiftName'])) { 'No Change' } else { $sched['ShiftName'] }
                    Kiosk = if ($supportsKiosk) { 
                        if ([DBNull]::Value.Equals($sched['KioskName'])) { 'None' } else { $sched['KioskName'] }
                    } else { $null }
                    DayColor = $dayColors[$day]
                }
                
                $script:allScheduleRows += $rowData
            }
            
            # Function to populate grid
            $populateGrid = {
                param([string]$filterText)
                
                $dgv.Rows.Clear()
                
                foreach ($rowData in $script:allScheduleRows) {
                    # Apply filter
                    if (-not [string]::IsNullOrWhiteSpace($filterText)) {
                        $match = $rowData.Workstation -like "*$filterText*" -or 
                                 $rowData.Store -like "*$filterText*"
                        if (-not $match) { continue }
                    }
                    
                    $row = $dgv.Rows.Add()
                    $dgv.Rows[$row].Cells['Day'].Value = $rowData.Day
                    $dgv.Rows[$row].Cells['Time'].Value = $rowData.Time
                    $dgv.Rows[$row].Cells['Workstation'].Value = $rowData.Workstation
                    $dgv.Rows[$row].Cells['Store'].Value = $rowData.Store
                    $dgv.Rows[$row].Cells['Offset'].Value = $rowData.Offset
                    $dgv.Rows[$row].Cells['KeySet'].Value = $rowData.KeySet
                    $dgv.Rows[$row].Cells['Price'].Value = $rowData.Price
                    $dgv.Rows[$row].Cells['Points'].Value = $rowData.Points
                    $dgv.Rows[$row].Cells['Override'].Value = $rowData.Override
                    $dgv.Rows[$row].Cells['TableMap'].Value = $rowData.TableMap
                    $dgv.Rows[$row].Cells['Shift'].Value = $rowData.Shift
                    
                    # Add Kiosk value if column exists
                    if ($supportsKiosk) {
                        $dgv.Rows[$row].Cells['Kiosk'].Value = $rowData.Kiosk
                    }
                    
                    # Apply day color to Day column
                    $dgv.Rows[$row].Cells['Day'].Style.BackColor = $rowData.DayColor
                }
                
                # Update count label
                $lblCount.Text = "Showing: $($dgv.Rows.Count) of $($script:allScheduleRows.Count) schedule entries"
            }
            
            # Create record count label BEFORE initial population (so populateGrid can update it)
            $lblCount = New-Object System.Windows.Forms.Label
            $lblCount.Location = New-Object System.Drawing.Point(10, 675)
            $lblCount.Size = New-Object System.Drawing.Size(600, 20)
            $lblCount.Text = "Total schedule entries: 0"
            $lblCount.Anchor = 'Bottom,Left'
            
            # Initial population
            & $populateGrid ""
            
            # Filter textbox event
            $txtFilter.Add_TextChanged({
                & $populateGrid $txtFilter.Text
            })
            
            $weekForm.Controls.Add($dgv)
            $weekForm.Controls.Add($lblCount)  # Add label to form
            
            # Add close button (position adjusts based on form width)
            $btnCloseWeek = New-Object System.Windows.Forms.Button
            $btnCloseX = if ($supportsKiosk) { 1600 } else { 1480 }
            $btnCloseWeek.Location = New-Object System.Drawing.Point($btnCloseX, 670)
            $btnCloseWeek.Size = New-Object System.Drawing.Size(90, 30)
            $btnCloseWeek.Text = 'Close'
            $btnCloseWeek.Anchor = 'Bottom,Right'
            $btnCloseWeek.Add_Click({ $weekForm.Close() })
            $weekForm.Controls.Add($btnCloseWeek)
            
            # Add export to CSV button (position adjusts based on form width)
            $btnExport = New-Object System.Windows.Forms.Button
            $btnExportX = if ($supportsKiosk) { 1490 } else { 1370 }
            $btnExport.Location = New-Object System.Drawing.Point($btnExportX, 670)
            $btnExport.Size = New-Object System.Drawing.Size(100, 30)
            $btnExport.Text = 'Export CSV'
            $btnExport.Anchor = 'Bottom,Right'
            $btnExport.Add_Click({
                try {
                    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
                    $saveDialog.Filter = "CSV files (*.csv)|*.csv"
                    $saveDialog.FileName = "WeekSchedule_${venueName}_$(Get-Date -Format 'yyyyMMdd').csv"
                    
                    if ($saveDialog.ShowDialog() -eq 'OK') {
                        $csv = @()
                        $header = if ($supportsKiosk) {
                            "Day,Time,Offset,Workstation,Store,KeySet,Price,Points,Override,TableMap,Shift,Kiosk"
                        } else {
                            "Day,Time,Offset,Workstation,Store,KeySet,Price,Points,Override,TableMap,Shift"
                        }
                        $csv += $header
                        
                        foreach ($rowData in $script:allScheduleRows) {
                            $line = "$($rowData.Day),$($rowData.Time),$($rowData.Offset),$($rowData.Workstation),$($rowData.Store),$($rowData.KeySet),$($rowData.Price),$($rowData.Points),$($rowData.Override),$($rowData.TableMap),$($rowData.Shift)"
                            if ($supportsKiosk) {
                                $line += ",$($rowData.Kiosk)"
                            }
                            $csv += $line
                        }
                        
                        $csv | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
                        
                        [System.Windows.Forms.MessageBox]::Show(
                            "Exported $($script:allScheduleRows.Count) schedule entries to:`n$($saveDialog.FileName)",
                            'Export Successful',
                            'OK',
                            'Information'
                        )
                    }
                }
                catch {
                    [System.Windows.Forms.MessageBox]::Show(
                        "Export failed: $($_.Exception.Message)",
                        'Error',
                        'OK',
                        'Error'
                    )
                }
            })
            $weekForm.Controls.Add($btnExport)
            
            # Add legend
            $lblLegend = New-Object System.Windows.Forms.Label
            $lblLegend.Location = New-Object System.Drawing.Point(720, 675)
            $lblLegend.Size = New-Object System.Drawing.Size(640, 20)
            $lblLegend.Text = 'Color-coded by day | Click column headers to sort | Type to filter'
            $lblLegend.ForeColor = [System.Drawing.Color]::Gray
            $lblLegend.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
            $lblLegend.Anchor = 'Bottom,Right'
            $weekForm.Controls.Add($lblLegend)
            
            [void]$weekForm.ShowDialog()
        }
        catch {
            Write-Host "ERROR in View Week: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            
            [System.Windows.Forms.MessageBox]::Show(
                "Error loading week schedule: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })
    
    # Preview Changes
    $btnPreview.Add_Click({
        try {
            # Validation
            if (-not $cmbVenue.SelectedItem) {
                [System.Windows.Forms.MessageBox]::Show('Please select a venue', 'Validation', 'OK', 'Warning')
                return
            }
            
            $selectedWorkstations = @()
            for ($i = 0; $i -lt $clbWorkstations.CheckedItems.Count; $i++) {
                $selectedWorkstations += $clbWorkstations.CheckedItems[$i]
            }
            
            if ($selectedWorkstations.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Please select at least one workstation', 'Validation', 'OK', 'Warning')
                return
            }
            
            # Get selected days
            $selectedDays = @()
            for ($i = 0; $i -lt $clbDays.CheckedItems.Count; $i++) {
                $selectedDays += $clbDays.CheckedItems[$i]
            }
            
            if ($selectedDays.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Please select at least one day', 'Validation', 'OK', 'Warning')
                return
            }
            
            # Calculate offsets for each selected day
            $dayOffsets = @()
            foreach ($dayName in $selectedDays) {
                $minutesOffset = ConvertFrom-DayAndTime -DayName $dayName -TimeString $txtTime.Text
                
                if ($minutesOffset -lt 0) {
                    [System.Windows.Forms.MessageBox]::Show("Invalid time format. Use HH:MM (e.g., 05:00)", 'Validation', 'OK', 'Warning')
                    return
                }
                
                $dayOffsets += [PSCustomObject]@{
                    Day = $dayName
                    Offset = $minutesOffset
                }
            }
            
            $venueID = Get-ComboBoxItemValue $cmbVenue.SelectedItem
            
            # Build preview
            $previewText = @"
PREVIEW OF CHANGES
==================

Venue: $(Get-ComboBoxItemText $cmbVenue.SelectedItem)
Days: $($selectedDays -join ', ')
Time: $($txtTime.Text)
KeySet: $(Get-ComboBoxItemText $cmbKeySet.SelectedItem)
Price: $(Get-ComboBoxItemText $cmbPrice.SelectedItem)
Points Profile: $(Get-ComboBoxItemText $cmbPoints.SelectedItem)
Table Map: $(Get-ComboBoxItemText $cmbTableMap.SelectedItem)
Change Shift: $(Get-ComboBoxItemText $cmbShift.SelectedItem)
Override Map: $(Get-ComboBoxItemText $cmbOverride.SelectedItem)

WORKSTATIONS TO PROCESS ($($selectedWorkstations.Count)):
"@
            
            $insertCount = 0
            $updateCount = 0
            
            # Check each workstation for each day
            foreach ($ws in $selectedWorkstations) {
                $wsID = $ws.WorkstationID
                $previewText += "`n`n$($ws.Text):"
                
                foreach ($dayOffset in $dayOffsets) {
                    $exists = Test-ScheduleExists -ConnectionString $ConnectionString -VenueID $venueID -WorkstationID $wsID -MinutesOffset $dayOffset.Offset
                    
                    if ($exists) {
                        $previewText += "`n  [UPDATE] $($dayOffset.Day) at offset $($dayOffset.Offset)"
                        $updateCount++
                    }
                    else {
                        $previewText += "`n  [INSERT] $($dayOffset.Day) at offset $($dayOffset.Offset)"
                        $insertCount++
                    }
                }
            }
            
            $previewText += "`n`nSUMMARY:"
            $previewText += "`n  New records to INSERT: $insertCount"
            $previewText += "`n  Existing records to UPDATE: $updateCount"
            $previewText += "`n  Total operations: $($insertCount + $updateCount)"
            $previewText += "`n  (Workstations × Days = $($selectedWorkstations.Count) × $($selectedDays.Count))"
            
            # Show preview dialog
            $previewForm = New-Object System.Windows.Forms.Form
            $previewForm.Text = 'Preview Changes'
            $previewForm.Size = New-Object System.Drawing.Size(700, 600)
            $previewForm.StartPosition = 'CenterParent'
            
            $txtPreview = New-Object System.Windows.Forms.TextBox
            $txtPreview.Multiline = $true
            $txtPreview.ScrollBars = 'Vertical'
            $txtPreview.Font = New-Object System.Drawing.Font('Consolas', 9)
            $txtPreview.Text = $previewText
            $txtPreview.ReadOnly = $true
            $txtPreview.Location = New-Object System.Drawing.Point(10, 10)
            $txtPreview.Size = New-Object System.Drawing.Size(660, 500)
            $previewForm.Controls.Add($txtPreview)
            
            $btnClosePreview = New-Object System.Windows.Forms.Button
            $btnClosePreview.Text = 'Close'
            $btnClosePreview.Location = New-Object System.Drawing.Point(580, 520)
            $btnClosePreview.Size = New-Object System.Drawing.Size(90, 30)
            $btnClosePreview.Add_Click({ $previewForm.Close() })
            $previewForm.Controls.Add($btnClosePreview)
            
            [void]$previewForm.ShowDialog()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Preview error: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })
    
    # Apply Changes
    $btnApply.Add_Click({
        try {
            # Log user action
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "User clicked 'Apply' button"
            }

            # Validation
            if (-not $cmbVenue.SelectedItem) {
                [System.Windows.Forms.MessageBox]::Show('Please select a venue', 'Validation', 'OK', 'Warning')
                return
            }

            $selectedWorkstations = @()
            for ($i = 0; $i -lt $clbWorkstations.CheckedItems.Count; $i++) {
                $selectedWorkstations += $clbWorkstations.CheckedItems[$i]
            }

            if ($selectedWorkstations.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Please select at least one workstation', 'Validation', 'OK', 'Warning')
                return
            }

            # Get selected days
            $selectedDays = @()
            for ($i = 0; $i -lt $clbDays.CheckedItems.Count; $i++) {
                $selectedDays += $clbDays.CheckedItems[$i]
            }

            # Log operation details
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "Apply operation: $($selectedWorkstations.Count) workstations, $($selectedDays.Count) days"
            }
            
            if ($selectedDays.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Please select at least one day', 'Validation', 'OK', 'Warning')
                return
            }
            
            # Calculate offsets for each selected day
            $dayOffsets = @()
            foreach ($dayName in $selectedDays) {
                $minutesOffset = ConvertFrom-DayAndTime -DayName $dayName -TimeString $txtTime.Text
                
                if ($minutesOffset -lt 0) {
                    [System.Windows.Forms.MessageBox]::Show("Invalid time format. Use HH:MM (e.g., 05:00)", 'Validation', 'OK', 'Warning')
                    return
                }
                
                $dayOffsets += [PSCustomObject]@{
                    Day = $dayName
                    Offset = $minutesOffset
                }
            }
            
            # Confirm
            $confirmMsg = "Apply schedule changes to $($selectedWorkstations.Count) workstation(s)?`n`n"
            $confirmMsg += "Days: $($selectedDays -join ', ')`n"
            $confirmMsg += "Time: $($txtTime.Text)`n"
            $confirmMsg += "Venue: $(Get-ComboBoxItemText $cmbVenue.SelectedItem)`n`n"
            $confirmMsg += "Total schedule entries: $($selectedWorkstations.Count * $selectedDays.Count)`n"
            $confirmMsg += "(Workstations x Days = $($selectedWorkstations.Count) x $($selectedDays.Count))`n`n"
            $confirmMsg += "This will INSERT new records or UPDATE existing ones.`n`n"
            $confirmMsg += "Continue?"
            
            $result = [System.Windows.Forms.MessageBox]::Show($confirmMsg, 'Confirm', 'YesNo', 'Question')
            
            if ($result -ne 'Yes') {
                return
            }
            
            $statusLabel.Text = 'Applying changes...'
            $form.Refresh()
            
            $venueID = Get-ComboBoxItemValue $cmbVenue.SelectedItem
            $keySetID = Get-ComboBoxItemValue $cmbKeySet.SelectedItem
            $priceNumber = Get-ComboBoxItemValue $cmbPrice.SelectedItem
            $pointsProfile = Get-ComboBoxItemValue $cmbPoints.SelectedItem
            $tableMapSetID = Get-ComboBoxItemValue $cmbTableMap.SelectedItem
            $changeShift = Get-ComboBoxItemValue $cmbShift.SelectedItem
            # OverrideMap: Use name from dropdown, or empty string if "No Change" (ID=0)
            $overrideMapID = Get-ComboBoxItemValue $cmbOverride.SelectedItem
            $overrideMap = if ($overrideMapID -eq 0) { '' } else { 
                # Extract name part from "ID - Name" format
                $fullText = Get-ComboBoxItemText $cmbOverride.SelectedItem
                if ($fullText -match '^\d+\s*-\s*(.+)$') {
                    $Matches[1]
                } else {
                    ''
                }
            }
            
            Write-Host "`n=== Applying WeekSchedule Changes ===" -ForegroundColor Cyan
            Write-Host "VenueID: $venueID" -ForegroundColor Yellow
            Write-Host "Days: $($selectedDays -join ', ')" -ForegroundColor Yellow
            Write-Host "Time: $($txtTime.Text)" -ForegroundColor Yellow
            
            $insertCount = 0
            $updateCount = 0
            $errorCount = 0
            
            # Loop through each workstation and each selected day
            foreach ($ws in $selectedWorkstations) {
                $wsID = $ws.WorkstationID
                
                foreach ($dayOffset in $dayOffsets) {
                    $minutesOffset = $dayOffset.Offset
                    $dayName = $dayOffset.Day
                    
                    try {
                        $exists = Test-ScheduleExists -ConnectionString $ConnectionString -VenueID $venueID -WorkstationID $wsID -MinutesOffset $minutesOffset
                    
                    if ($exists) {
                        Write-Host "  Updating WorkstationID: $wsID ($($ws.WorkstationName))..." -ForegroundColor Yellow
                        
                        Update-WeekSchedule -ConnectionString $ConnectionString `
                            -VenueID $venueID `
                            -WorkstationID $wsID `
                            -MinutesOffset $minutesOffset `
                            -KeySetID $keySetID `
                            -PriceNumber $priceNumber `
                            -PointsProfile $pointsProfile `
                            -OverrideMap $overrideMap `
                            -TableMapSetID $tableMapSetID `
                            -ChangeShift $changeShift
                        
                        $updateCount++
                        Write-Host "    Updated successfully" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  Inserting WorkstationID: $wsID ($($ws.WorkstationName))..." -ForegroundColor Yellow
                        
                        New-WeekSchedule -ConnectionString $ConnectionString `
                            -VenueID $venueID `
                            -WorkstationID $wsID `
                            -MinutesOffset $minutesOffset `
                            -KeySetID $keySetID `
                            -PriceNumber $priceNumber `
                            -PointsProfile $pointsProfile `
                            -OverrideMap $overrideMap `
                            -TableMapSetID $tableMapSetID `
                            -ChangeShift $changeShift
                        
                        $insertCount++
                        Write-Host "    Inserted successfully" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
                    $errorCount++
                }
                }
            }
            
            Write-Host "`n=== Summary ===" -ForegroundColor Cyan
            Write-Host "Inserted: $insertCount" -ForegroundColor Green
            Write-Host "Updated: $updateCount" -ForegroundColor Green
            if ($errorCount -gt 0) {
                Write-Host "Errors: $errorCount" -ForegroundColor Red
            }

            # Log operation results
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "Apply completed: Inserted=$insertCount, Updated=$updateCount, Errors=$errorCount"
            }

            $statusLabel.Text = "Completed: $insertCount inserted, $updateCount updated, $errorCount errors"
            
            [System.Windows.Forms.MessageBox]::Show(
                "WeekSchedule changes applied!`n`n" +
                "Inserted: $insertCount`n" +
                "Updated: $updateCount`n" +
                "Errors: $errorCount`n`n" +
                "Days: $($selectedDays -join ', ')`n" +
                "Time: $($txtTime.Text)`n" +
                "Workstations: $($selectedWorkstations.Count)`n" +
                "Total entries processed: $($selectedWorkstations.Count * $selectedDays.Count)",
                'Success',
                'OK',
                'Information'
            )
        }
        catch {
            $statusLabel.Text = 'Error applying changes'

            # Log error
            if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
                Write-BepozLogError -Message "Apply operation failed" -Exception $_.Exception
            }

            [System.Windows.Forms.MessageBox]::Show(
                "Failed to apply changes: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })

    # Delete Schedules
    $btnDelete.Add_Click({
        # Log user action
        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "User clicked 'Delete' button"
        }

        try {
            # Validation
            if (-not $cmbVenue.SelectedItem) {
                [System.Windows.Forms.MessageBox]::Show('Please select a venue', 'Validation', 'OK', 'Warning')
                return
            }
            
            $selectedWorkstations = @()
            for ($i = 0; $i -lt $clbWorkstations.CheckedItems.Count; $i++) {
                $selectedWorkstations += $clbWorkstations.CheckedItems[$i]
            }
            
            if ($selectedWorkstations.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show('Please select at least one workstation', 'Validation', 'OK', 'Warning')
                return
            }
            
            # Confirm deletion
            $confirmMsg = "DELETE ALL WeekSchedule records for $($selectedWorkstations.Count) workstation(s)?`n`n"
            $confirmMsg += "Venue: $(Get-ComboBoxItemText $cmbVenue.SelectedItem)`n`n"
            $confirmMsg += "This will remove ALL schedule entries for the selected workstations.`n"
            $confirmMsg += "This action CANNOT be undone.`n`n"
            $confirmMsg += "Are you sure?"
            
            $result = [System.Windows.Forms.MessageBox]::Show($confirmMsg, 'Confirm Deletion', 'YesNo', 'Warning')

            if ($result -ne 'Yes') {
                if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                    Write-BepozLogAction "User cancelled delete operation"
                }
                return
            }

            # Log confirmed operation details
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                $venueName = Get-ComboBoxItemText $cmbVenue.SelectedItem
                Write-BepozLogAction "Delete operation confirmed: $($selectedWorkstations.Count) workstations for venue '$venueName'"
            }

            $statusLabel.Text = 'Deleting schedules...'
            $form.Refresh()
            
            $venueID = Get-ComboBoxItemValue $cmbVenue.SelectedItem
            
            Write-Host "`n=== Deleting WeekSchedule Records ===" -ForegroundColor Cyan
            Write-Host "VenueID: $venueID" -ForegroundColor Yellow
            
            $deleteCount = 0
            $errorCount = 0
            
            foreach ($ws in $selectedWorkstations) {
                $wsID = $ws.WorkstationID
                
                try {
                    Write-Host "  Deleting WorkstationID: $wsID ($($ws.WorkstationName))..." -ForegroundColor Yellow
                    
                    $rowsDeleted = Remove-WeekSchedule -ConnectionString $ConnectionString -VenueID $venueID -WorkstationID $wsID
                    
                    Write-Host "    Deleted $rowsDeleted record(s)" -ForegroundColor Green
                    $deleteCount += $rowsDeleted
                }
                catch {
                    Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
                    $errorCount++
                }
            }
            
            Write-Host "`n=== Summary ===" -ForegroundColor Cyan
            Write-Host "Total records deleted: $deleteCount" -ForegroundColor Green
            if ($errorCount -gt 0) {
                Write-Host "Errors: $errorCount" -ForegroundColor Red
            }
            
            $statusLabel.Text = "Deleted $deleteCount record(s) from $($selectedWorkstations.Count) workstation(s)"

            # Log completion
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "Delete completed: Deleted=$deleteCount, Workstations=$($selectedWorkstations.Count), Errors=$errorCount"
            }

            [System.Windows.Forms.MessageBox]::Show(
                "WeekSchedule records deleted!`n`n" +
                "Total records deleted: $deleteCount`n" +
                "Workstations processed: $($selectedWorkstations.Count)`n" +
                "Errors: $errorCount",
                'Deletion Complete',
                'OK',
                'Information'
            )
        }
        catch {
            $statusLabel.Text = 'Error deleting schedules'

            # Log error
            if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
                Write-BepozLogError -Message "Delete operation failed" -Exception $_.Exception
            }

            [System.Windows.Forms.MessageBox]::Show(
                "Failed to delete schedules: $($_.Exception.Message)",
                'Error',
                'OK',
                'Error'
            )
        }
    })
    
    # Close button
    $btnClose.Add_Click({
        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "User closed tool"
        }
        $form.Close()
    })
    
    #endregion
    
    # Load initial data
    Load-Venues
    
    # Show form
    [void]$form.ShowDialog()
}

#endregion

#region Main Entry Point

try {
    # Database already initialized in the module loading section above
    # $script:ConnectionString is set and ready to use
    
    Show-WeekScheduleManager -ConnectionString $script:ConnectionString
}
catch {
    Write-Host "`nFATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Gray

    # Log fatal error
    if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
        Write-BepozLogError -Message "Fatal error in tool execution" -Exception $_.Exception -StackTrace $_.ScriptStackTrace
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Fatal error:`n`n$($_.Exception.Message)`n`nSee console for details.",
        'Fatal Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    
    exit 1
}
finally {
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

#endregion

