# Documentation Links Feature

**Added:** 2026-02-11
**Version:** Bootstrap v1.1.0

---

## Overview

The Bepoz Toolkit GUI now supports **integrated documentation links** for each tool. Users can click the "📚 View Documentation" button to instantly access tool-specific guides, wikis, or help files.

---

## Features

### 1. Documentation Button in GUI

- **Location:** Details panel, below tool description
- **Color:** Blue (#2196F3)
- **State:**
  - Enabled when selected tool has documentation
  - Disabled when no tool selected or no docs available
  - Shows "📚 Documentation Available" indicator in tool details

### 2. Supported Documentation Types

| Type | Example | Behavior |
|------|---------|----------|
| **GitHub Wiki** | `https://github.com/user/repo/wiki/ToolName` | Opens in default browser |
| **External URL** | `https://docs.company.com/tools/tool-guide.html` | Opens in default browser |
| **Local File** | `C:\Docs\ToolGuide.pdf` | Opens with default application |
| **Network Share** | `\\server\share\docs\ToolGuide.docx` | Opens with default application |

### 3. User Experience

**When documentation exists:**
1. Select tool from list
2. Tool details show "📚 Documentation Available"
3. "📚 View Documentation" button becomes enabled (blue)
4. Click button → Documentation opens in browser/application

**When documentation doesn't exist:**
- "📚 View Documentation" button remains disabled (gray)
- No documentation indicator shown in details

---

## Adding Documentation to Tools

### Step 1: Update manifest.json

Add a `documentation` field to your tool entry:

```json
{
  "id": "weekschedule-bulk-manager",
  "name": "WeekSchedule Bulk Manager",
  "category": "scheduling",
  "file": "tools/BepozWeekScheduleBulkManager.ps1",
  "description": "GUI tool for bulk WeekSchedule operations",
  "version": "2.0.0",
  "requiresAdmin": false,
  "requiresDatabase": true,
  "author": "Bepoz Administration Team",
  "documentation": "https://github.com/StephenShawBepoz/bepoz-toolkit/wiki/WeekSchedule-Bulk-Manager"
}
```

### Step 2: Choose Documentation Location

#### Option A: GitHub Wiki (Recommended)

**Pros:**
- ✅ Version controlled with repository
- ✅ Markdown formatting
- ✅ Easy editing via GitHub web interface
- ✅ Always accessible (no VPN needed)
- ✅ Free hosting

**How to create:**
1. Go to your GitHub repository
2. Click "Wiki" tab
3. Click "Create the first page"
4. Name page: `WeekSchedule-Bulk-Manager`
5. Add documentation content
6. URL format: `https://github.com/USERNAME/REPO/wiki/PAGE-NAME`

**Example:**
```json
"documentation": "https://github.com/StephenShawBepoz/bepoz-toolkit/wiki/WeekSchedule-Bulk-Manager"
```

#### Option B: External Documentation Site

If you have an existing documentation portal:

```json
"documentation": "https://docs.bepoz.com/support/tools/weekschedule-manager"
```

#### Option C: Local/Network File

For PDF guides or Word documents on network shares:

```json
"documentation": "\\\\bepoz-fileserver\\Support\\Docs\\WeekSchedule-Tool-Guide.pdf"
```

**Note:** Use double backslashes (`\\\\`) in JSON for Windows UNC paths.

#### Option D: Local Repository File

For markdown files in the repository:

```json
"documentation": "https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/docs/WeekSchedule-Guide.md"
```

---

## Documentation Content Recommendations

### What to Include in Tool Documentation

1. **Quick Start**
   - What the tool does (1-2 sentences)
   - When to use it
   - Prerequisites (database access, admin rights, etc.)

2. **Step-by-Step Guide**
   - Numbered steps with screenshots
   - Common workflows
   - Best practices

3. **Troubleshooting**
   - Common errors and solutions
   - What to check if tool fails
   - How to verify results

4. **Examples**
   - Real-world scenarios
   - Before/after screenshots
   - Sample data

5. **FAQ**
   - Frequently asked questions
   - Tips and tricks
   - Performance considerations

### Example Tool Documentation Template

```markdown
# WeekSchedule Bulk Manager

## What It Does
Bulk insert, update, or delete WeekSchedule records across multiple workstations in a single operation.

## When to Use
- Setting up new venue with multiple workstations
- Changing KeySet assignments across all POS terminals
- Cleaning up old schedule entries

## Prerequisites
- ✅ Database access (reads from HKCU registry)
- ✅ Run via Bepoz Toolkit
- ⚠️ Does NOT require administrator rights

---

## Quick Start

1. **Launch Tool**
   - Open Bepoz Toolkit (GUI or CLI)
   - Navigate to "Scheduling" category
   - Select "WeekSchedule Bulk Manager"
   - Click "Run Tool"

2. **Select Venue**
   - Choose venue from dropdown
   - Tool loads workstations for that venue

3. **Apply Operation**
   - Check workstations to modify
   - Select days of week
   - Choose KeySet
   - Click "Apply"
   - Confirm operation

---

## Step-by-Step: Bulk Insert Example

**Scenario:** New venue with 8 POS workstations needs WeekSchedule entries for all days.

### Step 1: Select Venue
![Screenshot: Venue dropdown](images/step1-venue.png)

1. Click venue dropdown
2. Select "Main Bar (ID: 1)"
3. Workstations list populates automatically

### Step 2: Select Workstations
![Screenshot: Workstation selection](images/step2-workstations.png)

1. Click "Check All" button
2. OR manually check desired workstations
3. Count shown: "8 selected"

### Step 3: Configure Days
![Screenshot: Day selection](images/step3-days.png)

1. Click "Check All Days" button
2. All 7 days selected (Sunday-Saturday)

### Step 4: Choose KeySet
![Screenshot: KeySet dropdown](images/step4-keyset.png)

1. Select "POS Operators" from dropdown
2. KeySet ID shown in parentheses

### Step 5: Apply
![Screenshot: Apply confirmation](images/step5-confirm.png)

1. Click "Apply" button
2. Review confirmation dialog:
   - 8 workstations
   - 7 days
   - 56 total operations
3. Click "Yes" to proceed

### Step 6: Review Results
![Screenshot: Completion](images/step6-complete.png)

- Inserted: 56 records
- Updated: 0 records
- Errors: 0

**Log File:** `C:\Bepoz\Toolkit\Logs\BepozWeekScheduleBulkManager_YYYYMMDD.log`

---

## Troubleshooting

### Tool Exits with Code 1

**Cause:** Missing BepozDbCore module or database connection failure

**Solution:**
1. Ensure you're running tool via Toolkit (not directly)
2. Check HKCU:\SOFTWARE\Backoffice registry keys exist
3. Verify SQL Server instance is running
4. Check Windows user has database access

### No Workstations Showing

**Cause:** No workstations configured for selected venue in database

**Solution:**
1. Verify venue has workstations in Bepoz Backoffice
2. Check Workstation table: `SELECT * FROM Workstation WHERE VenueID = X`
3. Configure workstations in Backoffice first

### "Duplicate Key" Error

**Cause:** WeekSchedule record already exists for that WorkstationID/Day combination

**Solution:**
1. Use "Delete" button first to remove existing records
2. Then use "Apply" to insert new ones
3. OR: Modify existing records in Backoffice instead

---

## FAQ

**Q: Can I undo a bulk operation?**
A: No automatic undo. Use "Delete" button to remove records, or restore database backup.

**Q: What happens to existing records?**
A: Apply button INSERTS new records. If record exists (same WorkstationID + Day), you'll get duplicate key error. Delete first, then apply.

**Q: How do I change existing records?**
A: Tool doesn't UPDATE. Delete existing records, then Apply new ones.

**Q: Where are logs stored?**
A: `C:\Bepoz\Toolkit\Logs\BepozWeekScheduleBulkManager_YYYYMMDD.log` (date-stamped daily)

**Q: Can I run this remotely via ScreenConnect?**
A: Yes! Launch toolkit via ScreenConnect, then select this tool.

---

## Related Tools

- **Venue Query Tool** - Verify venue configuration
- **Workstation Setup** - Configure new workstations

## Support

**Issues?** Contact: support@bepoz.com
**Wiki:** https://github.com/StephenShawBepoz/bepoz-toolkit/wiki
```

---

## Benefits

### For Support Teams:
- ✅ **Instant access** - One click to documentation
- ✅ **Context-aware** - Right docs for the tool you're using
- ✅ **No searching** - No need to find guides manually
- ✅ **Always current** - Wiki updates immediately

### For Onboarding:
- ✅ **Self-service** - New team members can learn independently
- ✅ **Consistent training** - Everyone sees same documentation
- ✅ **Visual guides** - Screenshots and examples
- ✅ **Searchable** - GitHub wiki has search function

### For Management:
- ✅ **Knowledge base** - Centralized documentation
- ✅ **Reduced support calls** - Users can self-solve
- ✅ **Onboarding faster** - Less training time needed
- ✅ **Version controlled** - Track documentation changes

---

## Implementation Details

### GUI Changes

**File:** `bootstrap/Invoke-BepozToolkit-GUI.ps1`

**Changes:**
1. Added `$Script:ViewDocsButton` control
2. Added `Open-ToolDocumentation` function
3. Updated `Update-ToolDetails` to show docs indicator
4. Updated button enable/disable logic

**Layout:**
```
┌─────────────────────────────────────┐
│ Tool Details                        │
├─────────────────────────────────────┤
│                                     │
│ WeekSchedule Bulk Manager v2.0.0   │
│                                     │
│ GUI tool for bulk WeekSchedule...  │
│                                     │
│ Author: Bepoz Team                  │
│ Category: scheduling                │
│ 🗄 Requires Database Access         │
│ 📚 Documentation Available          │ <-- NEW
│                                     │
├─────────────────────────────────────┤
│  📚 View Documentation              │ <-- NEW BUTTON
├─────────────────────────────────────┤
│        Run Tool                     │
└─────────────────────────────────────┘
```

### Manifest Changes

**File:** `manifest.json`

**New field:**
```json
{
  "tools": [
    {
      "id": "tool-id",
      "name": "Tool Name",
      "category": "category-id",
      "file": "tools/ToolName.ps1",
      "description": "...",
      "version": "1.0.0",
      "requiresAdmin": false,
      "requiresDatabase": true,
      "author": "...",
      "documentation": "https://..." // <-- NEW FIELD (optional)
    }
  ]
}
```

**Field is optional** - Tools without documentation work normally (button just stays disabled).

---

## Testing Checklist

- [ ] Tool with documentation shows "📚 Documentation Available"
- [ ] View Docs button enabled for tools with docs
- [ ] View Docs button disabled for tools without docs
- [ ] View Docs button disabled when no tool selected
- [ ] Clicking button opens GitHub wiki in browser
- [ ] Clicking button opens local PDF with default app
- [ ] Error message shown for broken/missing links
- [ ] Status label updates when opening docs
- [ ] Button works correctly after switching between tools

---

## Rollout Plan

### Phase 1: Create Wiki Structure
1. Create GitHub wiki for repository
2. Create home page with toolkit overview
3. Create template page for tool documentation

### Phase 2: Document Existing Tools
1. WeekSchedule Bulk Manager (priority 1)
2. User Management Tool
3. EFTPOS Setup
4. Additional tools as needed

### Phase 3: Update Manifest
1. Add `documentation` field to tools with wikis
2. Test in GUI
3. Push to GitHub

### Phase 4: Announce to Teams
1. Update ScreenConnect launcher scripts
2. Notify support teams of new feature
3. Create training material for writing tool docs

---

## Future Enhancements

### Possible Additions:
- 📹 **Video tutorials** - Link to video walkthroughs
- 💬 **Built-in help** - Show docs in sidebar panel
- 🔍 **Search docs** - Search across all tool documentation
- 📝 **Changelog** - Link to tool version history
- ❓ **Context help** - F1 key to open docs for current tool

---

## Summary

The documentation links feature provides:
- **One-click access** to tool guides
- **Support for URLs and files** (GitHub wiki, PDFs, network shares)
- **Seamless integration** with existing toolkit GUI
- **Easy maintenance** via GitHub wiki

**Status:** ✅ **Complete and ready for deployment**

**Files Modified:**
1. `bootstrap/Invoke-BepozToolkit-GUI.ps1` - Added View Docs button and function
2. `manifest.json` - Added documentation field to WeekSchedule tool

**Next Steps:**
1. Upload updated files to GitHub
2. Create GitHub wiki pages for tools
3. Test feature with real documentation links

---

**Updated by:** Claude (Bepoz Toolkit Builder)
**Date:** 2026-02-11
**Bootstrap Version:** 1.1.0 (adds documentation feature)
