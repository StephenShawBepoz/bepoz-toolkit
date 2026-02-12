# Search & Filter User Guide

**Feature:** Real-time tool search and filtering
**Version:** 1.4.0+
**Updated:** 2026-02-12

---

## Quick Reference

| Feature | How to Use | Shortcut |
|---------|-----------|----------|
| **Search** | Type in search box | `Ctrl+F` |
| **Filter** | Check requirement boxes | N/A |
| **Clear** | Click "Clear" button | `Escape` |
| **Run Tool** | Click "Run Tool" button | `Ctrl+R` |
| **Refresh** | Click "Refresh" button | `F5` |

---

## GUI Layout (v1.4.0)

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ Bepoz Toolkit v1.4.0                                                          │
├───────────────┬──────────────────────┬──────────────────────────────────────────┤
│               │                      │                                          │
│  CATEGORIES   │      TOOLS           │       TOOL DETAILS                       │
│               │                      │                                          │
│               │  Tools    3 of 5 ←── │  WeekSchedule Bulk Manager v2.0.0        │
│  Scheduling   │  ┌────────────────┐  │                                          │
│  SmartPOS     │  │Search: [week__]│  │  GUI tool for bulk insertion/update/     │
│  Kiosk        │  │          Clear │  │  deletion of WeekSchedule records        │
│  TSPlus       │  └────────────────┘  │  across multiple workstations            │
│  Database     │  Filters:            │                                          │
│  Workstation  │  ☑ Admin             │  Author: Bepoz Administration Team       │
│               │  ☑ Database          │  Category: scheduling                    │
│               │  ☐ Basic             │                                          │
│               │  ┌────────────────┐  │  [DB] Requires Database Access           │
│               │  │                │  │  [📚 Docs] Documentation Available       │
│               │  │ WeekSchedule   │  │                                          │
│               │  │ Bulk Manager   │←─┼─────────────────────────────────────────│
│               │  │                │  │                                          │
│               │  │                │  │  [📚 View Documentation]  (purple)       │
│               │  │                │  │                                          │
│               │  │                │  │  [▶ Run Tool]  (green, large)            │
│               │  │                │  │                                          │
│               │  └────────────────┘  │                                          │
├───────────────┴──────────────────────┴──────────────────────────────────────────┤
│ Status: Ready         [View Logs] [Refresh] [Close]                            │
└────────────────────────────────────────────────────────────────────────────────┘

Color Scheme:
 Purple (#673AB6) - View Documentation, View Logs
 Green (#0A7C48)  - Run Tool
 Gray (#808080)   - Clear, Refresh, Close
 Light Blue (#8AA8DD) - All hover states
```

---

## Using Search

### Basic Search

1. **Select a category** (e.g., "Scheduling")
2. **Click in search box** or press `Ctrl+F`
3. **Type your search term** (e.g., "week")
4. **Tools filter in real-time** as you type

### What Search Looks For

Search is **case-insensitive** and searches both:
- ✅ **Tool name** - e.g., "WeekSchedule Bulk Manager"
- ✅ **Tool description** - e.g., "GUI tool for bulk insertion..."

### Search Examples

| Search Term | Finds |
|-------------|-------|
| `week` | WeekSchedule Bulk Manager |
| `schedule` | Any tool with "schedule" in name/description |
| `bulk` | Tools mentioning bulk operations |
| `gui` | Tools with GUI interfaces |
| `eftpos` | EFTPOS-related tools |

### Search Tips

- **Partial matches work** - "sched" finds "schedule"
- **Single word is best** - "week" better than "week schedule"
- **Check spelling** - Typos won't match (no fuzzy search yet)
- **Use tool count** - "0 tools" means no matches

---

## Using Filters

### Filter Types

**Admin** (☑)
- Shows tools that **require administrator privileges**
- Look for `[!] Requires Administrator` in tool details

**Database** (☑)
- Shows tools that **require database access**
- Look for `[DB] Requires Database Access` in tool details

**Basic** (☑)
- Shows tools with **no special requirements**
- Standard tools that any user can run

### Combining Filters

**Multiple filters use OR logic:**
- ☑ Admin + ☑ Database = Tools that are Admin OR Database
- ☑ Admin + ☑ Basic = Tools that are Admin OR Basic
- All three checked = Shows all tools (no filtering)

### Filter Examples

**Scenario 1: Find Database Tools**
```
1. Select category
2. Check "Database" box
3. See only tools needing database access
```

**Scenario 2: Find Simple Tools**
```
1. Select category
2. Check "Basic" box
3. See only tools with no special requirements
```

**Scenario 3: Find Admin or Database Tools**
```
1. Select category
2. Check "Admin" AND "Database"
3. See tools needing either (or both)
```

---

## Combining Search + Filters

**Search and filters work together!**

### Example: Find Admin Tools About Venues

```
1. Select "Workstation Setup" category
2. Type "venue" in search box
3. Check "Admin" filter
4. Result: Admin-only tools dealing with venues
```

### Example: Find Basic Schedule Tools

```
1. Select "Scheduling" category
2. Type "schedule" in search box
3. Check "Basic" filter
4. Result: Simple scheduling tools (no admin/database needed)
```

---

## Tool Count Display

**Location:** Top-right of Tools panel

### What It Shows

**No filters active:**
```
5 tools
```
Shows total number of tools in category.

**Filters active:**
```
3 of 5 tools
```
Shows:
- `3` = Number of tools matching filters
- `5` = Total tools in category

**No matches:**
```
0 of 5 tools
```
No tools match your search/filters. Try:
- Different search term
- Clear filters
- Check spelling

---

## Clearing Filters

### Method 1: Clear Button
1. Click the **"Clear"** button (gray, top-right of search box)
2. All search text and filters reset
3. All tools in category shown again

### Method 2: Escape Key
1. Press **`Escape`** key
2. If search box has focus: Clears search box only
3. If search box does NOT have focus: Clears everything

### Method 3: Manual
1. Delete text from search box
2. Uncheck all filter boxes
3. Tools gradually reappear as you clear

---

## Keyboard Shortcuts

### Available Shortcuts

| Shortcut | Action | When |
|----------|--------|------|
| `Ctrl+F` | Focus search box | Anytime |
| `Ctrl+R` | Run selected tool | Tool selected |
| `F5` | Refresh from GitHub | Anytime |
| `Escape` | Clear search/filters | Anytime |

### Using Ctrl+F

**Quick search workflow:**
```
1. Press Ctrl+F
2. Search box gains focus
3. Any existing text is selected (type to replace)
4. Start typing your search term
```

### Using Ctrl+R

**Quick run workflow:**
```
1. Select a tool from the list
2. Press Ctrl+R
3. Confirmation dialog appears
4. Click "Yes" to run tool
```

**Note:** Only works when a tool is selected (Run button enabled)

### Using F5

**Refresh workflow:**
```
1. Press F5 anywhere in toolkit
2. Downloads latest manifest.json from GitHub
3. Categories and tools refresh
4. Use this after new tools are added to GitHub
```

### Using Escape

**Clear workflow:**
```
1. Press Escape anywhere in toolkit
2. Search box clears
3. All filter checkboxes uncheck
4. All tools in category reappear
```

---

## Workflow Examples

### Example 1: Power User - Find and Run

```
Goal: Find and run WeekSchedule tool quickly

Steps:
1. Launch toolkit
2. Select "Scheduling" category
3. Press Ctrl+F (focus search)
4. Type "week"
5. Tool appears in list
6. Click tool or press Enter
7. Press Ctrl+R (run tool)
8. Confirm and execute
```

**Time:** ~10 seconds

---

### Example 2: Browse Database Tools

```
Goal: See what database tools are available

Steps:
1. Launch toolkit
2. Select any category (or browse all)
3. Check "Database" filter
4. Browse filtered list
5. Click tool for details
6. Click "View Documentation" if needed
7. Click "Run Tool" when ready
```

---

### Example 3: Search Across Description

```
Goal: Find tools that work with EFTPOS

Steps:
1. Launch toolkit
2. Select "SmartPOS Mobile" category
3. Type "eftpos" in search
4. See tools with "EFTPOS" in name or description
5. Select desired tool
```

**Note:** Search looks in descriptions, not just names!

---

### Example 4: Filter Then Refine

```
Goal: Find a specific admin tool

Steps:
1. Select category
2. Check "Admin" filter (narrows to admin tools)
3. Type search term (narrows further)
4. Result: Admin tools matching search
```

---

## Troubleshooting

### No Tools Showing (0 of X tools)

**Problem:** Filters are too restrictive

**Solution:**
1. Click "Clear" button
2. Try broader search term
3. Remove some filter checkboxes

---

### Tool Count Not Updating

**Problem:** Search/filters applied but count unchanged

**Solution:**
1. Click different category, then back
2. Press F5 to refresh manifest
3. Restart toolkit if persistent

---

### Search Not Finding Tool

**Problem:** You know tool exists but search doesn't find it

**Possible Causes:**
1. **Typo** - Check spelling of search term
2. **Wrong category** - Tool might be in different category
3. **Not in manifest** - Tool may not be published to GitHub yet

**Solution:**
1. Browse manually through categories
2. Check manifest.json on GitHub
3. Clear search and browse visually

---

### Keyboard Shortcut Not Working

**Problem:** Ctrl+F or Ctrl+R doesn't respond

**Possible Causes:**
1. Another application has focus
2. Toolkit window not active
3. Conflict with Windows/application shortcut

**Solution:**
1. Click anywhere in toolkit window first
2. Try shortcut again
3. Use mouse as alternative

---

## Best Practices

### For Finding Tools Quickly
1. ✅ **Use Ctrl+F** - Faster than clicking search box
2. ✅ **Type partial words** - "sched" finds "schedule"
3. ✅ **Check filters** - Narrow by requirements first
4. ✅ **Clear between searches** - Press Escape, start fresh

### For Browsing Tools
1. ✅ **Use filters** - See tools by type
2. ✅ **Read descriptions** - Search matches descriptions too
3. ✅ **Check tool count** - Know how many tools match
4. ✅ **View documentation** - Learn before running

### For Power Users
1. ✅ **Learn shortcuts** - Ctrl+F, Ctrl+R, F5, Escape
2. ✅ **Combine search + filters** - Maximum precision
3. ✅ **Use Clear button** - One-click reset
4. ✅ **Double-click to run** - Skip "Run Tool" button

---

## Tips & Tricks

### Speed Tips
- **Ctrl+F → type → Enter → Ctrl+R** = Run tool in 4 keystrokes
- **Double-click tool** = Opens confirmation dialog (no Run button needed)
- **Press Escape** = Instant filter reset

### Discovery Tips
- **Browse with "Basic" filter** = See simple tools first
- **Check "Database"** = See what requires database access
- **Search "bulk"** = Find batch operation tools
- **Search "setup"** = Find configuration tools

### Organization Tips
- **By requirement** = Filter by Admin/Database/Basic
- **By name** = Search for specific tool names
- **By function** = Search descriptions for keywords

---

## Video Walkthrough (Future)

*Coming soon: Video demonstration of search and filter features*

---

## Feedback

**Have suggestions for search/filter improvements?**

Contact: Bepoz Support Team

**Ideas we're considering:**
- Fuzzy search (typo tolerance)
- Recent searches dropdown
- Saved filter presets
- Favorite tools
- Cross-category search
- Advanced search (regex, author, version)

---

**Updated:** 2026-02-12
**Version:** 1.4.0
**Author:** Bepoz Administration Team
