# BepozTheme Quick Reference Card

**One-page cheat sheet for BepozTheme.ps1 v1.0.0**

---

## Load Module

```powershell
$themeModule = Get-ChildItem -Path $env:TEMP -Filter "BepozTheme.ps1" -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($themeModule) { . $themeModule.FullName }
```

---

## Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| **Primary** | #002D6A | Title bars, selected items |
| **DarkBlue** | #001432 | Panel headers |
| **Purple** | #673AB6 | Info/docs buttons |
| **Gray** | #808080 | Neutral buttons, borders |
| **LightBlue** | #8AA8DD | Hover states |
| **Green** | #0A7C48 | Success actions (Run, Apply) |
| **BrightPurple** | #9C27B0 | Special accents |

---

## Buttons

```powershell
# Success (Green) - Primary actions
$btnRun = New-BepozButton -Text "Run Tool" -Type Success -Location (10, 50) -Size (150, 40)

# Info (Purple) - Documentation
$btnDocs = New-BepozButton -Text "📚 Docs" -Type Info -Location (10, 100) -Size (150, 40)

# Neutral (Gray) - Standard actions
$btnClose = New-BepozButton -Text "Close" -Type Neutral -Location (10, 150) -Size (150, 40)

# Primary (Blue) - Brand actions (rare)
$btnBrand = New-BepozButton -Text "Bepoz" -Type Primary -Location (10, 200) -Size (150, 40)

# Danger (Black) - Destructive actions
$btnDelete = New-BepozButton -Text "Delete" -Type Danger -Location (10, 250) -Size (150, 40)
```

---

## Panels

```powershell
# With header (dark blue bar)
$panel = New-BepozPanel -Location (10, 10) -Size (300, 400) -HeaderText "Categories"

# Without header
$panel = New-BepozPanel -Location (10, 10) -Size (300, 400)

# Group box (Bepoz blue title)
$group = New-BepozGroupBox -Text "Options" -Location (10, 10) -Size (300, 200)
```

---

## Lists

```powershell
# List box
$list = New-BepozListBox -Location (10, 10) -Size (250, 300)

# Checked list box
$checkedList = New-BepozCheckedListBox -Location (10, 10) -Size (250, 300)

# Combo box (dropdown)
$combo = New-BepozComboBox -Location (10, 10) -Size (250, 25)
```

---

## Labels

```powershell
# Header (14pt bold, Bepoz blue)
$title = New-BepozLabel -Text "Tool Configuration" -Location (10, 10) -Type Header

# SubHeader (11pt bold, dark blue)
$subtitle = New-BepozLabel -Text "Select options" -Location (10, 40) -Type SubHeader

# Normal (9pt regular, black)
$label = New-BepozLabel -Text "Venue:" -Location (10, 70) -Type Normal

# Small (8pt regular, gray)
$info = New-BepozLabel -Text "Optional" -Location (10, 95) -Type Small
```

---

## Text Input

```powershell
# Single line
$textBox = New-BepozTextBox -Location (10, 10) -Size (250, 25)

# Multiline
$textBox = New-BepozTextBox -Location (10, 10) -Size (250, 100) -Multiline

# Read-only
$textBox = New-BepozTextBox -Location (10, 10) -Size (250, 25) -ReadOnly
```

---

## Data Grid

```powershell
# Bepoz-styled grid (blue header, alternating rows)
$grid = New-BepozDataGridView -Location (10, 10) -Size (500, 300) -ReadOnly $true
$grid.DataSource = $dataTable
```

---

## Forms

```powershell
# New themed form
$form = New-BepozForm -Title "My Tool" -Size (800, 600) -ShowBrand
# Shows as: "Bepoz - My Tool"

# Apply theme to existing form
$form = New-Object System.Windows.Forms.Form
Apply-BepozFormTheme -Form $form -ShowBrand
```

---

## Get Colors Directly

```powershell
# Get color object
$blue = Get-BepozColor -Name Primary
$label.ForeColor = $blue

# Get color with transparency
$panel.BackColor = Get-BepozColorWithAlpha -Name LightBlue -Alpha 50

# Get font
$label.Font = Get-BepozFont -Size 12 -Style Bold
```

---

## Button Type Decision

| You Want | Use Type | Color |
|----------|----------|-------|
| Run/Execute | `Success` | Green |
| Save/Apply | `Success` | Green |
| View Docs | `Info` | Purple |
| Help/Info | `Info` | Purple |
| Refresh/Browse | `Neutral` | Gray |
| Cancel/Close | `Neutral` | Gray |
| Delete/Remove | `Danger` | Black |

---

## Complete Example

```powershell
# Load
Add-Type -AssemblyName System.Windows.Forms
. .\BepozTheme.ps1

# Create form
$form = New-BepozForm -Title "Sample" -Size (400, 300) -ShowBrand

# Add panel
$panel = New-BepozPanel -Location (10, 10) -Size (370, 200) -HeaderText "Settings"

# Add label
$lbl = New-BepozLabel -Text "Venue:" -Location (10, 40) -Type Normal
$panel.Controls.Add($lbl)

# Add combo box
$cmb = New-BepozComboBox -Location (10, 65) -Size (340, 25)
$cmb.Items.AddRange(@("Venue 1", "Venue 2"))
$panel.Controls.Add($cmb)

# Add buttons
$btnRun = New-BepozButton -Text "Run" -Type Success -Location (10, 120) -Size (165, 40)
$btnClose = New-BepozButton -Text "Close" -Type Neutral -Location (185, 120) -Size (165, 40)
$btnClose.Add_Click({ $form.Close() })
$panel.Controls.AddRange(@($btnRun, $btnClose))

$form.Controls.Add($panel)

# Show
[void]$form.ShowDialog()
```

---

## Export Color Palette

```powershell
# To console
Export-BepozColorPalette

# To file
Export-BepozColorPalette -OutputPath "C:\Docs\BepozColors.txt"
```

---

**For full documentation:** See `BEPOZ_THEME_GUIDE.md`
