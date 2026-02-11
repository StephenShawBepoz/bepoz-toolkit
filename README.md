# Bepoz Toolkit

**Production-ready PowerShell toolkit for Bepoz support and onboarding teams**

The Bepoz Toolkit provides on-demand access to PowerShell tools for common Bepoz POS tasks. Tools are downloaded fresh from GitHub, executed, and automatically cleaned up. Perfect for ScreenConnect deployment.

## Key Features

- ✅ **On-Demand Download** - Tools are fetched fresh from GitHub every time
- ✅ **Auto-Update** - Bootstrap script updates itself automatically
- ✅ **Hierarchical Categories** - Tools organized by function (Scheduling, SmartPOS Mobile, Kiosk, etc.)
- ✅ **Zero Installation** - No persistent files, everything cleans up after use
- ✅ **Production Ready** - Full logging, error handling, and user confirmations
- ✅ **ScreenConnect Compatible** - Deploy as a saved script for instant access

---

## Quick Start for Support Teams

### Running the Toolkit via ScreenConnect

1. **Open ScreenConnect** to the target customer machine
2. **Open a PowerShell window** (as the logged-in user, not System)
3. **Run the bootstrap script**:
   ```powershell
   # Copy/paste this command (update GitHub org/repo as needed)
   irm https://raw.githubusercontent.com/your-github-org/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit.ps1 | iex
   ```
4. **Select a category** from the menu (e.g., "2) SmartPOS Mobile")
5. **Select a tool** from the category (e.g., "1) User Management Tool")
6. **Confirm execution** when prompted
7. **Tool runs**, then everything cleans up automatically

### Alternative: Save as ScreenConnect Script

1. In ScreenConnect, create a new **PowerShell script**
2. Name it: `Bepoz Toolkit`
3. Paste this content:
   ```powershell
   $org = "your-github-org"
   $repo = "bepoz-toolkit"
   $branch = "main"

   $url = "https://raw.githubusercontent.com/$org/$repo/$branch/bootstrap/Invoke-BepozToolkit.ps1"
   Invoke-Expression (Invoke-RestMethod $url)
   ```
4. Save and use whenever needed

---

## Setup for Developers

### 1. Create GitHub Repository

Create a **public** GitHub repository with this structure:

```
your-github-org/bepoz-toolkit/
├── manifest.json                    # Tool catalog (categories, versions)
├── bootstrap/
│   └── Invoke-BepozToolkit.ps1     # Bootstrap script (auto-updates)
├── modules/
│   └── BepozDbCore.ps1             # Shared database functions
├── tools/
│   ├── Weekly-Schedule-Tool.ps1
│   ├── User-Tool.ps1
│   ├── EFTPOS-Setup.ps1
│   └── Venue-Query.ps1
└── README.md                        # This file
```

### 2. Upload Files to GitHub

Upload all files from this package:
- `manifest.json` → root of repo
- `Invoke-BepozToolkit.ps1` → `bootstrap/` folder
- `BepozDbCore.ps1` → `modules/` folder
- `Tool-Template.ps1` → `tools/` folder (as example)
- `README.md` → root of repo

### 3. Update Configuration

Edit `Invoke-BepozToolkit.ps1` and change the default parameters:

```powershell
param(
    [string]$GitHubOrg = "your-actual-github-org",     # ← Change this
    [string]$GitHubRepo = "bepoz-toolkit",             # ← And this if different
    [string]$Branch = "main"
)
```

### 4. Test the Bootstrap

Run locally to verify everything works:

```powershell
.\Invoke-BepozToolkit.ps1
```

You should see:
- Auto-update check (will say "up to date" on first run)
- Category menu
- Ability to select and run tools

---

## Adding New Tools

### Method 1: Use the Template

1. Copy `tools/Tool-Template.ps1` to a new file (e.g., `tools/My-New-Tool.ps1`)
2. Update the header comments (synopsis, description, version, category)
3. Replace the example logic with your tool's functionality
4. Test locally on a Bepoz workstation
5. Add the tool to `manifest.json`:

```json
{
  "id": "my-new-tool",
  "name": "My New Tool",
  "category": "workstation",
  "file": "tools/My-New-Tool.ps1",
  "description": "Does something useful for workstations",
  "version": "1.0.0",
  "requiresAdmin": false,
  "requiresDatabase": true,
  "author": "Your Name"
}
```

6. Commit and push to GitHub
7. Tool is immediately available to all users (auto-update)

### Method 2: Migrate Existing Tools

If you have existing `.ps1` files:

1. Add the standard header from `Tool-Template.ps1`
2. Wrap your code in the `Start-Tool` function pattern
3. Add prerequisite checks (registry, DB connection)
4. Ensure it returns exit code (0 = success, 1 = user cancel, 2 = error)
5. Update `manifest.json` as above

---

## Tool Categories

Current categories defined in `manifest.json`:

- **Scheduling** - Schedule management and time-based operations
- **SmartPOS Mobile** - SmartPOS Mobile configuration tools
- **Kiosk** - Kiosk setup and maintenance
- **TSPlus** - Terminal Services Plus configuration
- **Database Tools** - Direct database queries and utilities
- **Workstation Setup** - Workstation and device configuration

To add a new category, edit the `categories` array in `manifest.json`.

---

## BepozDbCore Module Usage

All tools have access to `BepozDbCore.ps1` for database operations:

### Available Functions

```powershell
# Get database configuration from registry
$config = Get-BepozDatabaseConfig
# Returns: { SqlServer, Database, Registry, User }

# Execute a SELECT query
$venues = Invoke-BepozQuery -Query "SELECT * FROM dbo.Venue WHERE Active = 1"
foreach ($row in $venues.Rows) {
    Write-Host "$($row.VenueID): $($row.Name)"
}

# Execute query with parameters (ALWAYS use this for user input)
$params = @{"@VenueID" = 5}
$result = Invoke-BepozQuery -Query "SELECT * FROM dbo.Venue WHERE VenueID = @VenueID" -Parameters $params

# Execute INSERT/UPDATE/DELETE
$params = @{"@VenueID" = 5; "@Name" = "Updated Name"}
$affected = Invoke-BepozNonQuery -Query "UPDATE dbo.Venue SET Name = @Name WHERE VenueID = @VenueID" -Parameters $params

# Call stored procedure
$params = @{"@VenueID" = 1}
$result = Invoke-BepozStoredProc -ProcedureName "dbo.GetVenueDetails" -Parameters $params

# Test database connectivity
if (Test-BepozDatabaseConnection) {
    Write-Host "Database OK"
}
```

### Critical Patterns

- **ALWAYS parameterize** user input (prevents SQL injection)
- **ALWAYS check** `Invoke-BepozQuery` result for `$null` before accessing `.Rows`
- **NEVER concatenate** user input into SQL strings
- **Registry keys** are read from `HKCU:\SOFTWARE\Backoffice` (SQL_Server, SQL_DSN)

---

## Version Management

### Bootstrap Auto-Update

The bootstrap script checks GitHub for updates on **every run**:

1. Downloads `manifest.json`
2. Compares `manifest.bootstrap.version` to current version
3. If newer version available:
   - Downloads new bootstrap
   - Relaunches with new version
   - Old version is discarded

To disable auto-update (for testing), comment out the update check in `Start-Toolkit`.

### Tool Versioning

Tool versions are tracked in `manifest.json`. When you update a tool:

1. Increment the `version` field in `manifest.json`
2. Update the `$Script:ToolVersion` variable in the tool itself
3. Commit and push to GitHub
4. Users get the new version immediately (tools are downloaded fresh every run)

---

## Logging

All toolkit operations are logged to: `$env:TEMP\BepozToolkit.log`

Log format:
```
2026-02-11 14:32:15 | DOMAIN\technician | [INFO] Toolkit started
2026-02-11 14:32:18 | DOMAIN\technician | [SUCCESS] Bootstrap is up to date (v1.0.0)
2026-02-11 14:32:45 | DOMAIN\technician | [INFO] User selected tool: EFTPOS Setup v1.0.0
2026-02-11 14:33:12 | DOMAIN\technician | [SUCCESS] Tool completed successfully (exit code: 0)
```

Tools can write to this log by implementing their own logging, or using the bootstrap's log file.

---

## Troubleshooting

### "Failed to download manifest.json"

**Cause:** Network issue, incorrect GitHub URL, or private repo without auth

**Fix:**
- Verify internet connectivity on client machine
- Check GitHub org/repo names in bootstrap script
- Ensure repo is public (or add auth for private)
- Test URL manually: `https://raw.githubusercontent.com/your-org/your-repo/main/manifest.json`

### "Bepoz registry keys not found"

**Cause:** Tool is running on non-Bepoz machine or wrong user context

**Fix:**
- Verify running on Bepoz POS workstation
- Run as the logged-in user (not System)
- Check `HKCU:\SOFTWARE\Backoffice` exists and has `SQL_Server`, `SQL_DSN` values

### "Module BepozDbCore not found"

**Cause:** Module download failed or not available in temp

**Fix:**
- Module should auto-download to `$env:TEMP`
- Check network connectivity
- Verify `modules/BepozDbCore.ps1` exists in GitHub repo
- Run bootstrap with `-Verbose` to see download attempts

### "Tool execution failed" / Exit Code 2

**Cause:** Unhandled error in tool script

**Fix:**
- Check log file: `$env:TEMP\BepozToolkit.log`
- Review tool's error messages
- Test tool independently: `.\My-Tool.ps1`
- Add error handling to tool script

### PowerShell Execution Policy Blocked

**Cause:** Client machine has restricted execution policy

**Fix:**
```powershell
# Temporary bypass (current session only)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Or run with bypass flag
powershell.exe -ExecutionPolicy Bypass -File .\Invoke-BepozToolkit.ps1
```

---

## Switching to Private Repository

If you need to make the repo private later:

1. In GitHub, go to **Settings** → **Danger Zone** → **Change visibility**
2. Make repository **Private**
3. Generate a **Personal Access Token (PAT)** with `repo` scope
4. Update bootstrap download logic to include auth header:

```powershell
$headers = @{
    Authorization = "token YOUR_GITHUB_PAT"
}
Invoke-WebRequest -Uri $url -OutFile $dest -Headers $headers -UseBasicParsing
```

**Security Note:** Store PAT securely (not in script), or use environment variables.

---

## Support

For issues or feature requests:
- Check `$env:TEMP\BepozToolkit.log` for detailed error messages
- Review tool-specific documentation in script headers
- Test tools independently before blaming the toolkit
- Contact: Bepoz Support Team

---

## License

Internal use only - Bepoz Support Team

---

## Changelog

### v1.0.0 (2026-02-11)
- Initial release
- Hierarchical category menu
- Auto-update bootstrap
- BepozDbCore module v1.1.0
- Production logging and error handling
- ScreenConnect deployment support
