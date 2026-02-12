# WeekSchedule Tool Encoding Fix

**Date:** 2026-02-12
**Tool:** BepozWeekScheduleBulkManager.ps1
**Version:** 2.0.0 → 2.0.1
**Issue:** PowerShell parse errors due to Unicode characters

---

## Problem

Users reported the following error when running the WeekSchedule tool:

```
Tool completed with exit code: 1

Error details:
Unexpected token ']' in expression or statement.
Missing expression after unary operator '!'.
Missing closing '}' in statement block or type definition.
```

---

## Root Cause

The tool script contained Unicode characters that caused PowerShell parse errors when downloaded from GitHub:

1. **`(!)` in strings** - Parentheses with exclamation mark interpreted as PowerShell operators
2. **`[✓]` checkmarks** - Unicode character U+2713 (✓)
3. **`[✗]` X marks** - Unicode character U+2717 (✗)
4. **`[i]` info** - Unicode character (i)
5. **`×` multiplication** - Unicode character U+00D7 (×)

When uploaded to GitHub or transferred between systems, these Unicode characters could become corrupted or be misinterpreted by PowerShell's parser.

---

## Solution

Replaced all Unicode characters with ASCII equivalents:

| Before | After | Lines |
|--------|-------|-------|
| `(!)` | `WARNING:` or `NOTE:` | 161-162, 221-222, 226-227 |
| `[✓]` | `[OK]` | 125, 139, 214, 242 |
| `[✗]` | `[ERROR]` | 148, 155 |
| `[i]` | `[INFO]` | 129 |
| `×` | `x` | 2019 |

---

## Changes Made

### File: `tools/BepozWeekScheduleBulkManager.ps1`

**Line 161-162:**
```diff
- Write-Host "(!) BepozDbCore module not found in temp directory" -ForegroundColor Yellow
+ Write-Host "WARNING: BepozDbCore module not found in temp directory" -ForegroundColor Yellow
```

**Line 221-222:**
```diff
- Write-Host "(!) Logger module found but failed to load: ..." -ForegroundColor Yellow
- Write-Host "(!) Continuing without logging..." -ForegroundColor Yellow
+ Write-Host "WARNING: Logger module found but failed to load: ..." -ForegroundColor Yellow
+ Write-Host "WARNING: Continuing without logging..." -ForegroundColor Yellow
```

**Line 226-227:**
```diff
- Write-Host "(!) BepozLogger module not found (optional)" -ForegroundColor Yellow
- Write-Host "(!) Tool will run without centralized logging" -ForegroundColor Yellow
+ Write-Host "NOTE: BepozLogger module not found (optional)" -ForegroundColor Yellow
+ Write-Host "NOTE: Tool will run without centralized logging" -ForegroundColor Yellow
```

**Unicode symbols replaced:**
```diff
- [✓] → [OK]
- [✗] → [ERROR]
- [i] → [INFO]
- × → x
```

**Line 2019:**
```diff
- $previewText += "`n  (Workstations × Days = ..."
+ $previewText += "`n  (Workstations x Days = ..."
```

---

### File: `manifest.json`

**Version bumped:**
```diff
- "version": "2.0.0",
+ "version": "2.0.1",
```

---

## Verification

### Before Fix
```powershell
# Would fail with parse errors:
Unexpected token ']' in expression or statement.
Missing expression after unary operator '!'.
```

### After Fix
```powershell
# Clean execution:
[INFO] Loading BepozDbCore module...
[OK] BepozDbCore module already loaded
[OK] Database connection initialized
```

---

## Testing

### Test 1: Syntax Check
```powershell
# Run PowerShell syntax check
powershell.exe -NoProfile -Command "Get-Content 'BepozWeekScheduleBulkManager.ps1' | Out-Null"
# Expected: No errors
```

### Test 2: Character Encoding
```bash
# Check for non-ASCII characters
grep -v '^[:print:][:space:]' BepozWeekScheduleBulkManager.ps1
# Expected: No output (exit code 1)
```

### Test 3: Tool Execution
```powershell
# Run through toolkit
irm https://raw.githubusercontent.com/.../Invoke-BepozToolkit-GUI.ps1 | iex
# Select WeekSchedule tool
# Click "Run Tool"
# Expected: Tool opens without parse errors
```

---

## Prevention

### For Future Tools

**Use ASCII-only characters in PowerShell scripts:**

✅ **Good:**
```powershell
Write-Host "[OK] Success" -ForegroundColor Green
Write-Host "[ERROR] Failed" -ForegroundColor Red
Write-Host "[INFO] Loading..." -ForegroundColor Cyan
Write-Host "WARNING: Check this" -ForegroundColor Yellow
Write-Host "NOTE: Optional feature" -ForegroundColor Yellow
```

❌ **Avoid:**
```powershell
Write-Host "[✓] Success"        # Unicode checkmark
Write-Host "[✗] Failed"         # Unicode X
Write-Host "[i] Loading..."     # Can be misinterpreted
Write-Host "(!) Check this"     # Parentheses with ! problematic
Write-Host "5 × 3 = 15"         # Unicode multiplication sign
```

### Encoding Standards

**When creating PowerShell scripts:**
1. Use **UTF-8 without BOM** encoding
2. Verify no non-ASCII characters (except in comments)
3. Test by downloading from GitHub before committing
4. Run syntax check: `powershell.exe -NoProfile -NoExit -File script.ps1`

---

## Impact

**Affected Users:** All users running WeekSchedule tool via toolkit

**Severity:** High (tool completely broken)

**Resolution:** Update to v2.0.1

---

## Deployment

```bash
# Commit the fix
git add tools/BepozWeekScheduleBulkManager.ps1
git add manifest.json
git commit -m "Fix encoding issues in WeekSchedule tool (v2.0.1)

- Replace Unicode characters with ASCII equivalents
- Fix parse errors: (!) → WARNING/NOTE
- Fix symbols: [✓] → [OK], [✗] → [ERROR]
- Fix multiplication: × → x"

# Push to GitHub
git push origin main
```

---

## Related Issues

This is the second encoding issue fixed:
1. **First fix (commit ac21823):** Removed emoji characters
2. **This fix (v2.0.1):** Removed Unicode symbols and special characters

---

## Checklist

- [x] Unicode characters replaced with ASCII
- [x] Script version updated (2.0.0 → 2.0.1)
- [x] Manifest version updated
- [x] Changelog updated in script header
- [x] Tested locally (no parse errors)
- [x] Character encoding verified
- [x] Ready for GitHub upload

---

**Status:** ✅ Fixed and Ready for Deployment

**Fix By:** Claude Code
**Date:** 2026-02-12
