#Requires -Version 5.1

<#
.SYNOPSIS
    Bepoz Web API Settings Manager

.DESCRIPTION
    GUI tool to manage Web API settings stored in dbo.Global and Windows Firewall rules.

    Tab 1 - Web API: Edit WebApiSecretKey, WebApiClientID, WebApiPort
    Tab 2 - Firewall: Create/update inbound TCP rule "BepozSnapshots"

    Version 2.0 - Migrated to use Bepoz Toolkit modules (BepozDbCore, BepozLogger, BepozTheme)

.NOTES
    Author: Bepoz Administration Team
    Version: 2.0.0
    PowerShell Version: 5.1+
    Dependencies: BepozDbCore.ps1, BepozLogger.ps1 (optional), BepozTheme.ps1 (optional)

    Changelog:
    - 2.0.0: Migrated to Bepoz Toolkit framework with logging and theming
    - 1.0.0: Initial standalone version
#>

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

#region Module Loading

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Bepoz Web API Settings Manager" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load BepozDbCore (required)
Write-Host "[INFO] Loading BepozDbCore module..." -ForegroundColor Cyan
$dbCoreModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $dbCoreModule) {
    Write-Host "[ERROR] BepozDbCore module not found in temp directory" -ForegroundColor Red
    Write-Host "Expected location: $env:TEMP\BepozDbCore.ps1" -ForegroundColor Yellow
    Write-Host ""
    [System.Windows.Forms.MessageBox]::Show(
        "Database module (BepozDbCore.ps1) not found.`n`nThis tool must be run through the Bepoz Toolkit.",
        'Module Not Found',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

try {
    . $dbCoreModule.FullName
    Write-Host "[OK] BepozDbCore loaded from: $($dbCoreModule.FullName)" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load BepozDbCore: $($_.Exception.Message)" -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to load database module.`n`n$($_.Exception.Message)",
        'Module Load Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

# Load BepozLogger (optional)
$loggerModule = Get-ChildItem -Path $env:TEMP -Filter "BepozLogger.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($loggerModule) {
    try {
        . $loggerModule.FullName
        $script:LogFile = Initialize-BepozLogger -ToolName "BepozWebApiSettings"
        Write-Host "[OK] Logging initialized: $script:LogFile" -ForegroundColor Green
        Write-BepozLogAction "Tool started"
    } catch {
        Write-Host "WARNING: Logger module found but failed to load: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "WARNING: Continuing without logging..." -ForegroundColor Yellow
    }
} else {
    Write-Host "NOTE: BepozLogger module not found (optional)" -ForegroundColor Yellow
}

# Load BepozTheme (optional)
$themeModule = Get-ChildItem -Path $env:TEMP -Filter "BepozTheme.ps1" -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($themeModule) {
    try {
        . $themeModule.FullName
        Write-Host "[OK] BepozTheme loaded" -ForegroundColor Green
        $script:ThemeAvailable = $true
    } catch {
        Write-Host "NOTE: Theme module found but failed to load" -ForegroundColor Yellow
        $script:ThemeAvailable = $false
    }
} else {
    Write-Host "NOTE: BepozTheme module not found (optional)" -ForegroundColor Yellow
    $script:ThemeAvailable = $false
}

Write-Host ""

#endregion

#region Database Connection

try {
    Write-Host "Initializing database connection..." -ForegroundColor Cyan
    $script:dbInfo = Get-BepozDbInfo -ApplicationName 'BepozWebApiSettings'
    $script:ConnStr = $script:dbInfo.ConnectionString

    Write-Host "[OK] Database connection initialized" -ForegroundColor Green
    Write-Host "    Server: $($script:dbInfo.Server)" -ForegroundColor Gray
    Write-Host "    Database: $($script:dbInfo.Database)" -ForegroundColor Gray
    Write-Host ""

    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "Database connected: $($script:dbInfo.Server)\$($script:dbInfo.Database)"
    }
} catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to initialize database connection" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to discover database connection.`n`n$($_.Exception.Message)",
        'Database Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

if (-not (Test-BepozDatabaseConnection)) {
    Write-Host "[ERROR] Cannot connect to database" -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show(
        "Cannot connect to database: $($script:dbInfo.Server)\$($script:dbInfo.Database)",
        'Connection Failed',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}

#endregion

#region Schema Validation

function Test-GlobalColumns {
    <#
    .SYNOPSIS
        Verify WebApi columns exist in dbo.Global before attempting reads/writes.
    #>
    $requiredCols = @('WebApiSecretKey', 'WebApiClientID', 'WebApiPort')

    $query = @"
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Global'
  AND COLUMN_NAME IN ('WebApiSecretKey','WebApiClientID','WebApiPort')
"@

    try {
        $dt = Invoke-BepozQuery -Query $query
        $found = @()
        foreach ($row in $dt.Rows) {
            $found += $row['COLUMN_NAME']
        }

        $missing = $requiredCols | Where-Object { $_ -notin $found }

        if ($missing.Count -gt 0) {
            if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
                Write-BepozLogError -Message "Missing columns in Global table: $($missing -join ', ')"
            }
            return @{
                Valid   = $false
                Missing = $missing
                Found   = $found
            }
        }

        return @{ Valid = $true; Missing = @(); Found = $found }

    } catch {
        if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
            Write-BepozLogError -Message "Schema validation failed" -Exception $_.Exception
        }
        return @{
            Valid   = $false
            Missing = $requiredCols
            Found   = @()
            Error   = $_.Exception.Message
        }
    }
}

#endregion

#region Global Table Access

function Get-GlobalValues {
    <#
    .SYNOPSIS
        Read WebApi settings from dbo.Global (single-row table, direct columns).
    .OUTPUTS
        Hashtable with SecretKey, ClientID, Port (or empty values on failure).
    #>
    $query = 'SELECT WebApiSecretKey, WebApiClientID, WebApiPort FROM dbo.Global'

    try {
        $dt = Invoke-BepozQuery -Query $query

        if ($dt.Rows.Count -eq 0) {
            Write-Warning 'Global table returned no rows'
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "WARNING: Global table has no rows"
            }
            return @{ SecretKey = ''; ClientID = ''; Port = 0 }
        }

        $row = $dt.Rows[0]

        $values = @{
            SecretKey = if ($null -ne $row['WebApiSecretKey'] -and $row['WebApiSecretKey'] -isnot [System.DBNull]) { $row['WebApiSecretKey'].ToString() } else { '' }
            ClientID  = if ($null -ne $row['WebApiClientID']  -and $row['WebApiClientID']  -isnot [System.DBNull]) { $row['WebApiClientID'].ToString()  } else { '' }
            Port      = if ($null -ne $row['WebApiPort']      -and $row['WebApiPort']      -isnot [System.DBNull]) { [int]$row['WebApiPort']            } else { 0  }
        }

        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "Loaded Web API settings from database (Port: $($values.Port))"
        }

        return $values

    } catch {
        Write-Error "Failed to read Global values: $($_.Exception.Message)"
        if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
            Write-BepozLogError -Message "Failed to read Global values" -Exception $_.Exception
        }
        return @{ SecretKey = ''; ClientID = ''; Port = 0 }
    }
}

function Set-GlobalValues {
    <#
    .SYNOPSIS
        Write WebApi settings back to dbo.Global using parameterized SQL.
    .OUTPUTS
        Int32 (rows affected) - should be 1.
    #>
    param(
        [string]$SecretKey,
        [string]$ClientID,
        [int]$Port
    )

    $query = @"
UPDATE dbo.Global
SET WebApiSecretKey = @SecretKey,
    WebApiClientID  = @ClientID,
    WebApiPort      = @Port
"@

    $params = @{
        SecretKey = $SecretKey
        ClientID  = $ClientID
        Port      = $Port
    }

    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "Saving Web API settings (Port: $Port)"
    }

    $rowsAffected = Invoke-BepozNonQuery -Query $query -Parameters $params

    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "Web API settings saved ($rowsAffected rows affected)"
    }

    return $rowsAffected
}

#endregion

#region Firewall Rule Management

$script:FirewallRuleName = 'BepozSnapshots'

function Get-FirewallRuleStatus {
    <#
    .SYNOPSIS
        Check current state of the BepozSnapshots firewall rule.
    .OUTPUTS
        Hashtable with Exists, Enabled, Port, Profiles, Protocol (or defaults if not found).
    #>
    try {
        $rule = Get-NetFirewallRule -DisplayName $script:FirewallRuleName -ErrorAction SilentlyContinue

        if ($null -eq $rule) {
            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "Firewall rule '$($script:FirewallRuleName)' does not exist"
            }
            return @{ Exists = $false; Enabled = $false; Port = ''; Profiles = ''; Protocol = '' }
        }

        # Get port filter
        $portFilter = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue

        $status = @{
            Exists   = $true
            Enabled  = ($rule.Enabled -eq 'True')
            Port     = if ($portFilter) { $portFilter.LocalPort } else { '' }
            Profiles = $rule.Profile.ToString()
            Protocol = if ($portFilter) { $portFilter.Protocol } else { '' }
        }

        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "Firewall rule status checked: Exists=$($status.Exists), Enabled=$($status.Enabled), Port=$($status.Port)"
        }

        return $status

    } catch {
        Write-Error "Firewall query failed: $($_.Exception.Message)"
        if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
            Write-BepozLogError -Message "Firewall query failed" -Exception $_.Exception
        }
        return @{ Exists = $false; Enabled = $false; Port = ''; Profiles = ''; Protocol = ''; Error = $_.Exception.Message }
    }
}

function Ensure-FirewallRule {
    <#
    .SYNOPSIS
        Create or update the BepozSnapshots inbound TCP rule (Domain + Private profiles).
    .PARAMETER Port
        TCP port to allow inbound.
    .OUTPUTS
        Hashtable with Success (bool), Action (string), Message (string).
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Port
    )

    if ($Port -lt 1 -or $Port -gt 65535) {
        if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
            Write-BepozLogError -Message "Invalid port specified: $Port"
        }
        return @{ Success = $false; Action = 'None'; Message = "Invalid port: $Port (must be 1-65535)" }
    }

    try {
        $existing = Get-NetFirewallRule -DisplayName $script:FirewallRuleName -ErrorAction SilentlyContinue

        if ($null -ne $existing) {
            # Rule exists - update port if needed
            $portFilter = $existing | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
            $currentPort = if ($portFilter) { $portFilter.LocalPort } else { '' }

            if ($currentPort -eq $Port.ToString()) {
                if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                    Write-BepozLogAction "Firewall rule already configured correctly (port $Port)"
                }
                return @{ Success = $true; Action = 'NoChange'; Message = "Rule already exists with port $Port. No changes needed." }
            }

            # Update the existing rule's port and ensure correct profiles
            Set-NetFirewallRule -DisplayName $script:FirewallRuleName `
                -LocalPort $Port `
                -Profile Domain, Private `
                -ErrorAction Stop

            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "Firewall rule updated: port changed from $currentPort to $Port"
            }

            return @{ Success = $true; Action = 'Updated'; Message = "Rule updated: port changed from $currentPort to $Port." }

        } else {
            # Create new rule
            New-NetFirewallRule `
                -Name $script:FirewallRuleName `
                -DisplayName $script:FirewallRuleName `
                -Description 'Bepoz Web API inbound access (managed by Bepoz Web API Settings tool)' `
                -Direction Inbound `
                -Action Allow `
                -Protocol TCP `
                -LocalPort $Port `
                -Profile Domain, Private `
                -Enabled True `
                -ErrorAction Stop | Out-Null

            if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
                Write-BepozLogAction "Firewall rule created: TCP port $Port (Domain + Private profiles)"
            }

            return @{ Success = $true; Action = 'Created'; Message = "Rule created: TCP port $Port allowed (Domain + Private profiles)." }
        }

    } catch {
        if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
            Write-BepozLogError -Message "Firewall operation failed" -Exception $_.Exception
        }
        return @{ Success = $false; Action = 'Error'; Message = "Firewall operation failed: $($_.Exception.Message)" }
    }
}

#endregion

#region GUI Construction

# Create form
if ($script:ThemeAvailable) {
    $form = New-BepozForm -Title "Bepoz Web API Settings - $($script:dbInfo.Database)" -Size (520, 420) -ShowBrand $false
} else {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Bepoz Web API Settings - $($script:dbInfo.Database)"
    $form.Size = New-Object System.Drawing.Size(520, 420)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.BackColor = [System.Drawing.Color]::White
}

# Status bar
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Connected: $($script:dbInfo.Server)\$($script:dbInfo.Database)"
$statusLabel.Spring = $true
$statusLabel.TextAlign = 'MiddleLeft'
[void]$statusBar.Items.Add($statusLabel)
$form.Controls.Add($statusBar)

# Tab control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(8, 8)
$tabControl.Size = New-Object System.Drawing.Size(496, 350)

#region Tab 1: Web API

$tabApi = New-Object System.Windows.Forms.TabPage
$tabApi.Text = 'Web API'
$tabApi.Padding = New-Object System.Windows.Forms.Padding(12)
$tabApi.BackColor = [System.Drawing.Color]::White

$yPos = 16

# Secret Key
$lblSecret = New-Object System.Windows.Forms.Label
$lblSecret.Text = 'Secret Key:'
$lblSecret.Location = New-Object System.Drawing.Point(16, $yPos)
$lblSecret.Size = New-Object System.Drawing.Size(100, 22)
$tabApi.Controls.Add($lblSecret)

$txtSecret = New-Object System.Windows.Forms.TextBox
$txtSecret.Location = New-Object System.Drawing.Point(120, $yPos)
$txtSecret.Size = New-Object System.Drawing.Size(280, 22)
$txtSecret.UseSystemPasswordChar = $true
$txtSecret.MaxLength = 500
$tabApi.Controls.Add($txtSecret)

# Show/Hide button for secret key
if ($script:ThemeAvailable) {
    $btnShowSecret = New-BepozButton -Text "Show" -Type Neutral -Location (406, ($yPos - 1)) -Size (60, 24)
} else {
    $btnShowSecret = New-Object System.Windows.Forms.Button
    $btnShowSecret.Text = 'Show'
    $btnShowSecret.Location = New-Object System.Drawing.Point(406, ($yPos - 1))
    $btnShowSecret.Size = New-Object System.Drawing.Size(60, 24)
    $btnShowSecret.FlatStyle = 'Flat'
}
$btnShowSecret.Add_Click({
    if ($txtSecret.UseSystemPasswordChar) {
        $txtSecret.UseSystemPasswordChar = $false
        $btnShowSecret.Text = 'Hide'
        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "User revealed Secret Key"
        }
    } else {
        $txtSecret.UseSystemPasswordChar = $true
        $btnShowSecret.Text = 'Show'
        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "User hid Secret Key"
        }
    }
})
$tabApi.Controls.Add($btnShowSecret)

$yPos += 36

# Client ID
$lblClient = New-Object System.Windows.Forms.Label
$lblClient.Text = 'Client ID:'
$lblClient.Location = New-Object System.Drawing.Point(16, $yPos)
$lblClient.Size = New-Object System.Drawing.Size(100, 22)
$tabApi.Controls.Add($lblClient)

$txtClientID = New-Object System.Windows.Forms.TextBox
$txtClientID.Location = New-Object System.Drawing.Point(120, $yPos)
$txtClientID.Size = New-Object System.Drawing.Size(346, 22)
$txtClientID.MaxLength = 500
$tabApi.Controls.Add($txtClientID)

$yPos += 36

# Port
$lblPort = New-Object System.Windows.Forms.Label
$lblPort.Text = 'API Port:'
$lblPort.Location = New-Object System.Drawing.Point(16, $yPos)
$lblPort.Size = New-Object System.Drawing.Size(100, 22)
$tabApi.Controls.Add($lblPort)

$nudPort = New-Object System.Windows.Forms.NumericUpDown
$nudPort.Location = New-Object System.Drawing.Point(120, $yPos)
$nudPort.Size = New-Object System.Drawing.Size(100, 22)
$nudPort.Minimum = 1
$nudPort.Maximum = 65535
$nudPort.Value = 8080
$tabApi.Controls.Add($nudPort)

$yPos += 48

# Save / Reload buttons
if ($script:ThemeAvailable) {
    $btnSave = New-BepozButton -Text "Save Settings" -Type Success -Location (120, $yPos) -Size (120, 32)
    $btnReload = New-BepozButton -Text "Reload" -Type Neutral -Location (250, $yPos) -Size (80, 32)
} else {
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = 'Save Settings'
    $btnSave.Location = New-Object System.Drawing.Point(120, $yPos)
    $btnSave.Size = New-Object System.Drawing.Size(120, 32)
    $btnSave.BackColor = [System.Drawing.Color]::FromArgb(10, 124, 72)  # Bepoz Green
    $btnSave.ForeColor = [System.Drawing.Color]::White
    $btnSave.FlatStyle = 'Flat'

    $btnReload = New-Object System.Windows.Forms.Button
    $btnReload.Text = 'Reload'
    $btnReload.Location = New-Object System.Drawing.Point(250, $yPos)
    $btnReload.Size = New-Object System.Drawing.Size(80, 32)
    $btnReload.FlatStyle = 'Flat'
}
$tabApi.Controls.Add($btnSave)
$tabApi.Controls.Add($btnReload)

$yPos += 48

# Validation message area
$lblApiStatus = New-Object System.Windows.Forms.Label
$lblApiStatus.Location = New-Object System.Drawing.Point(16, $yPos)
$lblApiStatus.Size = New-Object System.Drawing.Size(450, 60)
$lblApiStatus.ForeColor = [System.Drawing.Color]::DarkGreen
$lblApiStatus.Text = ''
$tabApi.Controls.Add($lblApiStatus)

#endregion

#region Tab 2: Firewall

$tabFirewall = New-Object System.Windows.Forms.TabPage
$tabFirewall.Text = 'Firewall'
$tabFirewall.Padding = New-Object System.Windows.Forms.Padding(12)
$tabFirewall.BackColor = [System.Drawing.Color]::White

$yFw = 16

# Current rule status panel
$grpStatus = New-Object System.Windows.Forms.GroupBox
$grpStatus.Text = 'Current Firewall Rule Status'
$grpStatus.Location = New-Object System.Drawing.Point(16, $yFw)
$grpStatus.Size = New-Object System.Drawing.Size(450, 130)
$grpStatus.BackColor = [System.Drawing.Color]::White
$tabFirewall.Controls.Add($grpStatus)

$lblFwStatus = New-Object System.Windows.Forms.Label
$lblFwStatus.Location = New-Object System.Drawing.Point(12, 24)
$lblFwStatus.Size = New-Object System.Drawing.Size(424, 90)
$lblFwStatus.Font = New-Object System.Drawing.Font('Consolas', 9)
$lblFwStatus.Text = 'Checking...'
$grpStatus.Controls.Add($lblFwStatus)

$yFw += 148

# Open Firewall Port button
if ($script:ThemeAvailable) {
    $btnFirewall = New-BepozButton -Text "Open Firewall Port" -Type Success -Location (16, $yFw) -Size (160, 32)
    $btnRefreshFw = New-BepozButton -Text "Refresh Status" -Type Neutral -Location (186, $yFw) -Size (120, 32)
} else {
    $btnFirewall = New-Object System.Windows.Forms.Button
    $btnFirewall.Text = 'Open Firewall Port'
    $btnFirewall.Location = New-Object System.Drawing.Point(16, $yFw)
    $btnFirewall.Size = New-Object System.Drawing.Size(160, 32)
    $btnFirewall.BackColor = [System.Drawing.Color]::FromArgb(10, 124, 72)  # Bepoz Green
    $btnFirewall.ForeColor = [System.Drawing.Color]::White
    $btnFirewall.FlatStyle = 'Flat'

    $btnRefreshFw = New-Object System.Windows.Forms.Button
    $btnRefreshFw.Text = 'Refresh Status'
    $btnRefreshFw.Location = New-Object System.Drawing.Point(186, $yFw)
    $btnRefreshFw.Size = New-Object System.Drawing.Size(120, 32)
    $btnRefreshFw.FlatStyle = 'Flat'
}
$tabFirewall.Controls.Add($btnFirewall)
$tabFirewall.Controls.Add($btnRefreshFw)

$yFw += 48

# Firewall result label
$lblFwResult = New-Object System.Windows.Forms.Label
$lblFwResult.Location = New-Object System.Drawing.Point(16, $yFw)
$lblFwResult.Size = New-Object System.Drawing.Size(450, 60)
$lblFwResult.ForeColor = [System.Drawing.Color]::DarkGreen
$lblFwResult.Text = ''
$tabFirewall.Controls.Add($lblFwResult)

#endregion

# Assemble tabs
[void]$tabControl.TabPages.Add($tabApi)
[void]$tabControl.TabPages.Add($tabFirewall)
$form.Controls.Add($tabControl)

#endregion

#region Event Handlers

function Update-FirewallStatusDisplay {
    $status = Get-FirewallRuleStatus

    if ($status.Exists) {
        $enabledText = if ($status.Enabled) { 'Yes' } else { 'No' }
        $lblFwStatus.Text = @"
Rule Name:  $($script:FirewallRuleName)
Exists:     Yes
Enabled:    $enabledText
Protocol:   $($status.Protocol)
Port:       $($status.Port)
Profiles:   $($status.Profiles)
"@
        $lblFwStatus.ForeColor = if ($status.Enabled) { [System.Drawing.Color]::DarkGreen } else { [System.Drawing.Color]::DarkOrange }
    } else {
        $lblFwStatus.Text = @"
Rule Name:  $($script:FirewallRuleName)
Exists:     No
Status:     Rule not found - click 'Open Firewall Port' to create.
"@
        $lblFwStatus.ForeColor = [System.Drawing.Color]::Gray
    }

    if ($status.Error) {
        $lblFwStatus.Text += "`nError: $($status.Error)"
        $lblFwStatus.ForeColor = [System.Drawing.Color]::Red
    }
}

function Load-ApiSettings {
    $lblApiStatus.ForeColor = [System.Drawing.Color]::Gray
    $lblApiStatus.Text = 'Loading settings...'
    $form.Refresh()

    # Schema validation first
    $schemaCheck = Test-GlobalColumns
    if (-not $schemaCheck.Valid) {
        $missing = $schemaCheck.Missing -join ', '
        $lblApiStatus.ForeColor = [System.Drawing.Color]::Red
        $lblApiStatus.Text = "Schema error: columns not found in dbo.Global:`n$missing`n`nThe database may need updating."
        $btnSave.Enabled = $false
        return
    }

    $btnSave.Enabled = $true

    $values = Get-GlobalValues
    $txtSecret.Text   = $values.SecretKey
    $txtClientID.Text = $values.ClientID

    if ($values.Port -ge 1 -and $values.Port -le 65535) {
        $nudPort.Value = $values.Port
    } else {
        $nudPort.Value = 8080
    }

    $lblApiStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    $lblApiStatus.Text = 'Settings loaded successfully.'
}

function Validate-ApiInputs {
    <#
    .SYNOPSIS
        Validate form inputs before saving. Returns error message or empty string.
    #>
    $errors = @()

    if ([string]::IsNullOrWhiteSpace($txtSecret.Text)) {
        $errors += 'Secret Key is required.'
    }

    if ([string]::IsNullOrWhiteSpace($txtClientID.Text)) {
        $errors += 'Client ID is required.'
    }

    $port = [int]$nudPort.Value
    if ($port -lt 1 -or $port -gt 65535) {
        $errors += 'Port must be between 1 and 65535.'
    }

    return ($errors -join "`n")
}

# Save button handler
$btnSave.Add_Click({
    $validationErrors = Validate-ApiInputs
    if ($validationErrors) {
        $lblApiStatus.ForeColor = [System.Drawing.Color]::Red
        $lblApiStatus.Text = "Validation errors:`n$validationErrors"
        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "Validation failed: $validationErrors"
        }
        return
    }

    $lblApiStatus.ForeColor = [System.Drawing.Color]::Gray
    $lblApiStatus.Text = 'Saving...'
    $form.Refresh()

    try {
        $rows = Set-GlobalValues -SecretKey $txtSecret.Text -ClientID $txtClientID.Text -Port ([int]$nudPort.Value)

        if ($rows -gt 0) {
            $lblApiStatus.ForeColor = [System.Drawing.Color]::DarkGreen
            $lblApiStatus.Text = "Settings saved successfully ($rows row(s) updated)."
        } else {
            $lblApiStatus.ForeColor = [System.Drawing.Color]::DarkOrange
            $lblApiStatus.Text = "Warning: UPDATE returned 0 rows affected.`nThe Global table may be empty."
        }

    } catch {
        $lblApiStatus.ForeColor = [System.Drawing.Color]::Red
        $lblApiStatus.Text = "Save failed: $($_.Exception.Message)"
        if (Get-Command -Name Write-BepozLogError -ErrorAction SilentlyContinue) {
            Write-BepozLogError -Message "Save failed" -Exception $_.Exception
        }
    }
})

# Reload button handler
$btnReload.Add_Click({
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User clicked Reload button"
    }
    Load-ApiSettings
})

# Firewall button handler
$btnFirewall.Add_Click({
    $port = [int]$nudPort.Value

    if ($port -lt 1 -or $port -gt 65535) {
        $lblFwResult.ForeColor = [System.Drawing.Color]::Red
        $lblFwResult.Text = 'Set a valid port (1-65535) on the Web API tab first.'
        return
    }

    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User initiated firewall rule creation/update for port $port"
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Create/update firewall rule '$($script:FirewallRuleName)'?`n`nProtocol: TCP`nPort: $port`nProfiles: Domain + Private`n`nThis requires administrator privileges.",
        'Confirm Firewall Change',
        'YesNo', 'Question')

    if ($confirm -ne 'Yes') {
        if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
            Write-BepozLogAction "User cancelled firewall rule operation"
        }
        return
    }

    $lblFwResult.ForeColor = [System.Drawing.Color]::Gray
    $lblFwResult.Text = 'Applying firewall rule...'
    $form.Refresh()

    $result = Ensure-FirewallRule -Port $port

    if ($result.Success) {
        $lblFwResult.ForeColor = [System.Drawing.Color]::DarkGreen
        $lblFwResult.Text = "$($result.Action): $($result.Message)"
    } else {
        $lblFwResult.ForeColor = [System.Drawing.Color]::Red
        $lblFwResult.Text = $result.Message

        if ($result.Message -match 'Access is denied|not recognized|permission') {
            $lblFwResult.Text += "`n`nTip: Run this tool as Administrator to modify firewall rules."
        }
    }

    # Refresh status display
    Update-FirewallStatusDisplay
})

# Refresh firewall status handler
$btnRefreshFw.Add_Click({
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "User refreshed firewall status"
    }
    Update-FirewallStatusDisplay
})

#endregion

#region Form Load

$form.Add_Shown({
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "GUI opened"
    }

    # Load API settings from database
    Load-ApiSettings

    # Load firewall status
    Update-FirewallStatusDisplay
})

$form.Add_FormClosed({
    if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
        Write-BepozLogAction "Tool closed"
    }
})

#endregion

#region Launch

if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    Write-BepozLogAction "Displaying GUI to user"
}

[void]$form.ShowDialog()
$form.Dispose()

#endregion
