# Bepoz Toolkit GUI - User Guide

**Windows Forms Interface for Easy Point-and-Click Tool Access**

The GUI version of the Bepoz Toolkit provides a user-friendly graphical interface, perfect for support staff who prefer buttons over command-line menus.

---

## What You Get

### GUI Features

✅ **Point-and-Click Interface** - No typing required, just click
✅ **Visual Category Browser** - See all categories in a list
✅ **Tool Descriptions** - Detailed info before you run
✅ **One-Click Execution** - Click "Run Tool" button to execute
✅ **Progress Indicators** - Visual feedback during downloads
✅ **Auto-Update** - Prompts to update when new version available
✅ **Refresh Button** - Reload manifest without restarting
✅ **Clean UI** - Professional Windows Forms interface

---

## GUI Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ Bepoz Toolkit v1.0.0                                          [─][□][×]│
├───────────────┬────────────────────┬──────────────────────────────────┤
│               │                    │                                  │
│  Categories   │       Tools        │       Tool Details               │
│               │                    │                                  │
│ ┌───────────┐ │ ┌────────────────┐ │  EFTPOS Setup v1.0.0            │
│ │ Scheduling│ │ │ EFTPOS Setup   │ │                                  │
│ │ SmartPOS  │ │ │ Venue Query    │ │  Configure EFTPOS devices       │
│ │ Kiosk     │ │ │ User Tool      │ │  for a workstation              │
│ │ TSPlus    │ │ │                │ │                                  │
│ │ Database  │ │ │                │ │  Author: Bepoz Support Team     │
│ │ Workstation│ │ │                │ │  Category: workstation          │
│ └───────────┘ │ └────────────────┘ │                                  │
│               │                    │  🗄 Requires Database Access     │
│               │                    │                                  │
│               │                    │                                  │
│               │                    │  ┌────────────────────────────┐ │
│               │                    │  │      Run Tool              │ │
│               │                    │  └────────────────────────────┘ │
├───────────────┴────────────────────┴──────────────────────────────────┤
│ Status: Ready                         [Refresh]  [Close]              │
└─────────────────────────────────────────────────────────────────────┘
```

---

## How to Use

### Step 1: Launch the GUI

**From ScreenConnect:**
1. Connect to customer machine
2. Run saved script: **"Bepoz Toolkit (GUI)"**
3. GUI window opens automatically

**Or use one-line command:**
```powershell
irm https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit-GUI.ps1 | iex
```

### Step 2: Select a Category

- **Left panel** shows all categories (Scheduling, SmartPOS Mobile, etc.)
- Click on a category to see its tools
- Categories are color-coded for easy identification

### Step 3: Select a Tool

- **Center panel** shows tools in the selected category
- Click on a tool to see its details
- **Right panel** updates with tool description, version, requirements

### Step 4: Run the Tool

- Click the green **"Run Tool"** button
- Confirmation dialog appears: "Run tool: [name]?"
- Click **Yes** to proceed
- Tool downloads and runs in a separate console window
- GUI shows status: "Running tool..."

### Step 5: Wait for Completion

- Tool runs in its own window (you can see output)
- When complete, success/warning message appears
- Click **OK** to acknowledge
- GUI returns to ready state

### Step 6: Run More Tools or Close

- Select another tool and run it, or
- Click **Close** button to exit
- All temporary files cleaned up automatically

---

## GUI Controls

### Category List (Left Panel)

- **Single-click** to select category
- Shows category name only (hover for description in future version)
- Categories sorted as defined in manifest

### Tool List (Center Panel)

- **Single-click** to select tool (shows details)
- **Double-click** to run tool immediately (skips "Run Tool" button)
- Shows tool name only (version in details panel)

### Tool Details (Right Panel)

- **Tool name and version** at top
- **Description** of what the tool does
- **Author** who created it
- **Category** it belongs to
- **Requirements** (Admin, Database, etc.) with icons

### Run Tool Button

- **Enabled** when a tool is selected
- **Disabled** when no tool selected or during execution
- **Green color** indicates ready to run
- **Grayed out** when disabled

### Status Bar (Bottom)

- **Status Label** (left side) - Shows current activity
  - "Ready" = Idle, waiting for user
  - "Downloading tool..." = Fetching from GitHub
  - "Running tool..." = Tool executing
  - "Tool completed successfully" = Done
- **Refresh Button** (center) - Reload manifest from GitHub
- **Close Button** (right) - Exit toolkit and cleanup

---

## Status Messages

| Message | Meaning |
|---------|---------|
| **Ready** | Idle, waiting for user action |
| **Downloading tool...** | Fetching selected tool from GitHub |
| **Running tool...** | Tool is executing (check console window) |
| **Tool completed successfully** | Tool finished with exit code 0 |
| **Tool completed with warnings** | Tool finished with non-zero exit code |
| **Tool execution failed** | Error occurred during execution |

---

## Dialogs and Prompts

### Update Available Dialog

**When:** On startup, if new version detected

**Message:**
```
A new version of the toolkit is available.

Would you like to update now?
[Yes] [No]
```

**Action:**
- **Yes**: Downloads new version and restarts
- **No**: Continues with current version

### Confirm Execution Dialog

**When:** Before running a tool

**Message:**
```
Run tool: [Tool Name] v[Version]?

[Tool Description]

[Yes] [No]
```

**Action:**
- **Yes**: Proceeds with tool execution
- **No**: Cancels, returns to ready state

### Success Dialog

**When:** Tool completes with exit code 0

**Message:**
```
Tool completed successfully!

[OK]
```

### Warning Dialog

**When:** Tool completes with non-zero exit code

**Message:**
```
Tool completed with exit code: [code]

Check the log for details.

[OK]
```

### Error Dialog

**When:** Download fails or tool crashes

**Message:**
```
Failed to download tool from GitHub.

[OK]
```
or
```
Tool execution failed:

[Error Details]

[OK]
```

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **Enter** | Run selected tool (when tool selected) |
| **Escape** | Close toolkit |
| **F5** | Refresh manifest |
| **Up/Down Arrows** | Navigate lists |
| **Tab** | Switch between panels |

---

## Advantages Over CLI Version

### For Support Staff:

✅ **Easier to use** - No typing, just clicking
✅ **Visual feedback** - See what's happening
✅ **Discoverable** - Browse categories and tools visually
✅ **Less intimidating** - Looks like a normal Windows app
✅ **Fewer mistakes** - No typing errors
✅ **Better for training** - New staff learn faster

### When to Use CLI vs GUI:

**Use GUI when:**
- Support staff are non-technical
- Visual browsing is preferred
- Point-and-click is easier
- Training new staff

**Use CLI when:**
- Running from remote PowerShell session
- Automating with scripts
- No GUI available (Server Core, remote)
- Personal preference for command-line

---

## Troubleshooting

### GUI doesn't open

**Cause:** Windows Forms not available or PowerShell error

**Fix:**
- Ensure Windows desktop environment is running (not Server Core)
- Check PowerShell version: `$PSVersionTable.PSVersion` (need 5.1+)
- Try running from PowerShell console (not ISE)
- Check for error messages in console output

### "Failed to download manifest"

**Cause:** Network issue or GitHub unavailable

**Fix:**
- Verify internet connectivity: `Test-NetConnection github.com`
- Test URL in browser: `https://github.com/StephenShawBepoz/bepoz-toolkit`
- Check firewall/proxy settings
- Click **Refresh** button to retry

### Tool runs but no output visible

**Cause:** Tool window minimized or behind GUI

**Fix:**
- Check taskbar for console window
- Alt+Tab to switch windows
- Look for "Windows PowerShell" window
- Tool may have completed quickly (check success dialog)

### "Tool execution failed"

**Cause:** Tool script error or missing dependencies

**Fix:**
- Check log file: `C:\Temp\BepozToolkit.log`
- Review error message in dialog
- Test tool independently: Download and run manually
- Report issue to tool author

### GUI freezes during execution

**Cause:** Tool running in foreground (shouldn't happen - bug)

**Fix:**
- Wait for tool to complete
- If stuck for >5 minutes, close GUI (Ctrl+C or Task Manager)
- Report issue with tool name and details
- Try CLI version as workaround

### Buttons are disabled

**Cause:** Tool is running or error occurred

**Fix:**
- Wait for current tool to complete
- Check status bar for current activity
- If stuck, close and reopen GUI
- Check log file for errors

---

## Logging

All GUI actions are logged to:
```
C:\Temp\BepozToolkit.log
```

**Log entries include:**
- Timestamp and user
- Actions taken (tool selected, executed, etc.)
- Download success/failures
- Tool exit codes
- Errors and warnings

**Sample log:**
```
2026-02-11 14:32:15 | DOMAIN\tech | [INFO] Toolkit GUI started
2026-02-11 14:32:18 | DOMAIN\tech | [SUCCESS] Bootstrap is up to date (v1.0.0)
2026-02-11 14:32:20 | DOMAIN\tech | [SUCCESS] Manifest loaded: 4 tools in 6 categories
2026-02-11 14:32:45 | DOMAIN\tech | [INFO] User selected tool: EFTPOS Setup v1.0.0
2026-02-11 14:32:48 | DOMAIN\tech | [SUCCESS] Downloaded successfully
2026-02-11 14:32:50 | DOMAIN\tech | [INFO] Executing tool
2026-02-11 14:33:12 | DOMAIN\tech | [SUCCESS] Tool completed with exit code: 0
```

---

## Customization (Future)

Planned features for v2.0:

- **Dark mode** - Toggle light/dark theme
- **Tool search** - Find tools by keyword
- **Favorites** - Pin frequently used tools
- **History** - Recent tools list
- **Log viewer** - View log within GUI
- **Tool output** - Capture output in GUI instead of console
- **Scheduled runs** - Run tools on schedule
- **Multi-tool execution** - Run multiple tools in sequence

---

## Deployment Options

### Option 1: ScreenConnect Script (Recommended)

**Setup:**
1. Open ScreenConnect → Scripts
2. Create new PowerShell script
3. Name: "Bepoz Toolkit (GUI)"
4. Copy contents of `ScreenConnect-Launch-Toolkit-GUI.ps1`
5. Save

**Usage:**
- Connect to customer machine
- Run "Bepoz Toolkit (GUI)" script
- GUI opens automatically

### Option 2: Desktop Shortcut

**Setup:**
1. Download `Invoke-BepozToolkit-GUI.ps1` to customer machine
2. Create shortcut with target:
   ```
   powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\Invoke-BepozToolkit-GUI.ps1"
   ```
3. Place on desktop

**Usage:**
- Double-click shortcut
- GUI opens

### Option 3: One-Line Command

**Usage:**
```powershell
irm https://raw.githubusercontent.com/StephenShawBepoz/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit-GUI.ps1 | iex
```

Copy/paste into PowerShell, press Enter.

---

## Comparison: CLI vs GUI

| Feature | CLI | GUI |
|---------|-----|-----|
| **Ease of Use** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Speed** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Visual Appeal** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Remote Access** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Automation** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Training Time** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Power User** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Beginner Friendly** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

**Recommendation:**
- **Support teams:** Use GUI
- **Technical teams:** Use CLI or GUI (preference)
- **Automation:** Use CLI only

---

## FAQ

**Q: Can I use both CLI and GUI?**
A: Yes! They're separate scripts. Use whichever you prefer.

**Q: Does the GUI show tool output?**
A: Tool output appears in a separate console window. The GUI shows status and results.

**Q: Can I run multiple tools at once?**
A: Not currently. Run one tool, wait for completion, then run another.

**Q: Why does a console window appear when running tools?**
A: Tools run in their own PowerShell process so you can see their output. This will be optional in v2.0.

**Q: Can I resize the GUI window?**
A: No, it's fixed size. This may be configurable in v2.0.

**Q: Does the GUI work on Windows Server?**
A: Yes, if the server has a desktop environment. Server Core requires CLI version.

**Q: Can I customize the colors/theme?**
A: Not yet. Dark mode planned for v2.0.

---

## Summary

The GUI version provides a **user-friendly, point-and-click interface** for the Bepoz Toolkit, perfect for:

- ✅ Support staff who prefer visual tools
- ✅ New technicians learning the toolkit
- ✅ Quick browsing of available tools
- ✅ Professional customer-facing demonstrations

**Getting Started:**
1. Upload `Invoke-BepozToolkit-GUI.ps1` to GitHub bootstrap folder
2. Save `ScreenConnect-Launch-Toolkit-GUI.ps1` in ScreenConnect
3. Train staff on point-and-click usage
4. Enjoy easier tool access!

---

**Questions?** See `README.md` or `SCREENCONNECT_DEPLOYMENT.md` for more info.
