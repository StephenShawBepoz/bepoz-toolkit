# GitHub Repository Structure Guide

This document shows the exact folder structure for your `bepoz-toolkit` GitHub repository.

## Complete Repository Layout

```
your-github-org/bepoz-toolkit/
│
├── manifest.json                           # Master catalog (REQUIRED)
│
├── README.md                               # User documentation
├── GITHUB_REPO_STRUCTURE.md               # This file
│
├── bootstrap/                              # Bootstrap scripts folder
│   └── Invoke-BepozToolkit.ps1            # Main bootstrap (REQUIRED)
│
├── modules/                                # Shared modules folder
│   └── BepozDbCore.ps1                    # Database access module (REQUIRED)
│
├── tools/                                  # Individual tools folder
│   ├── Tool-Template.ps1                  # Template for new tools (example)
│   │
│   ├── Weekly-Schedule-Tool.ps1           # Your existing tools
│   ├── User-Tool.ps1                      #
│   │
│   ├── EFTPOS-Setup.ps1                   # Example tools (customize as needed)
│   └── Venue-Query.ps1                    #
│
└── docs/                                   # Optional: Additional documentation
    ├── ADDING_TOOLS.md                    # How to add new tools
    ├── DEPLOYMENT_GUIDE.md                # ScreenConnect deployment guide
    └── TROUBLESHOOTING.md                 # Common issues and fixes
```

---

## Required Files (Minimum Viable Toolkit)

These files **MUST** be present for the toolkit to function:

### 1. `manifest.json` (root)
- Defines all available tools and categories
- Tracks bootstrap version for auto-update
- Lists shared modules

### 2. `bootstrap/Invoke-BepozToolkit.ps1`
- The main bootstrap script
- Downloads manifest, shows menus, executes tools
- Auto-updates itself

### 3. `modules/BepozDbCore.ps1`
- Core database access functions
- Used by most tools for Bepoz SQL Server access

### 4. At least one tool in `tools/`
- Example: `tools/Tool-Template.ps1`
- Tools are `.ps1` files that perform specific tasks

---

## File Upload Checklist

When setting up your GitHub repo, upload files in this order:

1. ✅ Create repository on GitHub (public)
2. ✅ Upload `README.md` to root
3. ✅ Upload `manifest.json` to root
4. ✅ Create folder: `bootstrap/`
5. ✅ Upload `Invoke-BepozToolkit.ps1` to `bootstrap/`
6. ✅ Create folder: `modules/`
7. ✅ Upload `BepozDbCore.ps1` to `modules/`
8. ✅ Create folder: `tools/`
9. ✅ Upload tool files (`.ps1`) to `tools/`
10. ✅ Test bootstrap script from ScreenConnect

---

## Folder Purposes

### `bootstrap/`
**Purpose:** Contains the bootstrap script that users run to launch the toolkit

**Contents:**
- `Invoke-BepozToolkit.ps1` - Main bootstrap script

**URL Pattern:**
```
https://raw.githubusercontent.com/your-org/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit.ps1
```

### `modules/`
**Purpose:** Shared PowerShell modules used by multiple tools

**Contents:**
- `BepozDbCore.ps1` - Database access functions (always included)
- Additional modules as needed (e.g., `BepozNetworking.ps1`, `BepozLogging.ps1`)

**Usage:**
Tools can dot-source modules:
```powershell
. $tempModule.FullName  # Load BepozDbCore
```

### `tools/`
**Purpose:** Individual tool scripts (.ps1 files)

**Contents:**
- Each tool is a standalone `.ps1` file
- Tools are organized by function (not subfolders)
- Naming convention: `Descriptive-Name-Tool.ps1` (PascalCase with hyphens)

**Examples:**
- `Weekly-Schedule-Tool.ps1`
- `User-Management-Tool.ps1`
- `EFTPOS-Setup.ps1`
- `Venue-Query.ps1`
- `Kiosk-Reset.ps1`

### `docs/` (Optional)
**Purpose:** Additional documentation for developers and power users

**Suggested Contents:**
- `ADDING_TOOLS.md` - Step-by-step guide for creating new tools
- `DEPLOYMENT_GUIDE.md` - ScreenConnect deployment instructions
- `TROUBLESHOOTING.md` - Common issues and solutions
- `API_REFERENCE.md` - BepozDbCore function reference

---

## URL Patterns

GitHub serves raw files at predictable URLs. The bootstrap uses this pattern:

```
https://raw.githubusercontent.com/{ORG}/{REPO}/{BRANCH}/{FILE_PATH}
```

### Examples:

**Manifest:**
```
https://raw.githubusercontent.com/your-org/bepoz-toolkit/main/manifest.json
```

**Bootstrap:**
```
https://raw.githubusercontent.com/your-org/bepoz-toolkit/main/bootstrap/Invoke-BepozToolkit.ps1
```

**Module:**
```
https://raw.githubusercontent.com/your-org/bepoz-toolkit/main/modules/BepozDbCore.ps1
```

**Tool:**
```
https://raw.githubusercontent.com/your-org/bepoz-toolkit/main/tools/Weekly-Schedule-Tool.ps1
```

---

## manifest.json Structure

The `manifest.json` file ties everything together:

```json
{
  "bootstrap": {
    "version": "1.0.0",
    "file": "bootstrap/Invoke-BepozToolkit.ps1"
  },
  "modules": {
    "BepozDbCore": {
      "version": "1.1.0",
      "file": "modules/BepozDbCore.ps1",
      "description": "Core database functions"
    }
  },
  "categories": [
    { "id": "scheduling", "name": "Scheduling", "description": "..." }
  ],
  "tools": [
    {
      "id": "weekly-schedule",
      "name": "Weekly Schedule Tool",
      "category": "scheduling",
      "file": "tools/Weekly-Schedule-Tool.ps1",
      "version": "1.0.0"
    }
  ]
}
```

**Key Points:**
- `file` paths are relative to repo root
- Tool `category` must match a category `id`
- Versions are semantic (major.minor.patch)

---

## Adding New Tools

### Quick Method:

1. Create new `.ps1` file in `tools/` folder
2. Add entry to `manifest.json` under `tools` array
3. Commit and push to GitHub
4. Tool is immediately available (users get it on next run)

### Example: Adding "Kiosk-Reset.ps1"

1. **Create file:** `tools/Kiosk-Reset.ps1`
2. **Add to manifest:**
   ```json
   {
     "id": "kiosk-reset",
     "name": "Kiosk Reset Tool",
     "category": "kiosk",
     "file": "tools/Kiosk-Reset.ps1",
     "description": "Resets kiosk to default settings",
     "version": "1.0.0",
     "requiresAdmin": true,
     "requiresDatabase": false
   }
   ```
3. **Commit and push**
4. **Test:**
   ```powershell
   # Run bootstrap, select "Kiosk" category, see new tool
   ```

---

## Adding New Categories

Edit `manifest.json` to add a new category:

```json
{
  "categories": [
    {
      "id": "my-new-category",
      "name": "My New Category",
      "description": "Tools for doing something specific"
    }
  ]
}
```

**Rules:**
- `id` must be lowercase, alphanumeric, hyphens only
- `name` is what users see in the menu
- Tools reference category by `id`

---

## Version Control Best Practices

### Branching Strategy

**Recommended: Simple single-branch**
- Use `main` branch for everything
- Tools auto-update on every run
- Quick iteration, immediate deployment

**Alternative: Multi-branch**
- `main` = production (stable)
- `develop` = testing (new features)
- Update bootstrap to point to desired branch

### Tagging Releases

Tag stable releases for rollback capability:

```bash
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0
```

To rollback, update bootstrap to use tag instead of branch:
```
https://raw.githubusercontent.com/your-org/bepoz-toolkit/v1.0.0/...
```

---

## Testing Changes

### Local Testing (Before Push)

1. Clone repo locally
2. Edit files
3. Test bootstrap with local files:
   ```powershell
   # Point to local repo for testing
   cd C:\local-repo\bepoz-toolkit
   .\bootstrap\Invoke-BepozToolkit.ps1
   ```
4. If working, commit and push

### Remote Testing (After Push)

1. Push changes to GitHub
2. Run bootstrap from ScreenConnect on test machine
3. Verify changes appear
4. Check logs: `$env:TEMP\BepozToolkit.log`

---

## Security Considerations

### Public Repository
- ✅ Code is visible to anyone
- ✅ No credentials or secrets in scripts
- ✅ No customer-specific data in tools
- ✅ Generic tools only

### Switching to Private
If you need privacy:
1. Make repo private in GitHub settings
2. Generate Personal Access Token (PAT)
3. Update bootstrap download logic to include auth
4. Store PAT securely (not in script)

---

## File Size Limits

GitHub has limits on file sizes:
- **Individual file max:** 100 MB (hard limit)
- **Recommended max per file:** 10 MB
- **Repository max:** 1 GB (soft limit, 5 GB hard limit)

For this toolkit:
- Bootstrap: ~10 KB (well under limit)
- Module: ~10 KB (well under limit)
- Tools: 1-50 KB typical (well under limit)
- Manifest: ~5 KB (well under limit)

**No issues expected** with size limits for this use case.

---

## Backup and Disaster Recovery

### Backup Strategy

1. **GitHub is your backup** - All files versioned and stored remotely
2. **Clone locally** for offline access:
   ```bash
   git clone https://github.com/your-org/bepoz-toolkit.git
   ```
3. **Export releases** as ZIP for archival

### Recovery Scenarios

**Scenario: Accidentally deleted file**
- Restore from GitHub history (revert commit)

**Scenario: Bad update pushed**
- Revert commit or checkout previous version
- Users get previous version on next run (auto-update)

**Scenario: GitHub outage**
- Use local clone + ScreenConnect file transfer
- Or wait for GitHub to recover

---

## Summary Checklist

### Initial Setup
- [ ] Create GitHub repository (public)
- [ ] Upload `manifest.json` to root
- [ ] Upload `README.md` to root
- [ ] Create `bootstrap/` folder
- [ ] Upload `Invoke-BepozToolkit.ps1` to `bootstrap/`
- [ ] Create `modules/` folder
- [ ] Upload `BepozDbCore.ps1` to `modules/`
- [ ] Create `tools/` folder
- [ ] Upload tool files to `tools/`
- [ ] Test bootstrap from ScreenConnect

### Maintenance
- [ ] Increment `version` in manifest when updating tools
- [ ] Update tool `$Script:ToolVersion` variable
- [ ] Test changes locally before pushing
- [ ] Tag stable releases (`v1.0.0`, `v1.1.0`, etc.)
- [ ] Document breaking changes in README

---

**Questions?** Refer to `README.md` or contact Bepoz Support Team.
