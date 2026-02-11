# Handoff to Claude Code - Bepoz Toolkit

**Date:** 2026-02-11
**Status:** Ready for Claude Code Migration

---

## Overview

This folder contains the complete **Bepoz Toolkit** - a PowerShell-based tool distribution system with:
- ✅ Official Bepoz brand theming
- ✅ Centralized logging system
- ✅ Database access modules
- ✅ UI helper libraries
- ✅ Documentation links integration
- ✅ Auto-update mechanism

---

## Folder Organization

### ✅ PRODUCTION FILES (Upload to GitHub)

These are the **core files** that need to be in your GitHub repository:

```
📦 bepoz-toolkit/
├── 📄 manifest.json                              ⭐ CRITICAL - Toolkit catalog
├── 📄 README.md                                  ⭐ Repository documentation
│
├── 📁 bootstrap/
│   ├── Invoke-BepozToolkit.ps1                  ⭐ CLI version
│   └── Invoke-BepozToolkit-GUI.ps1              ⭐ GUI version (v1.2.0 - themed)
│
├── 📁 modules/
│   ├── BepozDbCore.ps1      (v1.3.0)           ⭐ Database access + auto-logging
│   ├── BepozLogger.ps1      (v1.0.0)           ⭐ Centralized logging
│   ├── BepozUI.ps1          (v1.0.0)           ⭐ UI helpers
│   └── BepozTheme.ps1       (v1.0.0)           ⭐ Official Bepoz theme
│
└── 📁 tools/
    ├── Tool-Template.ps1                        ⭐ Template for new tools
    └── BepozWeekScheduleBulkManager.ps1 (v2.0.0) ⭐ Example tool with logging
```

**Total Production Files:** 10 files

---

### 📚 DOCUMENTATION FILES (Keep Local - Optional Upload)

These are **reference/guide documents** created during development:

**Theme Documentation:**
- `BEPOZ_THEME_GUIDE.md` - Complete theme usage guide (25 pages)
- `BEPOZ_THEME_QUICK_REF.md` - Quick reference card (1 page)
- `THEME_COMPLETE_SUMMARY.md` - Theme implementation summary
- `TOOLKIT_GUI_THEME_UPDATE.md` - GUI color changes

**Migration Guides:**
- `SCRIPT_MIGRATION_GUIDE.md` - For Claude Code to migrate tools
- `TOOL_MIGRATION_GUIDE.md` - Original migration guide

**Feature Documentation:**
- `DOCUMENTATION_LINKS_FEATURE.md` - Documentation links feature guide
- `LOGGING_GUIDE.md` - BepozLogger usage guide
- `WEEKSCHEDULE_LOGGING_UPDATE.md` - WeekSchedule logging changes
- `GUI_USER_GUIDE.md` - GUI toolkit user guide

**Session Summaries:**
- `SESSION_SUMMARY.md` - Today's session summary
- `DELIVERY_SUMMARY.md` - Original delivery summary
- `LOGGING_IMPLEMENTATION_SUMMARY.md` - Logging implementation

**Other:**
- `GITHUB_REPO_STRUCTURE.md` - Repository structure guide
- `SCREENCONNECT_DEPLOYMENT.md` - ScreenConnect deployment guide
- `TOOL_REVIEW_BepozWeekScheduleBulkManager.md` - Tool review notes

**Recommendation:**
- **Keep locally** for reference
- **Optional:** Upload to `docs/` folder in GitHub if you want team documentation
- **Don't upload:** Session summaries (internal development notes)

---

### 🛠️ UTILITY FILES (Keep Local)

- `Check-ToolMigration.ps1` - Tool to scan scripts for old DB patterns
- `ScreenConnect-Launch-Toolkit.ps1` - ScreenConnect launcher (CLI)
- `ScreenConnect-Launch-Toolkit-GUI.ps1` - ScreenConnect launcher (GUI)

**Recommendation:** Keep locally or in a separate `utilities/` folder

---

## What Claude Code Needs to Know

### 1. Project Purpose
This is a **PowerShell toolkit distribution system** for Bepoz POS support teams. Tools are:
- Downloaded on-demand from GitHub
- Run via ScreenConnect for remote support
- Themed with official Bepoz colors
- Logged to `C:\Bepoz\Toolkit\Logs\`

### 2. Key Architecture Decisions

**Module Pattern:**
- All modules are **optional** (graceful degradation)
- Loaded from `$env:TEMP` after toolkit downloads them
- Tools check if module exists before using functions

**Color Palette:**
- Official Bepoz colors are **hard-coded** in the toolkit GUI
- BepozTheme module provides **reusable functions** for tools
- Both use the **same official palette**

**Auto-Update:**
- Toolkit checks GitHub for new version on every run
- Prompts user to update if available
- Relaunches with new version automatically

**Database Access:**
- Registry-based discovery (`HKCU:\SOFTWARE\Backoffice`)
- Windows Integrated Security (no passwords)
- All queries auto-logged for troubleshooting

### 3. File Versions (Current State)

| File | Version | Status |
|------|---------|--------|
| manifest.json | 1.2.0 | ✅ Up to date |
| Invoke-BepozToolkit-GUI.ps1 | 1.2.0 | ✅ Themed |
| Invoke-BepozToolkit.ps1 | 1.0.0 | ✅ Stable |
| BepozDbCore.ps1 | 1.3.0 | ✅ Has Get-BepozDbInfo |
| BepozLogger.ps1 | 1.0.0 | ✅ Ready |
| BepozUI.ps1 | 1.0.0 | ✅ Ready |
| BepozTheme.ps1 | 1.0.0 | ✅ NEW |
| BepozWeekScheduleBulkManager.ps1 | 2.0.0 | ✅ Logging added |

### 4. Critical Dependencies

**For toolkit to work, GitHub must have:**
1. ✅ `manifest.json` - Lists all modules and tools
2. ✅ `bootstrap/Invoke-BepozToolkit-GUI.ps1` - GUI launcher
3. ✅ `modules/BepozDbCore.ps1` - Database access (v1.3.0+)
4. ✅ `modules/BepozLogger.ps1` - Logging system
5. ✅ `modules/BepozUI.ps1` - UI helpers
6. ✅ `modules/BepozTheme.ps1` - Theme functions

**Without these, tools will fail!**

### 5. Known Issues to Fix

**None!** Everything is production-ready.

**Minor:**
- View Logs button at bottom renders as two purple bars (cosmetic)
- Could add more example tools to demonstrate modules

---

## Recommended Cleanup Before GitHub Upload

### Option A: Minimal (Upload Everything)
```bash
# Just upload everything as-is
git add .
git commit -m "Complete Bepoz Toolkit with theming, logging, and documentation"
git push origin main
```

**Pros:** Simple, includes all documentation
**Cons:** GitHub repo will have many .md files

### Option B: Organized (Recommended)
```bash
# Create docs folder
mkdir -p docs/guides
mkdir -p docs/migration
mkdir -p docs/summaries

# Move documentation
mv BEPOZ_THEME_*.md docs/guides/
mv SCRIPT_MIGRATION_GUIDE.md docs/migration/
mv LOGGING_GUIDE.md docs/guides/
mv DOCUMENTATION_LINKS_FEATURE.md docs/guides/

# Move session summaries (or delete)
mv SESSION_SUMMARY.md docs/summaries/
mv DELIVERY_SUMMARY.md docs/summaries/
mv TOOLKIT_GUI_THEME_UPDATE.md docs/summaries/

# Upload production files + organized docs
git add manifest.json bootstrap/ modules/ tools/ README.md docs/
git commit -m "Add Bepoz Toolkit v1.2.0 with official theming"
git push origin main
```

**Pros:** Clean, organized, professional
**Cons:** Requires manual reorganization

### Option C: Production Only
```bash
# Upload only production files
git add manifest.json
git add bootstrap/
git add modules/
git add tools/
git add README.md
git commit -m "Add Bepoz Toolkit v1.2.0 - production files"
git push origin main
```

**Pros:** Clean GitHub repo
**Cons:** Loses documentation (keep locally instead)

**My Recommendation:** **Option B** - Organized with docs/ folder

---

## For Claude Code: Common Tasks

### Task 1: Create a New Tool
```
Claude, create a new tool called "VenueSetup.ps1" that:
1. Uses BepozDbCore for database access
2. Uses BepozLogger for logging
3. Uses BepozTheme for UI styling
4. Prompts for venue name and creates basic venue setup

Follow the Tool-Template.ps1 pattern and SCRIPT_MIGRATION_GUIDE.md.
```

### Task 2: Update Existing Tool
```
Claude, update tools/OldTool.ps1 to use the new modules.
Follow SCRIPT_MIGRATION_GUIDE.md to:
1. Replace old DB code with BepozDbCore
2. Add BepozLogger integration
3. Apply BepozTheme if it has a GUI

The tool is in tools/OldTool.ps1. Make it v2.0.0.
```

### Task 3: Add Tool to Manifest
```
Claude, add my new tool "VenueSetup.ps1" to manifest.json:
- Category: database
- Version: 1.0.0
- Requires database access
- Add documentation link to wiki
```

---

## Important Notes for Claude Code

### 1. Module Loading Pattern
**ALWAYS use this pattern in tools:**
```powershell
# Load BepozDbCore (REQUIRED)
$dbCoreModule = Get-ChildItem -Path $env:TEMP -Filter "BepozDbCore.ps1" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $dbCoreModule) {
    Write-Host "ERROR: BepozDbCore module not found" -ForegroundColor Red
    exit 1
}

. $dbCoreModule.FullName
$dbInfo = Get-BepozDbInfo -ApplicationName "ToolName"
$script:ConnectionString = $dbInfo.ConnectionString
```

### 2. Defensive Logging
**ALWAYS check if logger exists:**
```powershell
if (Get-Command -Name Write-BepozLogAction -ErrorAction SilentlyContinue) {
    Write-BepozLogAction "Something happened"
}
```

**Never call logging functions directly without checking!**

### 3. Color Palette Reference
When using BepozTheme, follow **official usage rules:**
- **Primary (#002D6A):** Title bars, selected items only
- **Success (#0A7C48):** Run, Apply, Save buttons
- **Info (#673AB6):** Documentation, View buttons
- **Neutral (#808080):** Cancel, Close, Refresh
- **Hover (#8AA8DD):** All hover states

### 4. Database Queries
**ALWAYS parameterize:**
```powershell
# ✅ CORRECT
$params = @{ VenueID = $venueId }
Invoke-BepozQuery -Query "SELECT * FROM Venue WHERE VenueID = @VenueID" -Parameters $params

# ❌ WRONG
Invoke-BepozQuery -Query "SELECT * FROM Venue WHERE VenueID = $venueId"
```

### 5. Version Numbers
When updating files:
- **Major change** (new features): 1.0.0 → 2.0.0
- **Minor change** (improvements): 1.0.0 → 1.1.0
- **Patch** (bug fixes): 1.0.0 → 1.0.1

**Update both:**
1. Script header comment
2. manifest.json entry

---

## Testing Checklist

After making changes, test:

1. ✅ **Download from GitHub:**
   ```powershell
   Remove-Item "$env:TEMP\Bepoz*" -Recurse -Force -ErrorAction SilentlyContinue
   irm https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit-GUI.ps1 | iex
   ```

2. ✅ **Modules download correctly:**
   - Check `$env:TEMP` for BepozDbCore.ps1, BepozLogger.ps1, etc.

3. ✅ **Tool runs without errors:**
   - Select tool from GUI
   - Click "Run Tool"
   - Check console output

4. ✅ **Logs created:**
   - Check `C:\Bepoz\Toolkit\Logs\`
   - Verify log file exists and has entries

5. ✅ **Colors match Bepoz palette:**
   - Purple docs button (#673AB6)
   - Green run button (#0A7C48)
   - Hover states work (light blue)

---

## Quick Reference

### File Locations
- **Production code:** `bootstrap/`, `modules/`, `tools/`
- **Configuration:** `manifest.json`
- **Documentation:** Root folder (organize to `docs/` if desired)
- **Templates:** `tools/Tool-Template.ps1`

### Key Guides for Claude Code
- **Creating tools:** `SCRIPT_MIGRATION_GUIDE.md`
- **Using theme:** `BEPOZ_THEME_GUIDE.md` or `BEPOZ_THEME_QUICK_REF.md`
- **Using logger:** `LOGGING_GUIDE.md`
- **Module patterns:** `Tool-Template.ps1`

### Color Palette
```
Primary:   #002D6A  RGB(0, 45, 106)    Bepoz Blue
Secondary: #673AB6  RGB(103, 58, 182)  Purple
Secondary: #808080  RGB(128, 128, 128) Gray
Tertiary:  #0A7C48  RGB(10, 124, 72)   Green
Tertiary:  #8AA8DD  RGB(138, 168, 221) Light Blue
```

---

## Status: Ready for Claude Code ✅

**What works:**
- ✅ Toolkit GUI with official Bepoz theming
- ✅ Auto-update mechanism
- ✅ Module downloading from GitHub
- ✅ Centralized logging system
- ✅ Database access with auto-logging
- ✅ UI helper library
- ✅ Theme module with official colors
- ✅ Documentation links feature
- ✅ Complete guides and templates

**What needs work:**
- More example tools demonstrating the modules
- GitHub wiki pages for tool documentation
- Optional: CLI theming (currently only GUI is themed)

**Ready to:**
1. Upload to GitHub
2. Share with support teams
3. Build more tools using the framework
4. Migrate existing scripts to use modules

---

## Final Recommendation

**For Claude Code:**

1. **Read first:**
   - `SCRIPT_MIGRATION_GUIDE.md` (how to create/update tools)
   - `Tool-Template.ps1` (reference implementation)
   - `BEPOZ_THEME_QUICK_REF.md` (color palette)

2. **When creating tools:**
   - Copy `Tool-Template.ps1`
   - Follow module loading patterns exactly
   - Use defensive logging checks
   - Parameterize all SQL queries
   - Apply BepozTheme for GUI tools

3. **When updating manifest:**
   - Add tool entry with all required fields
   - Include documentation link if available
   - Update version numbers

4. **Before committing:**
   - Test tool via toolkit (not directly)
   - Verify logs created
   - Check colors match palette
   - Update version in both script and manifest

---

**You're all set!** The toolkit is production-ready and fully documented. Claude Code has everything needed to maintain and extend it. 🚀

---

**Created by:** Claude (Bepoz Toolkit Builder)
**Date:** 2026-02-11
**Handoff Status:** Complete and Ready
