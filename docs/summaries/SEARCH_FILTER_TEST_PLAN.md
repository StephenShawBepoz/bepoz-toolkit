# Search & Filter Test Plan

**Feature:** Search and filter functionality
**Version:** 1.4.0
**Test Date:** 2026-02-12

---

## Pre-Testing Setup

### Upload to GitHub
```bash
cd /Users/stephenshaw/Documents/GitHub/bepoz-toolkit
git add .
git commit -m "Add search and filter functionality (v1.4.0)"
git push origin main
```

### Launch Toolkit
```powershell
# Clear any cached toolkit files
Remove-Item "$env:TEMP\Bepoz*" -Recurse -Force -ErrorAction SilentlyContinue

# Launch GUI toolkit
irm https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit-GUI.ps1 | iex
```

---

## Test Cases

### TEST 1: Search Functionality

**Objective:** Verify search box filters tools in real-time

**Steps:**
1. Launch toolkit
2. Select "Scheduling" category
3. Observe all tools in category
4. Type "week" in search box
5. Observe tool list updates in real-time

**Expected Results:**
- ✅ Search box visible at top of Tools panel
- ✅ Typing filters tools immediately (no delay)
- ✅ Only tools with "week" in name/description shown
- ✅ Tool count updates (e.g., "1 of 5 tools")
- ✅ Case-insensitive ("WEEK" = "week" = "Week")

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 2: Filter Checkboxes

**Objective:** Verify requirement filters work correctly

**Steps:**
1. Launch toolkit
2. Select category with multiple tools
3. Check "Admin" checkbox
4. Observe filtered tools
5. Uncheck "Admin", check "Database"
6. Observe filtered tools
7. Check "Basic"
8. Observe filtered tools

**Expected Results:**
- ✅ "Admin" shows only tools with `requiresAdmin: true`
- ✅ "Database" shows only tools with `requiresDatabase: true`
- ✅ "Basic" shows only tools with neither flag
- ✅ Checking multiple filters shows tools matching ANY filter (OR logic)
- ✅ Tool count updates with each filter change

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 3: Combined Search + Filters

**Objective:** Verify search and filters work together

**Steps:**
1. Launch toolkit
2. Select category with 5+ tools
3. Type search term (e.g., "schedule")
4. Check "Database" filter
5. Observe results

**Expected Results:**
- ✅ Only tools matching BOTH search AND filter shown
- ✅ Tool count shows correct filtered amount
- ✅ Removing search shows all Database tools
- ✅ Removing filter shows all tools matching search

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 4: Clear Filters Button

**Objective:** Verify Clear button resets all filters

**Steps:**
1. Launch toolkit
2. Type search term
3. Check multiple filter boxes
4. Click "Clear" button
5. Observe results

**Expected Results:**
- ✅ Search box clears immediately
- ✅ All checkboxes uncheck
- ✅ All tools in category reappear
- ✅ Tool count returns to total (e.g., "5 tools")
- ✅ Button has gray background, white text
- ✅ Hover shows light blue background

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 5: Tool Count Display

**Objective:** Verify tool count shows correctly

**Steps:**
1. Launch toolkit
2. Select category
3. Note total count (e.g., "5 tools")
4. Apply search to filter to 2 tools
5. Note filtered count (e.g., "2 of 5 tools")
6. Clear filters
7. Note count returns to "5 tools"

**Expected Results:**
- ✅ Shows "X tools" when no filters applied
- ✅ Shows "X of Y tools" when filters reduce count
- ✅ Shows "0 of Y tools" when no matches
- ✅ Gray text, right-aligned
- ✅ Small font (8pt)
- ✅ Updates in real-time

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 6: Keyboard Shortcut - Ctrl+F

**Objective:** Verify Ctrl+F focuses search box

**Steps:**
1. Launch toolkit
2. Click anywhere OUTSIDE search box
3. Press Ctrl+F
4. Observe search box

**Expected Results:**
- ✅ Search box gains focus (cursor appears)
- ✅ Any existing text is selected
- ✅ Typing replaces selected text
- ✅ Works from anywhere in toolkit

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 7: Keyboard Shortcut - Escape

**Objective:** Verify Escape clears filters

**Steps:**
1. Launch toolkit
2. Apply search and filters
3. Click outside search box
4. Press Escape key
5. Observe results

**Expected Results:**
- ✅ Search box clears
- ✅ All checkboxes uncheck
- ✅ All tools reappear
- ✅ Works when search box does NOT have focus

**Alternative Test:**
1. Type in search box
2. Press Escape (while search box has focus)
3. **Expected:** Only search box clears (not filters)

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 8: Keyboard Shortcut - Ctrl+R

**Objective:** Verify Ctrl+R runs selected tool

**Steps:**
1. Launch toolkit
2. Select a category
3. Click on a tool in the list
4. Press Ctrl+R
5. Observe result

**Expected Results:**
- ✅ Confirmation dialog appears
- ✅ Same as clicking "Run Tool" button
- ✅ Only works when tool is selected

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 9: Keyboard Shortcut - F5

**Objective:** Verify F5 refreshes manifest

**Steps:**
1. Launch toolkit
2. Note current categories/tools
3. Press F5 key
4. Observe console/log output

**Expected Results:**
- ✅ Manifest re-downloads from GitHub
- ✅ Categories refresh
- ✅ Tools refresh
- ✅ Log shows "Refreshing manifest..." and "Manifest refreshed"
- ✅ Current filters remain applied after refresh

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 10: No Matches Scenario

**Objective:** Verify behavior when no tools match filters

**Steps:**
1. Launch toolkit
2. Select category
3. Type search term that matches nothing (e.g., "zzzzz")
4. Observe results

**Expected Results:**
- ✅ Tool list shows empty
- ✅ Tool count shows "0 of X tools"
- ✅ Tool details shows "No tools match the current filters"
- ✅ Run button disabled
- ✅ Clear button still works

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 11: UI Layout Verification

**Objective:** Verify new UI elements render correctly

**Steps:**
1. Launch toolkit
2. Examine Tools panel visually

**Expected Results:**
- ✅ Search box: Top-left, "Search:" label, textbox, "Clear" button aligned
- ✅ Filters: "Filters:" label with 3 checkboxes (Admin, Database, Basic)
- ✅ Tool count: Top-right, gray text, small font
- ✅ Tool list: Starts below filters, takes remaining vertical space
- ✅ No overlapping controls
- ✅ All text readable

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 12: Bepoz Theme Compliance

**Objective:** Verify new controls follow Bepoz color palette

**Steps:**
1. Launch toolkit
2. Examine "Clear" button colors
3. Hover over "Clear" button

**Expected Results:**
- ✅ Clear button background: Gray (#808080)
- ✅ Clear button text: White
- ✅ Clear button hover: Light Blue (#8AA8DD)
- ✅ Flat style, no borders
- ✅ Cursor changes to hand on hover
- ✅ Consistent with other buttons (Refresh, Close)

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 13: Empty Category

**Objective:** Verify behavior in category with no tools

**Steps:**
1. Launch toolkit
2. Select category with 0 tools (if any)
3. Try search and filters

**Expected Results:**
- ✅ Tool count shows "0 tools"
- ✅ Message: "No tools available in this category yet"
- ✅ Search box and filters still functional (but no effect)
- ✅ No errors in log

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 14: Auto-Update from v1.3.0

**Objective:** Verify auto-update mechanism works

**Prerequisites:**
- Old version (v1.3.0) still on local machine
- New version (v1.4.0) uploaded to GitHub

**Steps:**
1. Launch old toolkit (v1.3.0)
2. Wait for update check
3. Observe update prompt
4. Click "Yes" to update
5. Observe new version launches

**Expected Results:**
- ✅ Prompt: "Update available v1.3.0 → v1.4.0"
- ✅ New version downloads
- ✅ Toolkit relaunches with v1.4.0
- ✅ Search box and filters appear
- ✅ All new functionality works

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 15: Logging Verification

**Objective:** Verify new features are logged

**Steps:**
1. Launch toolkit
2. Type in search box
3. Check filter boxes
4. Press Ctrl+F
5. Click Clear button
6. Press Escape
7. Click "View Logs" button
8. Examine log file

**Expected Results:**
- ✅ Log shows "Search focused (Ctrl+F)"
- ✅ Log shows "Filters cleared" when Clear clicked
- ✅ Log shows "Filters cleared (Escape)" when Escape pressed
- ✅ All events timestamped
- ✅ No errors in log

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

## Performance Tests

### TEST 16: Search Performance

**Objective:** Verify search is instant even with many tools

**Setup:**
- Category with 10+ tools (or add more tools to manifest for testing)

**Steps:**
1. Select category
2. Type search term character by character
3. Observe response time

**Expected Results:**
- ✅ Filtering happens in real-time (< 100ms)
- ✅ No lag or delay when typing
- ✅ Smooth user experience

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 17: Filter Toggle Performance

**Objective:** Verify filter checkboxes respond instantly

**Steps:**
1. Select category with multiple tools
2. Rapidly check/uncheck filter boxes
3. Observe tool list updates

**Expected Results:**
- ✅ Tool list updates immediately
- ✅ No lag between checkbox click and filter
- ✅ No visual glitches

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

## Edge Cases

### TEST 18: Special Characters in Search

**Objective:** Verify search handles special characters

**Steps:**
1. Create tool with special chars in name (if needed)
2. Search for special characters: `@ # $ % & * ( )`
3. Observe results

**Expected Results:**
- ✅ No errors
- ✅ Matches tools with those characters
- ✅ Wildcards don't break search

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 19: Very Long Search Term

**Objective:** Verify search box handles long input

**Steps:**
1. Launch toolkit
2. Type very long search term (100+ characters)
3. Observe behavior

**Expected Results:**
- ✅ Search box scrolls horizontally
- ✅ No UI breaking
- ✅ Search still functions
- ✅ Clear button still works

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

### TEST 20: Rapid Category Switching

**Objective:** Verify filters persist/reset correctly when switching categories

**Steps:**
1. Select Category A
2. Apply search and filters
3. Switch to Category B
4. Observe filters
5. Switch back to Category A
6. Observe filters

**Expected Results:**
- ✅ Filters apply to new category (persist)
- ✅ Search persists across categories
- ✅ Tool count updates for each category
- ✅ No errors or glitches

**Status:** ⬜ Pass | ⬜ Fail

**Notes:**
```


```

---

## Test Summary

**Total Tests:** 20
**Passed:** ___
**Failed:** ___
**Blocked:** ___
**Not Run:** ___

---

## Critical Issues Found

| Test # | Issue | Severity | Status |
|--------|-------|----------|--------|
| | | | |

---

## Non-Critical Issues Found

| Test # | Issue | Priority | Status |
|--------|-------|----------|--------|
| | | | |

---

## Sign-Off

**Tester Name:** _______________________
**Date Tested:** _______________________
**Build Version:** 1.4.0
**Status:** ⬜ Approved for Production | ⬜ Needs Fixes

**Notes:**
```



```

---

## Deployment Checklist

After all tests pass:

- [ ] All tests passed
- [ ] No critical issues
- [ ] Non-critical issues documented
- [ ] Code committed to GitHub
- [ ] Manifest.json version updated
- [ ] README.md updated
- [ ] User guide created
- [ ] Support team notified
- [ ] ScreenConnect scripts updated (if needed)

**Ready for Production:** ⬜ Yes | ⬜ No

---

**Test Plan Version:** 1.0
**Created:** 2026-02-12
**Last Updated:** 2026-02-12
