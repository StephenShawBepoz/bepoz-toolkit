# Bepoz Toolkit Hybrid Launcher - Implementation Plan

**Document Version:** 2.0
**Created:** 2026-02-12
**Last Updated:** 2026-02-13 (Agent 1: Final Reconciliation - Ready for Implementation)
**Status:** Final - Ready for Implementation
**Target Timeline:** 21 days (3 weeks)

---

## Executive Summary

This document outlines the complete implementation plan for rebuilding the Bepoz Toolkit as a **Hybrid Launcher** (Option 3). This architecture combines the best of both worlds:

- **Compiled .NET Launcher** (GUI + orchestration) - provides modern UI, persistence, and professional user experience
- **Live PowerShell Tools from GitHub** - maintains auto-update capability and IT team flexibility

### Key Benefits
- ✅ Modern, polished WPF interface with MaterialDesign theme and Mica/Acrylic backdrop
- ✅ Dark/Light/Bepoz theme system with smooth animated transitions
- ✅ Persistent settings and usage statistics (SQLite)
- ✅ Tools auto-update from GitHub (no launcher updates needed for tool changes)
- ✅ Fast startup (~2 seconds) with skeleton loading states
- ✅ Professional MSI installer with shortcuts
- ✅ Offline caching for reliability
- ✅ Maintains backward compatibility with existing PS1 tools
- ✅ Command palette (Ctrl+K) for power-user quick-launch
- ✅ Toast notifications (no intrusive popups)
- ✅ System tray integration with quick-launch menu
- ✅ Full keyboard accessibility and High DPI support
- ✅ Live dashboard with sparkline trends and activity feed

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Technology Stack](#technology-stack)
3. [Project Structure](#project-structure)
4. [Data Models](#data-models)
5. [Service Interfaces](#service-interfaces)
6. [UI/UX Design](#uiux-design)
7. [UI Enhancement Directives (Agent 1)](#ui-enhancement-directives-agent-1)
8. [Devil's Advocate Review (Agent 3)](#devils-advocate-review-agent-3)
9. [Final Implementation Directives (Reconciled)](#final-implementation-directives-reconciled)
10. [Implementation Phases](#implementation-phases)
11. [Database Schema](#database-schema)
12. [Deployment Strategy](#deployment-strategy)
13. [Auto-Update Mechanism](#auto-update-mechanism)
14. [Migration Path](#migration-path)
15. [Risk Analysis](#risk-analysis)
16. [Success Metrics](#success-metrics)
17. [Timeline](#timeline)

---

## Architecture Overview

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  BepozToolkit.exe (.NET 6/8)                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  WPF UI     │  │  Services    │  │  PowerShell  │      │
│  │  (MVVM)     │◄─┤  Layer       │◄─┤  Host        │      │
│  └─────────────┘  └──────────────┘  └──────────────┘      │
│        │                 │                   │             │
│        │                 ▼                   │             │
│        │         ┌──────────────┐            │             │
│        │         │  SQLite DB   │            │             │
│        │         │  (Settings)  │            │             │
│        │         └──────────────┘            │             │
│        │                                     │             │
└────────┼─────────────────────────────────────┼─────────────┘
         │                                     │
         ▼                                     ▼
  ┌─────────────┐                    ┌─────────────────┐
  │  User sees  │                    │  GitHub API     │
  │  modern UI  │                    │  (fetch tools)  │
  └─────────────┘                    └─────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  Cache PS1 files │
                                    │  locally         │
                                    └──────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  Execute via     │
                                    │  PowerShell SDK  │
                                    └──────────────────┘
```

### Data Flow

1. **Startup**
   - Launcher reads manifest.json from GitHub (or cache if offline)
   - Populates tool catalog in SQLite
   - Displays modern WPF dashboard

2. **Tool Execution**
   - User clicks "Run" on a tool
   - Launcher downloads PS1 + dependencies from GitHub (cached for 1 hour)
   - Creates PowerShell runspace with embedded runtime
   - Executes PS1 in isolated runspace
   - Captures output/logs and displays in real-time
   - Records usage statistics to SQLite

3. **Updates**
   - Tools update automatically (fetched from GitHub on each run)
   - Launcher can self-update via GitHub Releases (check on startup)
   - No user intervention required

---

## Technology Stack

### Core Technologies

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Framework** | .NET | 6 LTS or 8 LTS | Cross-platform, modern, long-term support |
| **UI Framework** | WPF | Built-in | Native Windows UI with XAML |
| **UI Toolkit** | MaterialDesignThemes | 5.x | Modern Material Design components |
| **UI Animations** | WpfAnimatedGif + custom Storyboards | N/A | Smooth transitions, skeleton loading, ripple effects |
| **Toast Notifications** | Notification.Wpf | 7.x | Non-blocking toast notification system |
| **Charts** | LiveCharts2 | 2.x | Sparkline charts and usage trend visualizations |
| **PowerShell** | System.Management.Automation | 7.x SDK | Embedded PowerShell runtime |
| **Database** | SQLite | 3.x | Lightweight embedded database |
| **GitHub API** | Octokit.NET | 9.x | GitHub repository interaction |
| **Logging** | Serilog | 3.x | Structured logging |
| **JSON** | System.Text.Json | Built-in | Fast JSON serialization |
| **Dependency Injection** | Microsoft.Extensions.DependencyInjection | Built-in | Service management |
| **Installer** | WiX Toolset | 4.x | MSI installer creation |

### Development Tools

- **IDE:** Visual Studio 2022 Community (free) or JetBrains Rider
- **Version Control:** Git + GitHub
- **Build System:** MSBuild / dotnet CLI
- **Package Manager:** NuGet
- **Testing:** xUnit + FluentAssertions

---

## Project Structure

```
BepozToolkit/
├── BepozToolkit.sln                          # Solution file
│
├── src/
│   ├── BepozToolkit.App/                     # Main WPF application
│   │   ├── BepozToolkit.App.csproj
│   │   ├── App.xaml                          # Application entry point
│   │   ├── App.xaml.cs
│   │   ├── MainWindow.xaml                   # Main window
│   │   ├── MainWindow.xaml.cs
│   │   │
│   │   ├── ViewModels/                       # MVVM ViewModels
│   │   │   ├── MainViewModel.cs              # Main window VM
│   │   │   ├── DashboardViewModel.cs         # Dashboard tab
│   │   │   ├── ToolsViewModel.cs             # Tools browser tab
│   │   │   ├── LogsViewModel.cs              # Logs tab
│   │   │   ├── SettingsViewModel.cs          # Settings tab
│   │   │   └── ToolExecutionViewModel.cs     # Tool execution window
│   │   │
│   │   ├── Views/                            # XAML Views
│   │   │   ├── DashboardView.xaml
│   │   │   ├── ToolsView.xaml
│   │   │   ├── LogsView.xaml
│   │   │   ├── SettingsView.xaml
│   │   │   └── ToolExecutionWindow.xaml
│   │   │
│   │   ├── Controls/                         # Custom controls
│   │   │   ├── ToolCard.xaml                 # Tool display card (with hover, star, context menu)
│   │   │   ├── LogViewer.xaml                # Log display control
│   │   │   ├── ProgressButton.xaml           # Button with progress
│   │   │   ├── ToastNotification.xaml        # Non-blocking toast notification overlay
│   │   │   ├── CommandPalette.xaml           # Ctrl+K quick-launch overlay
│   │   │   ├── SparklineChart.xaml           # Mini trend chart for dashboard stats
│   │   │   ├── SkeletonLoader.xaml           # Animated skeleton placeholder
│   │   │   ├── StatusPill.xaml               # Health status indicator (green/amber/red)
│   │   │   ├── FloatingActionButton.xaml     # Primary action FAB
│   │   │   ├── BreadcrumbBar.xaml            # Navigation breadcrumb trail
│   │   │   └── KeyboardShortcutsOverlay.xaml # Press ? to see shortcuts
│   │   │
│   │   ├── Converters/                       # Value converters
│   │   │   ├── BoolToVisibilityConverter.cs
│   │   │   ├── CategoryToColorConverter.cs
│   │   │   ├── StatusToPulseConverter.cs     # Pulsing dot for running tools
│   │   │   └── ThemeToResourceConverter.cs   # Dark/Light theme switching
│   │   │
│   │   ├── Animations/                       # Animation resources
│   │   │   ├── TabTransitions.xaml           # Slide/fade between tabs
│   │   │   ├── RippleEffect.xaml             # Material ripple on button click
│   │   │   ├── SkeletonShimmer.xaml          # Shimmer animation for loading
│   │   │   └── SuccessShake.xaml             # Success confetti / failure shake
│   │   │
│   │   ├── Themes/                           # Theme definitions
│   │   │   ├── LightTheme.xaml               # Light color palette
│   │   │   ├── DarkTheme.xaml                # Dark color palette
│   │   │   └── BepozTheme.xaml               # Bepoz-branded theme
│   │   │
│   │   ├── Resources/                        # Resources
│   │   │   ├── Styles.xaml                   # Global styles
│   │   │   ├── Icons.xaml                    # Icon resources
│   │   │   └── icon.ico                      # Application icon
│   │   │
│   │   └── Helpers/                          # UI helpers
│   │       ├── RelayCommand.cs               # ICommand implementation
│   │       ├── ViewModelBase.cs              # Base ViewModel class
│   │       ├── WindowPositionManager.cs      # Remember window size/position
│   │       └── SystemTrayManager.cs          # System tray icon + quick-launch menu
│   │
│   ├── BepozToolkit.Core/                    # Core business logic
│   │   ├── BepozToolkit.Core.csproj
│   │   │
│   │   ├── Models/                           # Domain models
│   │   │   ├── Tool.cs                       # Tool metadata
│   │   │   ├── Category.cs                   # Tool category
│   │   │   ├── Module.cs                     # PowerShell module
│   │   │   ├── ToolExecutionResult.cs        # Execution result
│   │   │   ├── Settings.cs                   # User settings
│   │   │   └── UsageStatistic.cs             # Usage tracking
│   │   │
│   │   ├── Services/                         # Service interfaces
│   │   │   ├── IGitHubService.cs             # GitHub API interface
│   │   │   ├── GitHubService.cs              # Implementation
│   │   │   ├── IPowerShellHost.cs            # PowerShell execution interface
│   │   │   ├── PowerShellHost.cs             # Implementation
│   │   │   ├── ISettingsService.cs           # Settings persistence
│   │   │   ├── SettingsService.cs            # Implementation
│   │   │   ├── IStatsService.cs              # Usage tracking
│   │   │   ├── StatsService.cs               # Implementation
│   │   │   ├── ICacheService.cs              # File caching
│   │   │   └── CacheService.cs               # Implementation
│   │   │
│   │   ├── Database/                         # Database access
│   │   │   ├── BepozToolkitContext.cs        # SQLite context
│   │   │   └── Migrations/                   # DB migrations
│   │   │       └── InitialCreate.cs
│   │   │
│   │   └── Constants.cs                      # App constants
│   │
│   └── BepozToolkit.Installer/               # WiX installer project
│       ├── BepozToolkit.Installer.wixproj
│       ├── Product.wxs                        # Installer definition
│       └── Bundle.wxs                         # Bundle configuration
│
├── tests/
│   ├── BepozToolkit.Tests/                   # Unit tests
│   │   ├── BepozToolkit.Tests.csproj
│   │   ├── Services/
│   │   │   ├── GitHubServiceTests.cs
│   │   │   ├── PowerShellHostTests.cs
│   │   │   └── CacheServiceTests.cs
│   │   └── ViewModels/
│   │       ├── DashboardViewModelTests.cs
│   │       └── ToolsViewModelTests.cs
│   │
│   └── BepozToolkit.IntegrationTests/        # Integration tests
│       ├── BepozToolkit.IntegrationTests.csproj
│       └── EndToEndTests.cs
│
├── docs/
│   ├── HYBRID_LAUNCHER_PLAN.md               # This document
│   ├── API.md                                # Service API documentation
│   └── USER_GUIDE.md                         # End-user guide
│
├── .github/
│   └── workflows/
│       ├── build.yml                         # CI build
│       ├── release.yml                       # Release workflow
│       └── test.yml                          # Test workflow
│
├── .gitignore
├── README.md
└── LICENSE
```

---

## Data Models

### Tool Model

```csharp
namespace BepozToolkit.Core.Models
{
    public class Tool
    {
        public string Id { get; set; }                    // "weekschedule-bulk-manager"
        public string Name { get; set; }                  // "WeekSchedule Bulk Manager"
        public string Category { get; set; }              // "scheduling"
        public string Description { get; set; }           // Tool description
        public string Version { get; set; }               // "2.0.4"
        public string File { get; set; }                  // "tools/BepozWeekScheduleBulkManager.ps1"
        public bool RequiresAdmin { get; set; }           // Elevation required?
        public bool RequiresDatabase { get; set; }        // Database access needed?
        public string Author { get; set; }                // "Bepoz Administration Team"
        public string Documentation { get; set; }         // Wiki URL
        public DateTime LastUpdated { get; set; }         // From GitHub API
        public List<string> Dependencies { get; set; }    // Required modules
        public ToolStatus Status { get; set; }            // Available, Cached, Running, Failed
    }

    public enum ToolStatus
    {
        Available,      // Not cached, needs download
        Cached,         // Downloaded and ready
        Running,        // Currently executing
        Completed,      // Finished successfully
        Failed          // Execution error
    }
}
```

### Category Model

```csharp
public class Category
{
    public string Id { get; set; }                        // "scheduling"
    public string Name { get; set; }                      // "Scheduling"
    public string Description { get; set; }               // Description
    public string Icon { get; set; }                      // MaterialDesign icon name
    public System.Windows.Media.Color Color { get; set; } // Category color
    public int ToolCount { get; set; }                    // Number of tools
}
```

### Module Model

```csharp
public class Module
{
    public string Name { get; set; }                      // "BepozDbCore"
    public string Version { get; set; }                   // "1.3.1"
    public string File { get; set; }                      // "modules/BepozDbCore.ps1"
    public string Description { get; set; }               // Description
    public bool IsLoaded { get; set; }                    // Currently loaded?
    public DateTime CachedDate { get; set; }              // When downloaded
}
```

### Settings Model

```csharp
public class Settings
{
    public string GitHubOwner { get; set; } = "StephenShawBepoz";
    public string GitHubRepo { get; set; } = "bepoz-toolkit";
    public string GitHubBranch { get; set; } = "main";
    public int CacheExpirationMinutes { get; set; } = 60;
    public bool CheckForUpdatesOnStartup { get; set; } = true;
    public bool EnableUsageTracking { get; set; } = true;
    public bool EnableLogging { get; set; } = true;
    public string LogLevel { get; set; } = "Information";
    public string Theme { get; set; } = "Bepoz";          // Light, Dark, Bepoz
    public bool ConfirmToolExecution { get; set; } = false;
    public string DatabaseServer { get; set; } = "";      // Saved DB connection
    public string DatabaseName { get; set; } = "";

    // UI Enhancement Settings (Agent 1 Additions)
    public bool MinimizeToSystemTray { get; set; } = true;
    public bool EnableAnimations { get; set; } = true;     // Toggle all UI animations
    public bool EnableToastNotifications { get; set; } = true;
    public double WindowLeft { get; set; } = -1;           // Remembered window position
    public double WindowTop { get; set; } = -1;
    public double WindowWidth { get; set; } = 1100;
    public double WindowHeight { get; set; } = 750;
    public List<string> FavoriteToolIds { get; set; } = new(); // Starred tool IDs
    public List<string> PinnedToolIds { get; set; } = new();   // Pinned to dashboard
}
```

### ToolExecutionResult Model

```csharp
public class ToolExecutionResult
{
    public bool Success { get; set; }
    public string Output { get; set; }                    // Standard output
    public string Error { get; set; }                     // Error output
    public TimeSpan Duration { get; set; }                // Execution time
    public int ExitCode { get; set; }                     // PowerShell exit code
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public Dictionary<string, object> Metadata { get; set; } // Custom data
}
```

### UsageStatistic Model

```csharp
public class UsageStatistic
{
    public int Id { get; set; }                           // Auto-increment
    public string ToolId { get; set; }                    // Tool identifier
    public string ToolName { get; set; }                  // Tool display name
    public DateTime ExecutedAt { get; set; }              // When run
    public string UserName { get; set; }                  // Windows username
    public string ComputerName { get; set; }              // Machine name
    public bool Success { get; set; }                     // Completed successfully?
    public int DurationMs { get; set; }                   // Execution time
    public string ErrorMessage { get; set; }              // Error if failed
}
```

---

## Service Interfaces

### IGitHubService

Handles all GitHub API interactions.

```csharp
public interface IGitHubService
{
    /// <summary>
    /// Fetches manifest.json from GitHub repository
    /// </summary>
    Task<Manifest> GetManifestAsync(bool forceRefresh = false);

    /// <summary>
    /// Downloads a PowerShell script file from GitHub
    /// </summary>
    /// <param name="filePath">Relative path in repo (e.g., "tools/BepozWebApiSettings.ps1")</param>
    /// <returns>File content as string</returns>
    Task<string> GetFileContentAsync(string filePath);

    /// <summary>
    /// Downloads a file and caches it locally
    /// </summary>
    Task<string> DownloadAndCacheFileAsync(string filePath);

    /// <summary>
    /// Checks if a new launcher version is available
    /// </summary>
    Task<(bool Available, string Version, string DownloadUrl)> CheckForLauncherUpdateAsync();

    /// <summary>
    /// Gets last commit date for a file (shows when tool was last updated)
    /// </summary>
    Task<DateTime> GetFileLastUpdatedAsync(string filePath);
}
```

### IPowerShellHost

Manages PowerShell execution.

```csharp
public interface IPowerShellHost
{
    /// <summary>
    /// Executes a PowerShell script file with real-time output
    /// </summary>
    /// <param name="scriptPath">Path to .ps1 file</param>
    /// <param name="parameters">Parameters to pass to script</param>
    /// <param name="outputCallback">Called for each line of output</param>
    /// <param name="errorCallback">Called for each error</param>
    /// <param name="progressCallback">Called for progress updates</param>
    Task<ToolExecutionResult> ExecuteScriptAsync(
        string scriptPath,
        Dictionary<string, object> parameters = null,
        Action<string> outputCallback = null,
        Action<string> errorCallback = null,
        Action<int> progressCallback = null
    );

    /// <summary>
    /// Stops a currently running script
    /// </summary>
    void StopExecution();

    /// <summary>
    /// Checks if script requires admin elevation
    /// </summary>
    bool IsRunningAsAdmin();

    /// <summary>
    /// Restarts application with admin privileges
    /// </summary>
    void RestartAsAdmin();

    /// <summary>
    /// Tests if PowerShell modules can be loaded
    /// </summary>
    Task<bool> TestModuleLoadingAsync(string modulePath);
}
```

### ISettingsService

Manages application settings persistence.

```csharp
public interface ISettingsService
{
    /// <summary>
    /// Loads settings from SQLite database
    /// </summary>
    Task<Settings> LoadSettingsAsync();

    /// <summary>
    /// Saves settings to database
    /// </summary>
    Task SaveSettingsAsync(Settings settings);

    /// <summary>
    /// Resets settings to defaults
    /// </summary>
    Task ResetToDefaultsAsync();

    /// <summary>
    /// Gets a specific setting value
    /// </summary>
    Task<T> GetSettingAsync<T>(string key, T defaultValue = default);

    /// <summary>
    /// Sets a specific setting value
    /// </summary>
    Task SetSettingAsync<T>(string key, T value);
}
```

### IStatsService

Tracks usage statistics.

```csharp
public interface IStatsService
{
    /// <summary>
    /// Records a tool execution
    /// </summary>
    Task RecordExecutionAsync(UsageStatistic stat);

    /// <summary>
    /// Gets most frequently used tools
    /// </summary>
    Task<List<UsageStatistic>> GetTopToolsAsync(int count = 10);

    /// <summary>
    /// Gets execution history for a specific tool
    /// </summary>
    Task<List<UsageStatistic>> GetToolHistoryAsync(string toolId, int limit = 50);

    /// <summary>
    /// Gets total execution count for all tools
    /// </summary>
    Task<int> GetTotalExecutionCountAsync();

    /// <summary>
    /// Gets success rate percentage
    /// </summary>
    Task<double> GetSuccessRateAsync();

    /// <summary>
    /// Clears old statistics (older than X days)
    /// </summary>
    Task CleanOldStatsAsync(int retentionDays = 90);
}
```

### ICacheService

Manages local file caching.

```csharp
public interface ICacheService
{
    /// <summary>
    /// Gets cached file path if exists and not expired
    /// </summary>
    string GetCachedFilePath(string relativePath);

    /// <summary>
    /// Caches a file locally
    /// </summary>
    Task CacheFileAsync(string relativePath, string content);

    /// <summary>
    /// Checks if file is cached and valid
    /// </summary>
    bool IsCached(string relativePath);

    /// <summary>
    /// Clears all cached files
    /// </summary>
    Task ClearCacheAsync();

    /// <summary>
    /// Clears expired cache files
    /// </summary>
    Task CleanExpiredCacheAsync();

    /// <summary>
    /// Gets cache directory size
    /// </summary>
    long GetCacheSizeBytes();
}
```

---

## UI/UX Design

### Main Window Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  [B] Bepoz Toolkit v2.0        [Ctrl+K: Search...]    [D/L] [_][X] │
│      ^^^^^^^^^^^^                ^^^^^^^^^^^^^^^^       ^^^^         │
│      Logo + title               Command palette        Dark/Light   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Dashboard]  [Tools]  [Logs]  [Settings]     <-- animated underline │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                                                                │ │
│  │         ACTIVE TAB CONTENT (slide/fade transition)             │ │
│  │                                                                │ │
│  │                                                                │ │
│  │                                                                │ │
│  │                                                                │ │
│  │                                                                │ │
│  │                                             ┌──────────┐      │ │
│  │                                             │  [+] FAB │      │ │
│  │                                             └──────────┘      │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─ Status Bar ────────────────────────────────────────────────────┐ │
│  │ [*] GitHub: Connected  [*] Cache: 12 files (2.4 MB)  [*] PS 7 │ │
│  │ Last sync: 2m ago         ^^^ health status pills (green/red)  │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌─ Toast Region (top-right overlay, auto-dismiss) ──────┐         │
│  │  "WeekSchedule Manager completed successfully"    [X]  │         │
│  └────────────────────────────────────────────────────────┘         │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
     ^^^ Mica/Acrylic translucent backdrop on Windows 11

[System tray icon: right-click for quick-launch menu]
```

### Dashboard Tab

Shows quick overview, sparkline trends, pinned favorites, and a live activity feed.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Dashboard                                                           │
│  ┌─ Quick Run ──────────────────────────────────────────────────────┐│
│  │  [WeekSchedule]  [Web API]  [TSPlus]  [+ Add]   <-- pinned fav  ││
│  └──────────────────────────────────────────────────────────────────┘│
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Quick Stats (animated count-up on load)                             │
│  ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐    │
│  │      47           │ │       12         │ │     98.3%        │    │
│  │   Total Runs      │ │     Tools        │ │    Success       │    │
│  │   ___/\__/\_      │ │                  │ │   _________      │    │
│  │   ^^^ sparkline   │ │   All Cached     │ │   ^^^ trend     │    │
│  │   (7-day trend)   │ │                  │ │   (30 days)      │    │
│  └──────────────────┘ └──────────────────┘ └──────────────────┘    │
│                                                                      │
│  Favorite Tools (drag-and-drop reorderable)        [Manage Favs]    │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │ [*] WeekSchedule Bulk Manager   (*) CACHED  [Run] 15x    │     │
│  │     Last: 10m ago               ^^^ green dot              │     │
│  ├────────────────────────────────────────────────────────────┤     │
│  │ [*] Web API Settings            (*) CACHED  [Run]  8x    │     │
│  │     Last: 2h ago                                           │     │
│  ├────────────────────────────────────────────────────────────┤     │
│  │ [*] TSPlus Manager              (o) STALE   [Run]  6x    │     │
│  │     Last: Yesterday             ^^^ amber dot              │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                      │
│  Live Activity Feed (animated slide-in, newest on top)               │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │  [+] WeekSchedule Bulk Manager completed        2m ago    │     │
│  │      Duration: 1m 23s | Status: SUCCESS                    │     │
│  │  [+] Web API Settings completed                 1h ago    │     │
│  │      Duration: 45s    | Status: SUCCESS                    │     │
│  │  [~] Tools catalog refreshed from GitHub        2h ago    │     │
│  │      12 tools synced | 0 new | 2 updated                  │     │
│  │  [!] TSPlus Installer failed                    3h ago    │     │
│  │      Error: HTTP 404 | Click to view details               │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Tools Tab

Browse, search, favorite, and launch tools. Supports right-click context menus and batch selection.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Tools > All Categories              <-- breadcrumb (click to nav)   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [Search tools... (Ctrl+K)]                  [Refresh] [Grid|List]  │
│                                                                      │
│  Category: [All v] | Requires: [Any v] | Status: [Any v]  [x Clear] │
│  [*Favorites] [All] [Scheduling] [System] [Network]  <-- pill tabs  │
│                                                                      │
│  ┌─ SCHEDULING (4 tools) ────────────────────────────────────────┐  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │ [*]  WeekSchedule Bulk Manager               v2.0.4    │ │  │
│  │  │ ^^^                                                      │ │  │
│  │  │ star                                                     │ │  │
│  │  │  Bulk insertion/update/deletion of WeekSchedule records  │ │  │
│  │  │                                                          │ │  │
│  │  │  (*) Cached  |  DB Required  |  No Admin   | 2 days ago │ │  │
│  │  │  ^^^ green pulsing dot if running, static if cached      │ │  │
│  │  │                                                          │ │  │
│  │  │  [>>> Run]   [Docs]   [View Source]                     │ │  │
│  │  │  ^^^ primary action with ripple effect                   │ │  │
│  │  │                                                          │ │  │
│  │  │  Right-click context menu:                               │ │  │
│  │  │    > Run                                                 │ │  │
│  │  │    > Run as Administrator                                │ │  │
│  │  │    > Add to Favorites                                    │ │  │
│  │  │    > View Source on GitHub                               │ │  │
│  │  │    > Copy Script Path                                    │ │  │
│  │  │    > Clear Cache for This Tool                           │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  │                                                                │  │
│  │  ┌──────────────────────────────────────────────────────────┐ │  │
│  │  │ [ ]  WeekSchedule Export Tool                    v1.2.0 │ │  │
│  │  │      Export scheduling data to CSV/Excel                 │ │  │
│  │  │      (o) Stale  |  DB Required  |  No Admin             │ │  │
│  │  │      [>>> Run]  [Docs]                                  │ │  │
│  │  └──────────────────────────────────────────────────────────┘ │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─ SYSTEM CONFIGURATION (3 tools) ──────────────────────────────┐  │
│  │  ... (collapsible category groups)                             │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─ Batch Actions (visible when checkboxes selected) ────────────┐  │
│  │  [3 selected]   [Run All]   [Run Sequentially]   [Deselect]   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Hover any card: description expands with smooth animation           │
│  Loading state: skeleton shimmer cards instead of spinners           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Tool Execution Window

Shows real-time output in a split pane with ANSI color support, searchable output, and picture-in-picture mode.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Tools > Scheduling > WeekSchedule Bulk Manager       [PiP] [_] [X] │
│  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^          ^^^           │
│  breadcrumb trail                                      picture-in-   │
│                                                        picture btn   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Status: Running...    Elapsed: 00:01:23    [Stop]  [Restart]        │
│  [====================----------] 65%  (animated gradient progress)   │
│                                                                      │
│  ┌─ Output (Ctrl+F to search) ──────────┬─ State & Variables ─────┐ │
│  │                                       │                         │ │
│  │  [12:34:56] Bepoz Toolkit -           │  Modules Loaded:       │ │
│  │    WeekSchedule Manager               │   [*] BepozDbCore 1.3  │ │
│  │  [12:34:57] Loading modules...        │   [*] BepozLogger 1.0  │ │
│  │  [12:34:58] BepozDbCore v1.3.1        │   [*] BepozUI 1.0      │ │
│  │    loaded  (green text)               │                         │ │
│  │  [12:34:58] BepozLogger v1.0.1        │  Variables:            │ │
│  │    loaded  (green text)               │   $Server = BEPOZ-SQL  │ │
│  │  [12:34:59] BepozUI v1.0.0 loaded     │   $Database = BepozDB  │ │
│  │  [12:35:00] Connecting to DB...       │   $RecordCount = 147   │ │
│  │  [12:35:01] Connected!                │                         │ │
│  │    (green bold)                       │  Environment:           │ │
│  │  [12:35:02] Loading GUI...            │   PS: 7.4.1            │ │
│  │                                       │   User: BEPOZ\admin    │ │
│  │  >>> GUI window opened - check your   │   Admin: No            │ │
│  │      taskbar  (amber warning text)    │                         │ │
│  │                                       │                         │ │
│  │  ┌─ 12:34 ──────────────────┐        │                         │ │
│  │  │ (collapsible timestamp   │        │                         │ │
│  │  │  section - click to fold)│        │                         │ │
│  │  └──────────────────────────┘        │                         │ │
│  │                                       │                         │ │
│  │  [Search: _______________] [Prev][Nxt]│                         │ │
│  └───────────────────────────────────────┴─────────────────────────┘ │
│                                                                      │
│  [Copy Output]  [Save Log]  [Export CSV]  [Open in External Editor]  │
│                                                                      │
│  Completion: success = green flash + confetti burst                  │
│              failure = red flash + gentle horizontal shake            │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

Picture-in-Picture Mode (when browsing other tools):
┌─────────────────────────┐
│ WeekSchedule... Running │
│ [==========---] 65%     │
│ Last: Loading GUI...    │
│ [Expand]  [Stop]        │
└─────────────────────────┘
  ^^^ draggable mini-window, always on top
```

### Logs Tab

View historical logs with color-coded levels, inline search, and virtualized scrolling for performance.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Logs                                          [Search logs... Ctrl+F]│
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  [All Levels v] [All Tools v] [Today v]  [Clear Logs] [Export CSV]  │
│                                                                      │
│  Level pills:  [ALL] [INFO] [SUCCESS] [WARN] [ERROR]  <-- toggleable│
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Timestamp           Level      Tool                 Duration  │ │
│  │ ─────────────────────────────────────────────────────────────│ │
│  │ 2026-02-12 12:35:02 [INFO]     WeekSchedule Manager          │ │
│  │   GUI window opened                                           │ │
│  │   (color: blue background tint)                               │ │
│  │                                                                │ │
│  │ 2026-02-12 12:35:01 [SUCCESS]  WeekSchedule Manager  1m 23s  │ │
│  │   Database connection established                             │ │
│  │   Server: BEPOZ-SQL01, Database: BepozProd                   │ │
│  │   (color: green background tint)                              │ │
│  │                                                                │ │
│  │ 2026-02-12 12:34:58 [INFO]     WeekSchedule Manager          │ │
│  │   Loading modules...                                          │ │
│  │                                                                │ │
│  │ 2026-02-12 10:15:43 [SUCCESS]  Web API Settings       45s    │ │
│  │   Firewall rule created: BepozWebApi-8080                    │ │
│  │                                                                │ │
│  │ 2026-02-12 09:22:11 [ERROR]    TSPlus Installer               │ │
│  │   Download failed: HTTP 404                                   │ │
│  │   Stack: File not found on server                            │ │
│  │   [Copy Error] [Retry Tool]   <-- inline actions              │ │
│  │   (color: red background tint, bold)                          │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  Showing 47 entries | Filtered: All | Virtualized scroll             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Settings Tab

Configure launcher behavior. Settings auto-save with toast confirmation. Smooth theme transitions.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Settings                                              [Auto-saved]  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─ Appearance & Behavior ───────────────────────────────────────┐  │
│  │                                                                │  │
│  │  Theme:   [Light]  [Dark]  [Bepoz]   <-- toggle with preview  │  │
│  │            ^^^^     ^^^^    ^^^^^^                              │  │
│  │           visual preview thumbnails, active one highlighted    │  │
│  │           Smooth 300ms crossfade transition on switch          │  │
│  │                                                                │  │
│  │  [*] Enable UI animations               (toggle switch)       │  │
│  │  [*] Enable toast notifications          (toggle switch)       │  │
│  │  [*] Minimize to system tray on close    (toggle switch)       │  │
│  │  [ ] Confirm before running tools        (toggle switch)       │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─ GitHub Configuration ────────────────────────────────────────┐  │
│  │                                                                │  │
│  │  Repository Owner:  [StephenShawBepoz_______________]         │  │
│  │  Repository Name:   [bepoz-toolkit__________________]         │  │
│  │  Branch:            [main___________________________]         │  │
│  │                                                                │  │
│  │  Cache Expiration:  [60] minutes    [---|----*----] slider     │  │
│  │                                                                │  │
│  │  [*] Check for updates on startup                              │  │
│  │  [*] Enable usage tracking                                     │  │
│  │                                                                │  │
│  │  Connection: [*] Connected          <-- live status pill       │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─ Database Configuration ──────────────────────────────────────┐  │
│  │                                                                │  │
│  │  Server:   [________________________________]                  │  │
│  │  Database: [________________________________]                  │  │
│  │                                                                │  │
│  │  [Test Connection]    Result: [*] Connected (120ms)            │  │
│  │                       ^^^ inline result, no popup dialog       │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─ Advanced ────────────────────────────────────────────────────┐  │
│  │                                                                │  │
│  │  Log Level: [Information v]                                    │  │
│  │  [*] Enable logging                                            │  │
│  │                                                                │  │
│  │  Cache Directory: C:\Users\...\BepozToolkit\Cache             │  │
│  │  Cache Size: 2.4 MB (12 files)       [Clear Cache]            │  │
│  │                                                                │  │
│  │  Keyboard Shortcuts:                                           │  │
│  │    Ctrl+K  Command palette        ?  Show all shortcuts       │  │
│  │    Ctrl+F  Search in output       Ctrl+R  Refresh tools       │  │
│  │    Ctrl+1  Dashboard tab          Ctrl+2  Tools tab           │  │
│  │    Ctrl+3  Logs tab               Ctrl+4  Settings tab        │  │
│  │    Esc     Close overlay/dialog                                │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  [Reset to Defaults]                                                 │
│  ^^^ single destructive action, confirms via toast not dialog        │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Command Palette Overlay (Ctrl+K)

A VS Code-style quick-launch overlay for power users. Appears as a centered floating modal with backdrop blur.

```
                  ┌────────────────────────────────────────────┐
                  │  [> Search tools, commands, settings...]    │
                  ├────────────────────────────────────────────┤
                  │                                            │
                  │   Recently Used                            │
                  │   > WeekSchedule Bulk Manager     [Run]   │
                  │   > Web API Settings              [Run]   │
                  │                                            │
                  │   Commands                                 │
                  │   > Refresh tool catalog                   │
                  │   > Clear cache                            │
                  │   > Open settings                          │
                  │   > Toggle dark mode                       │
                  │   > Check for updates                      │
                  │                                            │
                  │   Navigation                               │
                  │   > Go to Dashboard                        │
                  │   > Go to Logs                             │
                  │                                            │
                  │   Results update as you type (fuzzy match) │
                  │   Arrow keys to navigate, Enter to select  │
                  │   Esc to dismiss                           │
                  │                                            │
                  └────────────────────────────────────────────┘
                  ^^^ backdrop: blurred + dimmed main window
```

### Keyboard Shortcuts Overlay (Press ?)

Displayed as a centered modal when the user presses `?` from any tab.

```
                  ┌────────────────────────────────────────────┐
                  │       Keyboard Shortcuts                    │
                  ├────────────────────────────────────────────┤
                  │                                            │
                  │  Navigation                                │
                  │    Ctrl+1      Dashboard                   │
                  │    Ctrl+2      Tools                       │
                  │    Ctrl+3      Logs                        │
                  │    Ctrl+4      Settings                    │
                  │    Ctrl+K      Command Palette             │
                  │                                            │
                  │  Tools                                     │
                  │    Ctrl+R      Refresh catalog             │
                  │    Ctrl+F      Search / Find in output     │
                  │    Enter       Run selected tool           │
                  │    Ctrl+Shift+Enter  Run as Admin          │
                  │                                            │
                  │  General                                   │
                  │    Ctrl+D      Toggle Dark/Light mode      │
                  │    Esc         Close overlay / Cancel      │
                  │    ?           Show this help              │
                  │                                            │
                  │              [Got it]                       │
                  └────────────────────────────────────────────┘
```

---

## UI Enhancement Directives (Agent 1)

> **Purpose:** These are binding directives for Agent 2 (the coder). Each directive is numbered, prioritized, and includes specific implementation guidance. Items marked **(MUST)** are non-negotiable for launch. Items marked **(SHOULD)** are strongly recommended. Items marked **(NICE)** are stretch goals if time permits.

---

### Directive 1: Window Chrome and Backdrop (MUST)

**What:** Replace default WPF window chrome with a custom borderless window that uses Mica/Acrylic translucent backdrop on Windows 11, falling back gracefully to solid color on Windows 10.

**Implementation:**
- Use `WindowChrome` class with `GlassFrameThickness = -1` for extending into the title bar area.
- On Windows 11 (build 22000+), call `DwmSetWindowAttribute` with `DWMWA_SYSTEMBACKDROP_TYPE = 2` (Mica) via P/Invoke.
- On Windows 10, fall back to a solid `#F3F3F3` (light) or `#1E1E1E` (dark) background.
- The title bar must contain: Bepoz logo (left), app title, command palette trigger button (center-ish), dark/light toggle (right), standard window buttons (right).
- Window must remember its position, size, and maximized state across sessions using `WindowPositionManager.cs`. Persist to SQLite Settings table.

**Files affected:** `MainWindow.xaml`, `MainWindow.xaml.cs`, `App.xaml`, `Helpers/WindowPositionManager.cs`

---

### Directive 2: Dark/Light/Bepoz Theme System (MUST)

**What:** Implement a three-mode theme system (Light, Dark, Bepoz-branded) with smooth 300ms crossfade transition when switching.

**Implementation:**
- Create three ResourceDictionary files: `LightTheme.xaml`, `DarkTheme.xaml`, `BepozTheme.xaml`.
- Each defines the same set of brush keys: `BackgroundPrimary`, `BackgroundSecondary`, `TextPrimary`, `TextSecondary`, `AccentPrimary`, `AccentSecondary`, `CardBackground`, `CardBorder`, `SuccessColor`, `ErrorColor`, `WarningColor`, `InfoColor`.
- Bepoz theme uses the company brand colors (derive from existing PS1 GUI: likely navy/blue accent with white cards).
- On theme switch, use a `DoubleAnimation` on a root-level `OpacityMask` or swap `ResourceDictionary` in `Application.Current.Resources.MergedDictionaries` and animate opacity from 0.7 to 1.0 over 300ms for a crossfade effect.
- Persist the selected theme in Settings. Apply on startup before the main window renders (in `App.xaml.cs` `OnStartup`).
- The dark/light toggle in the title bar must be a simple icon button (sun/moon icon) that cycles through: Light -> Dark -> Bepoz -> Light.

**Files affected:** `Themes/LightTheme.xaml`, `Themes/DarkTheme.xaml`, `Themes/BepozTheme.xaml`, `App.xaml.cs`, `Resources/Styles.xaml`

---

### Directive 3: Animated Tab Transitions (MUST)

**What:** When switching between Dashboard, Tools, Logs, and Settings tabs, the content must slide and fade rather than instantly swap.

**Implementation:**
- Use a `Frame` or `TransitioningContentControl` (from MaterialDesignThemes) as the tab content host.
- On tab change, the outgoing content slides left and fades out (150ms), then the incoming content slides in from the right and fades in (150ms). Total transition: 300ms.
- Use `TranslateTransform` + `DoubleAnimation` for the slide, and `OpacityAnimation` for the fade.
- If `Settings.EnableAnimations == false`, skip animations and swap instantly.
- Define these animations in `Animations/TabTransitions.xaml` as reusable `Storyboard` resources.

**Files affected:** `MainWindow.xaml`, `Animations/TabTransitions.xaml`, `ViewModels/MainViewModel.cs`

---

### Directive 4: Skeleton Loading States (MUST)

**What:** When data is loading (tools catalog, dashboard stats, logs), show animated skeleton placeholder cards instead of spinners or blank space.

**Implementation:**
- Create a `SkeletonLoader.xaml` custom control that renders gray rounded rectangles with a left-to-right shimmer gradient animation.
- The shimmer uses a `LinearGradientBrush` animated with `DoubleAnimation` on `GradientStop.Offset`, cycling every 1.5 seconds.
- Create skeleton variants: `SkeletonToolCard` (mimics tool card shape), `SkeletonStatCard` (mimics stat card shape), `SkeletonLogRow` (mimics log row shape).
- In each ViewModel, expose an `IsLoading` boolean. The View uses a `DataTrigger` to swap between skeleton and real content.
- Skeleton cards should be the same dimensions as real cards to prevent layout shift.

**Files affected:** `Controls/SkeletonLoader.xaml`, `Animations/SkeletonShimmer.xaml`, all View XAML files

---

### Directive 5: Toast Notification System (MUST)

**What:** Replace all `MessageBox.Show()` calls with non-blocking toast notifications that slide in from the top-right corner and auto-dismiss.

**Implementation:**
- Use `Notification.Wpf` NuGet package OR build a custom `ToastNotification.xaml` control.
- Toasts appear in a fixed overlay region at top-right of the main window, stacking vertically.
- Four toast types: `Success` (green accent), `Error` (red accent), `Warning` (amber accent), `Info` (blue accent).
- Each toast shows an icon, title, message, and optional action button (e.g., "Retry", "View Details").
- Auto-dismiss after 5 seconds (configurable). Manual dismiss via X button. Error toasts persist until dismissed.
- Toasts slide in from right (200ms ease-out) and fade out when dismissing (150ms).
- Create an `IToastService` interface registered in DI, so any ViewModel can call `_toastService.Show("Title", "Message", ToastType.Success)`.
- **CRITICAL:** No `MessageBox.Show()` anywhere in the codebase. Every notification goes through toast.

**Files affected:** `Controls/ToastNotification.xaml`, new `Services/IToastService.cs`, `Services/ToastService.cs`, `MainWindow.xaml` (overlay host)

---

### Directive 6: Command Palette (MUST)

**What:** Implement a VS Code / Spotlight-style command palette triggered by `Ctrl+K` that allows quick searching and launching of tools, commands, and navigation targets.

**Implementation:**
- Create `CommandPalette.xaml` as a centered overlay (not a new window) with backdrop blur/dim.
- The overlay appears with a 150ms scale-up + fade-in animation from 95% to 100% scale.
- At the top: a search `TextBox` with auto-focus and placeholder text "> Search tools, commands, settings...".
- Below: a virtualized `ListView` of results, grouped by category: "Recently Used", "Tools", "Commands", "Navigation".
- Fuzzy matching on tool names, categories, and command descriptions as the user types.
- Arrow keys navigate results, Enter executes, Esc dismisses.
- Commands include: "Refresh tool catalog", "Clear cache", "Toggle dark mode", "Open settings", "Check for updates".
- Register `Ctrl+K` as a global `KeyBinding` on `MainWindow`.
- Create a `CommandPaletteViewModel` with `ObservableCollection<CommandPaletteItem>` that filters on `SearchQuery` changes.

**Files affected:** `Controls/CommandPalette.xaml`, `ViewModels/CommandPaletteViewModel.cs`, `MainWindow.xaml` (keybinding + overlay host)

---

### Directive 7: Tool Card Redesign (MUST)

**What:** Redesign tool cards with hover expansion, visual status indicators, star/favorite toggle, and right-click context menu.

**Implementation:**
- **Card Layout:** Each card is a `Border` with `CornerRadius="8"`, subtle `DropShadowEffect`, and the theme's `CardBackground` brush. On mouse hover, the shadow deepens and the card elevates slightly (translate Y by -2px, 150ms animation).
- **Star/Favorite:** A star icon (outline when not favorited, filled yellow when favorited) at the top-left of each card. Click to toggle. Persisted to `Settings.FavoriteToolIds`.
- **Status Indicator:** A small colored dot next to the tool name. Green = cached and ready. Amber = stale (cache expired). Gray = not cached. Pulsing green animation = currently running. Red = last run failed. Use `StatusToPulseConverter.cs` and a `ColorAnimation` for the pulse.
- **Hover Expansion:** On hover, the tool description area expands from 2 lines (truncated with ellipsis) to full text using a `MaxHeight` animation over 200ms.
- **Right-Click Context Menu:** `ContextMenu` with items: Run, Run as Administrator (with shield icon), Add/Remove Favorite, View Source on GitHub (opens browser), Copy Script Path (to clipboard), Clear Cache for This Tool.
- **Checkbox for batch selection:** Optional checkbox at top-right. When any checkbox is checked, a batch action bar slides up from the bottom: "[N selected] [Run All] [Run Sequentially] [Deselect All]".

**Files affected:** `Controls/ToolCard.xaml`, `Controls/ToolCard.xaml.cs`, `ViewModels/ToolsViewModel.cs`, `Converters/StatusToPulseConverter.cs`

---

### Directive 8: Dashboard Sparkline Charts (SHOULD)

**What:** Each stat card on the Dashboard (Total Runs, Success Rate) includes a mini sparkline chart showing the trend over the last 7 or 30 days.

**Implementation:**
- Use `LiveCharts2` NuGet package with the `CartesianChart` control configured for sparkline mode (no axes, no labels, no legend, just the line).
- `SparklineChart.xaml` wraps a `CartesianChart` with: `LineSeries` with `GeometrySize=0`, `StrokeThickness=2`, `Fill=transparent`, smooth `LineSmoothness=0.6`.
- The chart is 120px wide x 40px tall, positioned below the stat number inside the stat card.
- Data comes from `IStatsService.GetDailyExecutionCountsAsync(int days)` (new method to add to the interface).
- The line color matches the stat card's accent (blue for total runs, green for success rate).
- Animate the line drawing in from left to right on first render (300ms).

**Files affected:** `Controls/SparklineChart.xaml`, `Views/DashboardView.xaml`, `ViewModels/DashboardViewModel.cs`, `Services/IStatsService.cs` (add new method)

---

### Directive 9: Live Activity Feed with Animations (SHOULD)

**What:** The Dashboard's "Recent Activity" section is a live-updating feed where new entries slide in from the top with animation.

**Implementation:**
- Use an `ItemsControl` bound to an `ObservableCollection<ActivityFeedItem>` in `DashboardViewModel`.
- When a new item is added to the collection, it triggers a `Loaded` event animation: slide from Y=20 to Y=0 + fade from opacity 0 to 1 (200ms ease-out).
- Each feed item shows: icon (colored by type: success=green check, error=red X, info=blue circle), tool name, description, relative timestamp ("2m ago"), and optional detail line.
- Poll for new data every 30 seconds or subscribe to `IStatsService` events.
- Maximum 20 items displayed; virtualize if more.
- Clicking an error entry opens the log detail for that execution.

**Files affected:** `Views/DashboardView.xaml`, `ViewModels/DashboardViewModel.cs`, `Models/ActivityFeedItem.cs`

---

### Directive 10: Drag-and-Drop Favorite Pinning (SHOULD)

**What:** Users can drag tool cards to rearrange their favorites on the Dashboard, and drag tools from the Tools tab to the Dashboard's "Quick Run" bar to pin them.

**Implementation:**
- Implement `DragDrop` behavior using WPF's built-in `DragDrop.DoDragDrop`.
- On the Dashboard "Quick Run" bar, tool chips are reorderable via drag. Show a blue insertion indicator line during drag.
- On the Tools tab, each tool card supports `DragStarted` to initiate a drag. The Dashboard's Quick Run bar accepts drops.
- On drop, add the tool's ID to `Settings.PinnedToolIds` and persist.
- Add a visual drag ghost: a semi-transparent copy of the tool card follows the cursor during drag.
- The "Quick Run" bar shows `[+ Add]` as a drop target placeholder when empty.

**Files affected:** `Views/DashboardView.xaml`, `Views/ToolsView.xaml`, `Controls/ToolCard.xaml.cs`, `ViewModels/DashboardViewModel.cs`

---

### Directive 11: Split-Pane Execution Window (MUST)

**What:** The tool execution window uses a resizable split pane: output log on the left (70%), live state/variables on the right (30%).

**Implementation:**
- Use a `Grid` with `GridSplitter` for the resizable split. Default ratio 70/30, user-adjustable.
- **Left pane (Output):** A `RichTextBox` or `FlowDocumentScrollViewer` with ANSI color code parsing. Map common ANSI codes to WPF `Foreground` brushes (red for errors, green for success, yellow for warnings, cyan for info). Use a custom `AnsiColorParser` helper class.
- **Right pane (State):** Shows three collapsible sections: "Modules Loaded" (list with checkmarks), "Variables" (key-value pairs updated in real-time from PowerShell runspace), "Environment" (PS version, user, admin status).
- **Search in output:** `Ctrl+F` shows a search bar at the top of the output pane. Highlights all matches in yellow. "Next" and "Previous" buttons to jump between matches.
- **Collapsible timestamp sections:** Group output lines by minute. Each minute group has a clickable header "[12:34]" that collapses/expands all lines in that minute.
- **Breadcrumb trail:** At the top of the execution window: `Tools > [Category] > [Tool Name]`. Each segment is clickable to navigate back.

**Files affected:** `Views/ToolExecutionWindow.xaml`, `ViewModels/ToolExecutionViewModel.cs`, `Helpers/AnsiColorParser.cs`

---

### Directive 12: Picture-in-Picture Mode (SHOULD)

**What:** When a tool is running and the user navigates away (back to Tools or Dashboard), the execution output continues in a small floating mini-window.

**Implementation:**
- Add a "PiP" button in the execution window title bar.
- When clicked, the full execution window minimizes and a `Popup` or small `Window` (200x120px) appears at the bottom-right of the main window.
- The mini-window shows: tool name (truncated), progress bar, last output line, and [Expand] [Stop] buttons.
- The mini-window is draggable (implement `MouseLeftButtonDown` + `DragMove`).
- When [Expand] is clicked, the mini-window closes and the full execution window restores.
- Only one PiP at a time. If a second tool starts, the first PiP is replaced.

**Files affected:** `Views/ToolExecutionWindow.xaml`, `Controls/PictureInPicture.xaml`, `ViewModels/ToolExecutionViewModel.cs`

---

### Directive 13: Button Ripple Effects (MUST)

**What:** All clickable buttons show a Material Design ripple effect on click.

**Implementation:**
- MaterialDesignThemes already includes ripple via `materialDesign:RippleAssist.IsDisabled="False"` on buttons. Ensure this is enabled globally.
- For custom buttons (FAB, tool card actions), wrap content in `materialDesign:Ripple` control.
- Ripple color should be a semi-transparent version of the button's accent color.
- If `Settings.EnableAnimations == false`, set `RippleAssist.IsDisabled="True"` globally.

**Files affected:** `Resources/Styles.xaml`, all button styles

---

### Directive 14: System Tray Icon (MUST)

**What:** When the application is minimized or closed (if "minimize to tray" is enabled), it sits in the Windows system tray with a context menu for quick actions.

**Implementation:**
- Use `System.Windows.Forms.NotifyIcon` (add reference to `System.Windows.Forms`) or the `Hardcodet.NotifyIcon.Wpf` NuGet package (preferred, WPF-native).
- Tray icon uses the Bepoz logo.
- Right-click context menu items: "Open Bepoz Toolkit", separator, "Run [Favorite 1]", "Run [Favorite 2]", "Run [Favorite 3]" (dynamically populated from favorites), separator, "Refresh Tools", "Check for Updates", separator, "Exit".
- Double-click tray icon: restore main window.
- When `Settings.MinimizeToSystemTray == true`: clicking the window X button hides to tray instead of closing. The app truly exits only via tray menu "Exit" or `Alt+F4` when window is visible.
- Show a balloon tooltip on first minimize: "Bepoz Toolkit is still running in the system tray."
- Create `Helpers/SystemTrayManager.cs` to encapsulate all tray logic.

**Files affected:** `Helpers/SystemTrayManager.cs`, `MainWindow.xaml.cs`, `App.xaml.cs`

---

### Directive 15: Keyboard Navigation and Accessibility (MUST)

**What:** The entire application must be fully navigable via keyboard. No mouse-only interactions.

**Implementation:**
- All tabs navigable via `Ctrl+1` through `Ctrl+4`. Register `InputBindings` on `MainWindow`.
- Tool cards are focusable (`Focusable="True"`) and navigable via `Tab` and `Arrow` keys within the tools list.
- Pressing `Enter` on a focused tool card runs it. `Space` toggles the favorite star.
- The command palette is `Ctrl+K`. Pressing `?` shows the keyboard shortcuts overlay.
- `Ctrl+R` refreshes the tool catalog from any tab.
- `Ctrl+F` opens search (in output pane when execution window is open, in logs when logs tab is active).
- `Ctrl+D` toggles dark/light mode.
- `Esc` closes any open overlay (command palette, shortcuts overlay, search bar, PiP).
- All custom controls must have `AutomationProperties.Name` set for screen reader support.
- Tab order must be logical (left-to-right, top-to-bottom).
- Focus indicators: a visible blue outline (`FocusVisualStyle`) on every focusable element.

**Files affected:** `MainWindow.xaml`, all View XAML files, `Resources/Styles.xaml`

---

### Directive 16: Status Bar with Health Indicators (MUST)

**What:** The bottom status bar shows live health indicators for GitHub connectivity, cache status, and PowerShell version.

**Implementation:**
- Create `StatusPill.xaml` control: a small rounded rectangle with a colored dot and label.
- Three health indicators:
  1. **GitHub:** Green = connected (last fetch < 5 min ago), Amber = degraded (last fetch > 5 min ago), Red = disconnected (fetch failed). Ping on startup and every 5 minutes.
  2. **Cache:** Shows count and size. Green = all tools cached, Amber = some expired, Red = cache empty.
  3. **PowerShell:** Shows version. Green = 7.x detected, Amber = 5.1 (older), Red = not found.
- Status bar also shows: "Last sync: Xm ago" with relative time that updates every minute.
- Clicking a status pill opens a tooltip or popover with details (e.g., "GitHub: Connected to StephenShawBepoz/bepoz-toolkit, Branch: main, Rate limit: 47/60 remaining").

**Files affected:** `Controls/StatusPill.xaml`, `MainWindow.xaml`, `ViewModels/MainViewModel.cs`

---

### Directive 17: Floating Action Button (SHOULD)

**What:** A floating action button (FAB) in the bottom-right of the main content area provides quick access to the primary action of the current tab.

**Implementation:**
- On Dashboard: FAB = "Refresh" (sync icon). Clicking refreshes the tool catalog.
- On Tools: FAB = "Run" (play icon). Clicking runs the currently selected/focused tool.
- On Logs: FAB = "Export" (download icon). Clicking exports logs to CSV.
- On Settings: No FAB (settings auto-save).
- FAB is a circular 56px button with `DropShadowEffect`, positioned 24px from bottom-right.
- On hover, FAB scales to 110% (100ms). On click, ripple + slight scale-down (95%) then back.
- FAB icon changes with a rotation animation (180deg) when switching tabs.

**Files affected:** `Controls/FloatingActionButton.xaml`, `MainWindow.xaml`, `ViewModels/MainViewModel.cs`

---

### Directive 18: Success/Failure Micro-Animations (SHOULD)

**What:** When a tool execution completes, provide satisfying visual feedback.

**Implementation:**
- **Success:** Brief green flash overlay (opacity 0 -> 0.15 -> 0 over 400ms) on the execution window, plus a small confetti burst animation (5-10 colored dots that scatter and fade from the center, 600ms). Use `Canvas` with `EllipseGeometry` particles animated via `Storyboard`.
- **Failure:** Brief red flash overlay (same timing), plus a horizontal shake animation on the window (translate X: 0 -> -8 -> 8 -> -4 -> 4 -> 0 over 400ms, `ElasticEase`).
- Both animations are skippable if `Settings.EnableAnimations == false`.
- After the animation, auto-show a toast: "Tool completed successfully (1m 23s)" or "Tool failed: [error summary]".

**Files affected:** `Animations/SuccessShake.xaml`, `Views/ToolExecutionWindow.xaml`, `ViewModels/ToolExecutionViewModel.cs`

---

### Directive 19: High DPI and Scaling Support (MUST)

**What:** The application must render crisply on all display scaling levels (100%, 125%, 150%, 175%, 200%) and multi-monitor setups with different DPI.

**Implementation:**
- In `App.manifest`, set `<dpiAwareness>PerMonitorV2</dpiAwareness>`.
- All sizing should use device-independent pixels (WPF default). Avoid hardcoded pixel values for anything that must scale.
- All icons should be vector-based (XAML path icons from MaterialDesign) -- no raster images except the app icon.
- The app icon (`icon.ico`) must include sizes: 16x16, 24x24, 32x32, 48x48, 64x64, 128x128, 256x256.
- Test on 4K monitors at 150% and 200% scaling to verify no blurry text or clipped controls.
- `UseLayoutRounding="True"` and `SnapsToDevicePixels="True"` on the root element to prevent anti-aliasing blur on borders.

**Files affected:** `App.manifest`, `MainWindow.xaml`, `Resources/Icons.xaml`

---

### Directive 20: Smooth Scroll and Momentum (NICE)

**What:** All scrollable areas (tool list, logs, output) use smooth scrolling with momentum instead of the default WPF jump scroll.

**Implementation:**
- Create an attached behavior `SmoothScrollBehavior` that intercepts `PreviewMouseWheel` events.
- Instead of instant jump, animate `ScrollViewer.VerticalOffset` using `DoubleAnimation` over 200ms with `CubicEase.EaseOut`.
- Apply the behavior to all `ScrollViewer` elements and `ListBox`/`ListView` controls.
- Touch-screen support: enable `PanningMode="VerticalOnly"` on scroll viewers for inertial scrolling on tablets.

**Files affected:** `Helpers/SmoothScrollBehavior.cs`, `Resources/Styles.xaml` (apply globally via Style)

---

### Directive 21: Grid/List View Toggle for Tools (NICE)

**What:** The Tools tab offers a toggle between grid view (cards, the default) and compact list view (table rows) for users who prefer density.

**Implementation:**
- Add a two-button toggle in the Tools tab header: Grid icon | List icon.
- Grid view: current card layout (2-3 cards per row, wrapping).
- List view: a `DataGrid` with columns: Star, Name, Category, Version, Status, Last Updated, [Run].
- Persist the view preference in Settings.
- Animate the transition between views with a fade (200ms).

**Files affected:** `Views/ToolsView.xaml`, `ViewModels/ToolsViewModel.cs`

---

### Directive 22: Breadcrumb Navigation (SHOULD)

**What:** When the user drills into a specific category or tool execution, a breadcrumb bar shows the navigation path and allows clicking any segment to go back.

**Implementation:**
- Create `BreadcrumbBar.xaml`: a horizontal `StackPanel` of `TextBlock`/`Button` segments separated by `>` chevrons.
- Default state: `Dashboard` or `Tools`.
- After clicking a category: `Tools > Scheduling`.
- After running a tool: `Tools > Scheduling > WeekSchedule Bulk Manager`.
- Each segment is clickable. Clicking "Tools" from `Tools > Scheduling > WeekSchedule` goes back to the full tools list.
- Breadcrumb updates are animated: new segments slide in from the right (100ms).
- Integrate with `MainViewModel` navigation state.

**Files affected:** `Controls/BreadcrumbBar.xaml`, `MainWindow.xaml`, `ViewModels/MainViewModel.cs`

---

### Directive 23: ANSI Color Support in Output (MUST)

**What:** The tool execution output pane must correctly render ANSI escape codes for colored text, bold, and underline that PowerShell tools may emit.

**Implementation:**
- Create `Helpers/AnsiColorParser.cs` that takes a raw output string and returns a list of `Run` elements with appropriate `Foreground`, `FontWeight`, and `TextDecoration` properties.
- Support the 8 standard ANSI colors (30-37, 40-47), bright variants (90-97, 100-107), bold (1), underline (4), and reset (0).
- Feed the parsed `Run` elements into a `RichTextBox` or `FlowDocument` `Paragraph`.
- Do NOT strip ANSI codes and display raw escape sequences. If a code is unrecognized, strip it silently.
- This is essential because Bepoz PowerShell tools use `Write-Host -ForegroundColor` which maps to ANSI in PS 7.x.

**Files affected:** `Helpers/AnsiColorParser.cs`, `Views/ToolExecutionWindow.xaml`, `ViewModels/ToolExecutionViewModel.cs`

---

### Directive 24: Auto-Save Settings with Toast (SHOULD)

**What:** The Settings tab does not need Save/Cancel buttons. All settings changes auto-save with a debounced write and toast confirmation.

**Implementation:**
- In `SettingsViewModel`, use a debounce timer (500ms) on any property change. When the timer fires, call `ISettingsService.SaveSettingsAsync()`.
- On save, show a subtle toast: "Settings saved" (success, 2-second auto-dismiss).
- Remove the Save/Cancel buttons from the Settings UI. Keep only "Reset to Defaults" which shows a confirmation toast with [Undo] action (5-second window to undo before persisting the reset).
- Real-time validation: if the user enters an invalid value (e.g., non-numeric cache expiration), show an inline red error message below the field. Do not save until corrected.

**Files affected:** `ViewModels/SettingsViewModel.cs`, `Views/SettingsView.xaml`

---

### Priority Summary for Agent 2

| Priority | Directives | Description |
|----------|-----------|-------------|
| **P0 - MUST** (launch blockers) | 1, 2, 3, 4, 5, 6, 7, 11, 13, 14, 15, 16, 19, 23 | Core UI framework, theme, animations, accessibility, notifications |
| **P1 - SHOULD** (strongly recommended) | 8, 9, 10, 12, 17, 18, 22, 24 | Dashboard polish, drag-drop, PiP, FAB, breadcrumbs |
| **P2 - NICE** (stretch goals) | 20, 21 | Smooth scroll, grid/list toggle |

**Implementation order recommendation:** Start with Directives 1, 2, 19 (foundation: window, themes, DPI). Then 3, 4, 13 (core animations). Then 5, 6, 14, 15, 16 (infrastructure: toasts, command palette, tray, keyboard, status). Then 7, 11, 23 (tool cards and execution). Then P1 items. Then P2 if time permits.

---

## Devil's Advocate Review (Agent 3)

> **Purpose:** This section exists to protect Agent 2 from building a cathedral when the users need a shed. Every critique below is grounded in the reality that this is an internal IT tool for ~10-20 IT staff who currently use PowerShell scripts from a WinForms GUI to manage Bepoz POS systems. There are exactly **4 tools** in the manifest today. The timeline is **21 days**. The minimum hardware target is **512 MB RAM**. These are the constraints. Agent 1 appears to have forgotten some of them.

---

### Critique of Individual Directives

**1. Directive 1 (Window Chrome and Mica/Acrylic Backdrop) -- MUST status: CHALLENGED**

**Concern:** Mica/Acrylic requires P/Invoke calls to `DwmSetWindowAttribute` with undocumented (or semi-documented) Windows 11 API flags. This is fragile. Microsoft changes these APIs between Windows 11 builds, and the fallback behavior on Windows 10 and Windows Server 2019 (which is explicitly listed in system requirements) is a completely separate code path that doubles the testing surface. The IT staff deploying this tool are working on customer POS terminals, many of which run Windows 10 or Server 2019. You are asking Agent 2 to spend time making a translucent title bar that most target machines will never display.

**Recommendation:** MODIFY. Keep the custom `WindowChrome` for a borderless modern look. Drop the Mica/Acrylic P/Invoke entirely. Use a solid themed background that looks clean on every supported OS. If someone wants to add Mica later as a post-launch enhancement when the app is stable, fine. But not in a 21-day sprint.

---

**2. Directive 2 (Dark/Light/Bepoz Theme System) -- MUST status: PARTIALLY CHALLENGED**

**Concern:** Three themes is one too many for launch. The "Bepoz" theme is the brand theme -- that should be the default and primary. Having Light AND Dark AND Bepoz means Agent 2 must test every single view, control, and state across three complete color palettes. That is 3x the visual QA work. The 300ms crossfade animation on theme switch using `OpacityMask` or dictionary swapping with animated opacity is a known source of flickering and binding errors in WPF when resource dictionaries are swapped at runtime.

**Recommendation:** MODIFY. Ship with TWO themes: Bepoz Light (the default branded theme) and Bepoz Dark. Drop the generic "Light" theme -- it adds nothing over Bepoz Light. Simplify the transition to an instant swap (no animation). Users will switch themes once and forget about it. Nobody is sitting there toggling back and forth admiring the crossfade.

---

**3. Directive 3 (Animated Tab Transitions) -- MUST status: CHALLENGED**

**Concern:** This is marked MUST but it is purely cosmetic. Slide/fade transitions between tabs add zero functional value. The IT staff using this tool switch tabs to get to a tool and run it. They do not care if the content slides in from the right. More importantly, `TranslateTransform` + `DoubleAnimation` on tab content with complex layouts (DataGrids in Logs, ItemsControls in Tools) can cause visible stutter on lower-end hardware, especially when the animation triggers layout recalculation.

**Recommendation:** MODIFY to NICE. Implement as a stretch goal. For launch, use a simple instant swap or a minimal 100ms opacity fade. Do not invest time in slide animations for an internal tool.

---

**4. Directive 4 (Skeleton Loading States) -- MUST status: CHALLENGED**

**Concern:** The app has 4 tools. The manifest JSON is under 100 lines. Loading it from cache or even from GitHub takes well under 1 second. Who is seeing the skeleton loaders? Agent 1 is designing for a scenario where there are 200 tools and network fetches take 5 seconds. That scenario does not exist. Building three skeleton variants (ToolCard, StatCard, LogRow) with shimmer gradient animations is pure overhead. This is the kind of feature that looks great in a Dribbble mockup and adds nothing to an IT tool that loads in under a second.

**Recommendation:** CUT for launch. Use a simple "Loading..." text or a standard indeterminate progress bar. If the app ever scales to 50+ tools and the load time exceeds 2 seconds, revisit skeletons then.

---

**5. Directive 5 (Toast Notification System) -- MUST status: ACCEPTED WITH CONCERNS**

**Concern:** Replacing all `MessageBox.Show()` is a reasonable goal. But the directive says "No `MessageBox.Show()` anywhere in the codebase" as if MessageBox is poison. MessageBox is appropriate for truly critical confirmations: "Are you sure you want to reset all settings?" or "This tool requires admin privileges -- restart now?" Toast notifications auto-dismiss and can be missed. For destructive or security-sensitive actions, a modal confirmation dialog is the correct UX pattern.

**Recommendation:** MODIFY. Use toasts for informational messages (success, info, non-critical warnings). Keep modal dialogs for destructive confirmations (reset settings, clear all cache, restart as admin). The blanket "no MessageBox anywhere" rule will create UX problems where users miss critical notifications.

---

**6. Directive 6 (Command Palette) -- MUST status: CHALLENGED**

**Concern:** There are 4 tools. The command palette's "fuzzy matching on tool names" will fuzzy-match across a list that fits on a single screen without scrolling. The commands it offers ("Refresh tool catalog", "Clear cache", "Toggle dark mode") are all one or two clicks away in the existing UI. This is a feature that makes sense in VS Code where there are 500+ commands. In an app with 4 tools and 4 tabs, it is feature theater. It adds significant implementation complexity: a new ViewModel, a new overlay control with backdrop blur, keyboard trap management (focus must not escape the overlay), fuzzy matching algorithm, grouped and categorized results rendering.

**Recommendation:** MODIFY to NICE. Downgrade from MUST. The IT staff have a tools tab with a search box. That is sufficient for 4 tools. If the tool count grows to 20+, a command palette becomes useful. Until then, it is over-engineering.

---

**7. Directive 7 (Tool Card Redesign) -- MUST status: PARTIALLY ACCEPTED**

**Concern:** Most of this is reasonable (cards with status dots, star/favorite, context menu). But the specification is dangerously scope-heavy. Hover expansion animation, pulsing color animation for running status, batch selection with a sliding action bar, drag ghost for batch operations -- this is a lot of custom WPF control work for a list of 4 tools. The batch selection feature ("Run All", "Run Sequentially") implies parallel tool execution, which is a significant backend feature that is not specified anywhere in the PowerShell host service. You cannot batch-run tools if the `IPowerShellHost` only supports one runspace at a time.

**Recommendation:** MODIFY. Keep: card layout, star/favorite, status dot (static, not pulsing), right-click context menu. Cut for launch: hover expansion animation, pulsing animation, batch selection bar (the backend does not support it), drag ghost. These are all post-launch polish.

---

**8. Directive 8 (Dashboard Sparkline Charts) -- SHOULD status: CHALLENGED**

**Concern:** LiveCharts2 depends on SkiaSharp, which pulls in native platform-specific binaries (SkiaSharp.NativeAssets). This significantly increases the installer size and adds a native dependency that can cause DLL loading failures on locked-down corporate machines. All of this to show a tiny 120x40px line chart of "runs per day" for an app that probably sees 5-10 tool executions per day. The sparkline will be a nearly flat line with 7 data points.

**Recommendation:** CUT the LiveCharts2 dependency. If sparklines are truly wanted post-launch, draw them manually with a simple WPF `Polyline` control using the 7 data points from SQLite. That is about 30 lines of code and zero additional NuGet packages.

---

**9. Directive 9 (Live Activity Feed with Animations) -- SHOULD status: PARTIALLY ACCEPTED**

**Concern:** A recent activity list is useful. The "live updating" aspect with slide-in animations and 30-second polling is overkill. This is not a real-time monitoring dashboard. It is an IT tool that runs scripts. The activity feed will update when someone runs a tool, which happens a few times a day. Polling every 30 seconds for a feed that changes a few times daily is wasteful.

**Recommendation:** MODIFY. Keep the activity feed as a static list loaded on dashboard navigation. Drop the polling and slide-in animations. Update the list when the user navigates to the dashboard tab.

---

**10. Directive 10 (Drag-and-Drop Favorite Pinning) -- SHOULD status: CHALLENGED**

**Concern:** WPF drag-and-drop is one of the most frustrating APIs in the framework. Getting it right with visual drag ghosts, insertion indicators, and cross-tab drag (from Tools to Dashboard) is easily 2-3 days of work and testing by itself. The users have 4 tools. They can click a star to favorite them and the favorites appear at the top. Drag-and-drop reordering of 4 items is a solution to a problem that does not exist.

**Recommendation:** CUT. Replace with simple star/favorite toggle (already in Directive 7) and a "Pin to Dashboard" option in the right-click context menu. That gives users the same outcome with 10% of the implementation effort.

---

**11. Directive 11 (Split-Pane Execution Window) -- MUST status: PARTIALLY CHALLENGED**

**Concern:** The split-pane concept is sound -- output on the left, state on the right. But the specification layers on too many sub-features: resizable `GridSplitter`, ANSI color parsing, Ctrl+F search with highlight and prev/next navigation, collapsible timestamp sections, breadcrumb trail. Each of these is a meaningful feature in its own right. Collapsible timestamp sections (grouping output lines by minute with clickable fold/unfold) is particularly complex -- it requires parsing timestamps from output lines, grouping them, and managing an expand/collapse state tree. The "Variables" panel showing live PowerShell runspace variables in real-time is non-trivial to implement safely (reading from a running runspace can cause thread synchronization issues).

**Recommendation:** MODIFY. Keep: split-pane layout, basic output display, progress bar, stop/restart buttons. Move to SHOULD: ANSI color parsing (Directive 23 covers this separately anyway), Ctrl+F search. CUT: collapsible timestamp sections (complexity vs. value is terrible), live variables panel (thread safety nightmare; show static environment info instead). The breadcrumb trail is in Directive 22 -- do not double-count it.

---

**12. Directive 12 (Picture-in-Picture Mode) -- SHOULD status: CHALLENGED**

**Concern:** This is a miniature floating always-on-top draggable window that shows a progress bar and last output line of a running tool. This requires custom window management, z-order control (`Topmost`), drag behavior, and coordination between the mini-window and the full execution window. The tools in this toolkit typically open their own WinForms GUI (the WeekSchedule Manager opens a full Windows Forms dialog). The user is not "browsing other tools" while one runs -- they are interacting with the tool's own GUI. PiP solves a problem that does not actually occur in the current workflow.

**Recommendation:** CUT. The execution window can simply remain open. If the user wants to see other tabs while a tool runs, they can use the taskbar. PiP is solving an imagined problem for a significant implementation cost.

---

**13. Directive 13 (Button Ripple Effects) -- MUST status: CHALLENGED**

**Concern:** This is marked MUST. A Material Design ripple effect on button click is a MUST for an internal IT tool? This is pure decoration. MaterialDesignThemes provides ripple out of the box, so enabling it is trivial -- but the directive specifies custom ripple for non-standard buttons (FAB, tool card actions), which requires wrapping content in `materialDesign:Ripple` controls and managing the ripple color per-button.

**Recommendation:** MODIFY to NICE. If MaterialDesignThemes provides it for free on standard buttons, fine, leave it enabled. Do not spend any time implementing custom ripple on custom controls. It should take zero developer time, not appear as a MUST directive.

---

**14. Directive 14 (System Tray Icon) -- MUST status: ACCEPTED**

**Concern:** This is reasonable. System tray integration is a standard feature for a persistent launcher. The `Hardcodet.NotifyIcon.Wpf` package is well-maintained and this is straightforward.

**Recommendation:** KEEP as MUST. One note: the directive says tray menu should dynamically populate with favorites. For launch, use a static list of the top 3 most-used tools instead. Dynamic favorites in the tray menu adds unnecessary complexity for v1.

---

**15. Directive 15 (Keyboard Navigation and Accessibility) -- MUST status: ACCEPTED WITH CONCERNS**

**Concern:** Full keyboard navigation and accessibility are good goals. But the directive scope is enormous: `Ctrl+1` through `Ctrl+4` for tabs, `Enter` to run, `Space` to toggle favorite, `Ctrl+K` for command palette, `?` for shortcuts overlay, `Ctrl+R` for refresh, `Ctrl+F` for search, `Ctrl+D` for theme toggle, `Esc` for close overlay, `AutomationProperties.Name` on every custom control, focus indicators on every focusable element. This is at least 2 days of implementation and testing by itself. Meanwhile, the `?` key as a shortcut is dangerous -- if the user has focus on any text field and presses `?`, it should type a question mark, not open an overlay.

**Recommendation:** MODIFY. Keep tab navigation (`Ctrl+1-4`), `Esc` to close overlays, and basic `Tab`/`Enter` navigation. Cut the `?` shortcut overlay (conflict-prone; put shortcuts in Settings tab instead, which the plan already does at line 918-924). Defer `AutomationProperties` and screen reader support to post-launch unless there is a specific accessibility requirement from the organization.

---

**16. Directive 16 (Status Bar with Health Indicators) -- MUST status: ACCEPTED**

**Concern:** Reasonable. Showing GitHub connection status, cache health, and PowerShell version in a status bar is practical and useful for IT staff troubleshooting. The 5-minute ping interval for GitHub is fine.

**Recommendation:** KEEP as MUST. Simplify the status pill click-to-popover detail (just show a tooltip, not a custom popover control).

---

**17. Directive 17 (Floating Action Button) -- SHOULD status: CHALLENGED**

**Concern:** A FAB that changes its icon and function based on the active tab is a mobile UI pattern that does not translate well to desktop applications. On Desktop, the primary action for each tab is already accessible via prominent buttons in the tab content itself. The 110% hover scale and rotation animation when switching tabs is gratuitous. IT staff do not need a floating circle chasing them around the screen.

**Recommendation:** CUT. Each tab already has its primary action (Refresh, Run, Export, etc.) as regular buttons. A FAB adds visual noise without improving discoverability.

---

**18. Directive 18 (Success/Failure Micro-Animations) -- SHOULD status: CHALLENGED**

**Concern:** Confetti on success. Confetti. For an IT tool that runs database bulk operations. The IT staff will see this confetti burst 5-10 times a day. By day 3 they will want to throw their monitors out the window. The "gentle horizontal shake" on failure is marginally more defensible but still theatrical. A green "SUCCESS" banner or a red "FAILED" banner with the error message is what IT professionals expect and need.

**Recommendation:** MODIFY. Keep a simple color flash (green border flash on success, red on failure). Cut the confetti entirely -- it will be the first thing users ask to disable, and it sends the wrong tone for a professional tool. Cut the window shake. Use the toast notification system (Directive 5) to communicate success/failure, which is already the plan.

---

**19. Directive 19 (High DPI and Scaling Support) -- MUST status: ACCEPTED**

**Concern:** This is genuinely important and correctly marked as MUST. Modern IT staff use high-DPI monitors. This is mostly configuration (manifest settings, `UseLayoutRounding`, vector icons) rather than heavy development.

**Recommendation:** KEEP as MUST. This is one of the few directives that directly impacts usability on real hardware.

---

**20. Directive 20 (Smooth Scroll and Momentum) -- NICE status: ACCEPTED**

**Concern:** This is correctly marked NICE. Custom scroll physics in WPF is finicky and can break mouse wheel behavior on different mice/trackpads.

**Recommendation:** KEEP as NICE. Likely will not be implemented in 21 days, which is fine.

---

**21. Directive 21 (Grid/List View Toggle) -- NICE status: ACCEPTED**

**Concern:** Correctly marked NICE. With 4 tools, this is unnecessary but harmless as a stretch goal.

**Recommendation:** KEEP as NICE.

---

**22. Directive 22 (Breadcrumb Navigation) -- SHOULD status: CHALLENGED**

**Concern:** The app has 4 tabs. There is no deep navigation hierarchy. The "drill-down" is: Tools tab > (optionally) Category filter > Tool card. That is two levels. You do not need breadcrumbs for two levels of navigation. Breadcrumbs are useful in file explorers and documentation sites with 5+ levels. Here, the tab bar already tells you where you are.

**Recommendation:** CUT. The tab bar is the navigation. If the user is in the execution window, the window title shows which tool is running. Breadcrumbs are unnecessary structural overhead.

---

**23. Directive 23 (ANSI Color Support in Output) -- MUST status: ACCEPTED**

**Concern:** This is genuinely useful. PowerShell tools use `Write-Host -ForegroundColor` extensively, and the Bepoz tools specifically use color-coded output. Displaying raw ANSI escape sequences would look terrible.

**Recommendation:** KEEP as MUST. Limit scope to the 8 standard colors + bright variants + bold + reset. Do not attempt to support 256-color or TrueColor ANSI -- the Bepoz tools do not use them.

---

**24. Directive 24 (Auto-Save Settings with Toast) -- SHOULD status: ACCEPTED**

**Concern:** Auto-save with debounce is a reasonable modern pattern. The undo-on-reset via toast is clever.

**Recommendation:** KEEP as SHOULD.

---

### Dependency Risk Assessment

| Package | Concern | Recommendation |
|---------|---------|----------------|
| **LiveCharts2 (SkiaSharpView.WPF)** | Pulls in SkiaSharp native binaries (~15 MB). Known DLL loading issues on locked-down corporate PCs. Overkill for 7-point sparklines. | **REMOVE.** Use a WPF `Polyline` if sparklines are needed post-launch. |
| **Notification.Wpf** | Last NuGet update varies; check if actively maintained. Adds a dependency for something that can be built as a simple custom control in ~200 lines of XAML. | **BUILD IN-HOUSE.** A toast overlay is a `Popup` with a `StackPanel` and a `DispatcherTimer`. It is not worth an external dependency. |
| **Hardcodet.NotifyIcon.Wpf** | Well-maintained, widely used, lightweight. The standard approach for WPF system tray. | **KEEP.** This is the right choice. |
| **MaterialDesignThemes** | Large but well-maintained and actively developed. Provides substantial value. | **KEEP.** Foundation of the UI. |

---

### Performance Reality Check

Agent 1 specifies a 512 MB RAM minimum. Let us account for what is being asked:

- .NET 6/8 WPF app baseline: ~80-120 MB RAM
- MaterialDesignThemes resource dictionaries: ~20-30 MB
- SQLite + EF Core (if used): ~10 MB
- PowerShell SDK (System.Management.Automation): ~40-60 MB loaded
- SkiaSharp for LiveCharts2: ~30-40 MB
- Running PowerShell tool (with its own WinForms GUI): ~50-100 MB

**Total estimated working set: 230-360 MB before the tool even opens its own GUI.**

On a 512 MB machine (which is probably a VM running a POS terminal), this leaves ~150-280 MB for the OS and the tool's own WinForms window. That is dangerously tight.

Animations, gradient shimmers on skeleton loaders, backdrop blur, sparkline chart rendering with SkiaSharp, confetti particle systems -- these all consume GPU and CPU cycles. On a machine with 512 MB RAM, the GPU is likely integrated and shared with system memory.

**Recommendation:** Cut SkiaSharp/LiveCharts2. Cut confetti particles. Cut backdrop blur. Cut skeleton shimmer animations. Make every animation togglable (the plan already has `EnableAnimations` in settings -- good). But better yet, default `EnableAnimations` to `false` and let users who want eye candy turn it on.

---

### Timeline Reality Check

The plan allocates 6 days (Days 9-14) for UI implementation. In those 6 days, Agent 2 is expected to implement:

- Custom borderless window with Mica P/Invoke + fallback
- Three-theme system with animated crossfade
- Animated tab transitions
- Skeleton loading states (3 variants)
- Toast notification system (custom control or NuGet integration + IToastService)
- Command palette (overlay, fuzzy search, ViewModel, keyboard trap)
- Tool cards (hover expansion, star toggle, status pulse, context menu, batch selection, drag ghost)
- Dashboard (stat cards, animated count-up, sparkline charts, pinned favorites, live activity feed)
- Tool execution window (split pane, ANSI parsing, Ctrl+F search, collapsible timestamp sections, live variables, PiP mode)
- Logs tab (color-coded levels, toggleable pills, virtualized scroll, inline actions)
- Settings tab (auto-save debounce, theme preview thumbnails, inline validation)
- Status bar with health indicator pills
- Floating action button with per-tab behavior
- System tray with dynamic favorites menu
- Breadcrumb navigation
- Keyboard shortcuts overlay
- Full keyboard navigation with focus indicators
- High DPI manifest configuration
- Button ripple effects

That is approximately **40-50 distinct UI features** in 6 working days. At a generous estimate of 4-6 hours of productive coding per day, that is 24-36 hours for 40-50 features. That is roughly 30-50 minutes per feature, including testing and debugging. WPF XAML debugging alone (layout issues, binding errors, animation glitches) can easily consume 30 minutes per control.

**This timeline is not realistic for one developer.** Even cutting the features I recommend cutting, it will be tight. Agent 2 needs to be honest about this.

---

### Revised Priority Recommendation (Agent 3)

| Priority | Directives | Notes |
|----------|-----------|-------|
| **P0 - MUST** (actual launch blockers) | 1 (modified: no Mica), 2 (modified: 2 themes), 5 (modified: keep MessageBox for destructive actions), 7 (modified: simplified), 11 (modified: simplified), 14, 16, 19, 23 | 9 directives. These make the app functional and professional. |
| **P1 - SHOULD** (Week 3 if time allows) | 3 (demoted), 9 (modified), 15 (modified), 24 | 4 directives. Add polish if the core is solid. |
| **P2 - NICE** (post-launch) | 4, 6, 8, 10, 12, 13, 17, 18, 20, 21, 22 | 11 directives. Everything else. Ship the app first. |

---

### What Agent 1 Missed (Agent 3)

Agent 1 spent significant design effort on sparklines, confetti, backdrop blur, and command palettes. Here is what the actual IT staff users need that is not in any of the 24 directives:

**1. Connection String Management UI**

The Bepoz tools require database connections. The current `BepozWeekScheduleBulkManager.ps1` requires users to enter SQL Server, Database, and authentication details every single time. The launcher should provide a first-class connection string manager: save named connections (e.g., "Production - BEPOZ-SQL01", "Staging - BEPOZ-SQL02"), select a saved connection when launching a tool, and pass it automatically. This saves IT staff from typing the same connection details 10 times a day. This is more valuable than every sparkline and confetti burst combined.

**2. Parameter Pre-fill and Tool Configuration**

Many Bepoz tools accept parameters (server name, database, flags). The launcher should let users configure default parameters per tool and save them. When launching a tool, show a parameter dialog pre-filled with saved values. The user reviews, optionally edits, and clicks Run. This eliminates repetitive data entry.

**3. Tool Output History / Re-View Last Run**

When a tool finishes and the user closes the execution window, the output is gone. The launcher should save the last N execution outputs (in SQLite or log files) and let users re-view them. "What was the error message from that TSPlus install I ran yesterday?" is a real question IT staff ask. The Logs tab shows summary entries but not full output.

**4. Error Recovery Actions**

When a tool fails, the user sees "Failed" and an error message. Then what? The launcher should provide actionable error recovery: "Retry with same parameters", "Retry as Administrator" (if permission error detected), "Open log file", "Copy error to clipboard for support ticket". The current plan shows a red toast and a shake animation. The user needs actions, not theater.

**5. Prerequisite Checks Before Tool Launch**

Before launching a tool that requires a database, check if the database is reachable. Before launching a tool that requires admin, check if running as admin. Before launching a tool that requires specific modules, verify the modules loaded successfully. Show a pre-flight checklist with green/red indicators BEFORE the user commits to running the tool. Catching a bad connection string before a 2-minute tool startup is far more useful than a pulsing green dot on a tool card.

**6. Multi-Machine / Remote Execution Awareness**

IT staff often need to run the same tool on multiple machines. While remote execution is out of scope for v1, the launcher should at minimum track which machine each execution ran on (already in the data model) and surface it clearly in logs and history. "Did I already run the WeekSchedule update on BEPOZ-POS-03?" is a real question.

**7. Tool Dependency Conflict Detection**

The manifest lists tool dependencies (`BepozDbCore`, `BepozLogger`, `BepozUI`). If a module fails to load, the tool will fail. The launcher should verify all dependencies are cached and loadable BEFORE executing the tool, and show a clear error if a dependency is missing or corrupt, with a "Re-download" action. This is more useful than a breadcrumb trail.

**8. Offline Mode Indicator and Behavior**

The plan mentions offline caching, but there is no UI for it. When GitHub is unreachable, the user should see a clear "OFFLINE MODE" indicator (not just a red status pill) and understand that they are running cached versions of tools. Show the cache age prominently: "Running cached version from 3 hours ago". If no cached version exists, show "Tool unavailable offline" with a clear message instead of a cryptic error.

---

### Summary

Agent 1 designed a beautiful consumer-grade application. The problem is that nobody asked for a consumer-grade application. The users are IT professionals who want to run PowerShell scripts efficiently, track what they ran, and not waste time on repetitive data entry. They will not notice sparklines. They will not appreciate confetti. They will absolutely notice when they have to type the same SQL Server connection string for the 15th time today because nobody built a connection string manager.

Build the shed. Make it sturdy. Put a good lock on the door. Then, if there is time, paint it.

---

## Final Implementation Directives (Reconciled)

> **Purpose:** This is the AUTHORITATIVE section. Agent 2 codes from THIS section only. The original Agent 1 directives and Agent 3's review above are preserved for context, but if there is any conflict, THIS section wins. Every item listed here gets built. If it is not listed here, it does not get built in v1.
>
> **Document Version:** 2.0 -- Final Reconciliation by Agent 1 after incorporating Agent 3 feedback.

---

### Reconciliation Notes

Agent 3 raised valid concerns. Here is my honest assessment:

**Where Agent 3 was right:**
- Skeleton loading states are overkill for 4 tools that load in under a second. Cut.
- Picture-in-Picture is solving a problem that does not exist in the current workflow. Cut.
- LiveCharts2/SkiaSharp is a heavy dependency for 7 data points. Cut the package, keep the concept with a lightweight Polyline.
- Drag-and-drop reordering for 4 tools is absurd. Cut. Replace with right-click "Pin to Dashboard".
- Confetti on success is tone-deaf for an IT tool. Cut the confetti, keep a subtle color flash.
- The FAB is a mobile pattern. IT staff have real buttons. Cut.
- Breadcrumbs for a 2-level navigation hierarchy is overengineering. Cut.
- 40-50 features in 6 days is not achievable. The timeline must be realistic.
- The 8 missed features (connection string manager, parameter pre-fill, output history, error recovery, pre-flight checks, machine tracking, dependency checks, offline indicator) are genuinely more valuable than half the visual polish I specified.

**Where I am pushing back on Agent 3:**
- **Animated tab transitions (Directive 3):** Agent 3 says demote to NICE. I say keep at SHOULD. A 100ms opacity fade is trivial to implement (literally one `DoubleAnimation` in XAML), costs nothing in performance, and the difference between "instant jarring swap" and "gentle fade" is the difference between "feels modern" and "feels like 2010 WinForms." This is not a slide animation -- I am accepting Agent 3's simplification to opacity-only. But it ships. [Agent 1 overruled -- keeping as SHOULD with simplified implementation]
- **Command Palette (Directive 6):** Agent 3 says demote to NICE because there are only 4 tools. I accept the demotion to SHOULD, not NICE. The tool count will grow. More importantly, the command palette is not just about tools -- it is a universal launcher for commands, navigation, and settings. Power users (and IT staff ARE power users) love keyboard-driven interfaces. It is worth the investment. [Agent 1 overruled -- keeping as SHOULD, not NICE]
- **Theme system (Directive 2):** Agent 3 says two themes. I accept dropping the generic "Light" to reduce testing surface. But the crossfade stays, simplified to a 200ms opacity transition (not the complex dictionary swap animation). It is 5 lines of code and it matters. [Modified per Agent 3 -- two themes, simplified transition]
- **Button ripple effects (Directive 13):** Agent 3 says NICE. I agree we should not custom-implement ripple. But MaterialDesignThemes gives it for free. Zero developer time = zero risk. Leave it enabled globally, do not customize per-button. [Modified per Agent 3 -- free from MaterialDesign, no custom work]
- **Keyboard accessibility (Directive 15):** Agent 3 wants to cut screen reader support and the ? shortcut overlay. I accept cutting ? (text field conflict is real). But basic `AutomationProperties.Name` on major controls is not optional -- it is a professional standard and takes 2 minutes per control. I am keeping it in scope but as P1 not P0. [Modified per Agent 3 -- reduced scope, kept core accessibility]
- **Animations default:** Agent 3 says default `EnableAnimations` to false. I disagree. Default to ON. The 512 MB machines are edge cases, and users on modern hardware should see the polished experience out of the box. The setting exists for anyone who needs to turn it off. [Agent 1 overruled -- default ON is correct UX]

---

### Final Directive List

Every directive below has a final priority. **P0 = launches broken without it. P1 = ships in v1 if humanly possible. P2 = post-launch.**

---

#### Directive 1: Window Chrome and Custom Title Bar (P0 - MUST)

[Modified per Agent 3 -- Mica/Acrylic dropped]

**What:** Custom borderless window with clean modern title bar. Solid themed background on all OS versions. No Mica. No Acrylic. No P/Invoke.

**Implementation:**
- Use `WindowChrome` for borderless look with custom title bar
- Title bar contains: Bepoz logo (left), app title, theme toggle (right), standard window buttons (right)
- Solid background from theme ResourceDictionary (`BackgroundPrimary` brush)
- Window remembers position, size, maximized state via `WindowPositionManager.cs` persisted to SQLite
- Graceful on Windows 10, Windows 11, and Windows Server 2019

**Files:** `MainWindow.xaml`, `MainWindow.xaml.cs`, `Helpers/WindowPositionManager.cs`

---

#### Directive 2: Bepoz Light / Bepoz Dark Theme System (P0 - MUST)

[Modified per Agent 3 -- reduced from 3 themes to 2, simplified transition]

**What:** Two-theme system: Bepoz Light (default, branded) and Bepoz Dark. Simple 200ms opacity fade on switch.

**Implementation:**
- Two ResourceDictionary files: `BepozLightTheme.xaml`, `BepozDarkTheme.xaml`
- Shared brush keys: `BackgroundPrimary`, `BackgroundSecondary`, `TextPrimary`, `TextSecondary`, `AccentPrimary`, `AccentSecondary`, `CardBackground`, `CardBorder`, `SuccessColor`, `ErrorColor`, `WarningColor`, `InfoColor`
- Bepoz Light uses company brand colors (navy/blue accent, white cards). Bepoz Dark inverts appropriately
- On switch: swap `ResourceDictionary` in `MergedDictionaries`, animate root opacity 0.8 to 1.0 over 200ms
- Title bar toggle is a sun/moon icon button that switches between Light and Dark
- Persist selection in Settings. Apply before main window renders

**Files:** `Themes/BepozLightTheme.xaml`, `Themes/BepozDarkTheme.xaml`, `App.xaml.cs`, `Resources/Styles.xaml`

---

#### Directive 3: Tab Transitions (P1 - SHOULD)

[Agent 1 overruled -- keeping because a 100ms fade is trivial and prevents jarring swaps]

**What:** When switching tabs, content fades (no slide). 100ms opacity-only transition.

**Implementation:**
- On tab change, outgoing content fades to 0 and incoming fades from 0 to 1 over 100ms total
- Use `DoubleAnimation` on `Opacity` property
- If `Settings.EnableAnimations == false`, instant swap
- No slide. No TranslateTransform. Just opacity

**Files:** `MainWindow.xaml`, `ViewModels/MainViewModel.cs`

---

#### Directive 4: Skeleton Loading States (CUT)

[Cut per Agent 3 -- 4 tools load in under 1 second. Use a simple indeterminate ProgressBar for any loading state.]

**Replacement:** When `IsLoading == true` in any ViewModel, show a standard MaterialDesign indeterminate `ProgressBar` at the top of the content area. One line of XAML. Done.

---

#### Directive 5: Toast Notification System (P0 - MUST)

[Modified per Agent 3 -- toasts for informational, modal dialogs for destructive confirmations]

**What:** Non-blocking toast notifications for informational messages. Modal `MaterialDesign:DialogHost` for destructive confirmations.

**Implementation:**
- Build toast in-house (no Notification.Wpf dependency -- Agent 3 is right, a `Popup` with a timer is sufficient)
- Toast overlay at top-right of main window, stacking vertically
- Four types: Success (green), Error (red), Warning (amber), Info (blue)
- Auto-dismiss: 5 seconds for success/info/warning. Error toasts persist until dismissed
- Slide-in from right (200ms). Fade-out on dismiss (150ms)
- `IToastService` interface in DI: `_toastService.Show(title, message, ToastType)`
- **For destructive actions** (reset settings, clear all cache, restart as admin): use `MaterialDesign:DialogHost` modal with confirm/cancel. NOT MessageBox. NOT toast. A proper styled modal dialog that fits the theme
- Rule: No `MessageBox.Show()` in the codebase. Use toast OR themed modal dialog

**Files:** `Controls/ToastNotification.xaml`, `Services/IToastService.cs`, `Services/ToastService.cs`, `MainWindow.xaml`

---

#### Directive 6: Command Palette (P1 - SHOULD)

[Agent 1 overruled -- keeping as SHOULD because IT staff are power users who benefit from keyboard-driven UX. Will grow more valuable as tool count increases]

**What:** Ctrl+K overlay for quick-launching tools and commands.

**Implementation:**
- Centered overlay (not a new window) with background dim
- 150ms fade-in animation
- Search TextBox with auto-focus, placeholder: "> Search tools and commands..."
- Results list grouped by: "Recently Used", "Tools", "Commands"
- Simple substring matching (not fuzzy -- Agent 3 is right, keep it simple for now)
- Arrow keys navigate, Enter executes, Esc dismisses
- Commands: "Refresh tools", "Clear cache", "Toggle theme", "Open settings"
- `Ctrl+K` registered as `InputBinding` on `MainWindow`

**Files:** `Controls/CommandPalette.xaml`, `ViewModels/CommandPaletteViewModel.cs`, `MainWindow.xaml`

---

#### Directive 7: Tool Card Design (P0 - MUST)

[Modified per Agent 3 -- simplified, cut hover expansion/pulsing/batch/drag]

**What:** Clean tool cards with status indicators, star/favorite, and right-click context menu.

**Implementation:**
- Card: `Border` with `CornerRadius="8"`, subtle shadow, themed `CardBackground`. On hover, shadow deepens slightly (150ms)
- Star/Favorite: star icon at top-left, click to toggle, persisted to Settings
- Status dot: small colored circle next to tool name. Green = cached. Amber = stale. Gray = not cached. Red = last run failed. Static colors, no pulsing animation
- Description: truncated to 2 lines with ellipsis. No hover expansion
- Right-click context menu: Run, Run as Administrator (shield icon), Add/Remove Favorite, Pin to Dashboard, View Source on GitHub, Copy Script Path, Clear Cache
- No batch selection. No drag ghost. No hover expansion animation

**Files:** `Controls/ToolCard.xaml`, `Controls/ToolCard.xaml.cs`, `ViewModels/ToolsViewModel.cs`

---

#### Directive 8: Dashboard Stats with Sparklines (P1 - SHOULD)

[Modified per Agent 3 -- removed LiveCharts2, using WPF Polyline instead]

**What:** Stat cards with mini trend lines drawn using native WPF Polyline.

**Implementation:**
- Each stat card (Total Runs, Success Rate) includes a 120x40px `Polyline` below the number
- Data from `IStatsService.GetDailyExecutionCountsAsync(int days)` -- last 7 days
- Draw points with `Polyline` element, `StrokeThickness="2"`, `Stroke` matching stat accent color
- No LiveCharts2. No SkiaSharp. Pure XAML + code-behind to set `Polyline.Points`
- If fewer than 2 data points, hide the sparkline

**Files:** `Views/DashboardView.xaml`, `ViewModels/DashboardViewModel.cs`, `Services/IStatsService.cs`

---

#### Directive 9: Activity Feed (P1 - SHOULD)

[Modified per Agent 3 -- static list, no polling, no slide-in animation]

**What:** Recent activity list on Dashboard, loaded on navigation to the tab.

**Implementation:**
- `ItemsControl` bound to `ObservableCollection<ActivityFeedItem>` in `DashboardViewModel`
- Each item: icon (success=green check, error=red X, info=blue), tool name, relative timestamp
- Load from SQLite when user navigates to Dashboard. No polling
- Maximum 20 items. Clicking an error entry opens the log detail
- No slide-in animation. Simple list render

**Files:** `Views/DashboardView.xaml`, `ViewModels/DashboardViewModel.cs`, `Models/ActivityFeedItem.cs`

---

#### Directive 10: Drag-and-Drop Favorite Pinning (CUT)

[Cut per Agent 3 -- replaced by "Pin to Dashboard" in right-click context menu (Directive 7)]

**Replacement:** Users right-click a tool card and select "Pin to Dashboard". Pinned tools appear in a "Quick Run" row on the Dashboard. Reordering is by most-recently-pinned. No drag-and-drop.

---

#### Directive 11: Execution Window (P0 - MUST)

[Modified per Agent 3 -- simplified, cut collapsible timestamps and live variables panel]

**What:** Split-pane execution window with output on left, environment info on right.

**Implementation:**
- `Grid` with `GridSplitter`. Default 75/25 split, user-adjustable
- **Left pane (Output):** `RichTextBox` or `FlowDocumentScrollViewer` with ANSI color parsing (Directive 23). Scrolls automatically. Clear button
- **Right pane (Info):** Static info sections: "Tool Info" (name, version, category), "Environment" (PS version, user, admin status, machine name), "Modules Loaded" (checklist). No live variable inspection (thread safety concern is real)
- **Progress:** Indeterminate progress bar at top while running. Determinate if the tool reports progress
- **Controls:** Stop button (kills runspace), Restart button (re-runs same tool with same params), Copy Output button
- **Search in output (P1):** `Ctrl+F` shows search bar at top of output pane with highlight, next/previous. Implement if time allows during Phase 4
- No collapsible timestamp sections. No breadcrumb trail in execution window (covered by window title)

**Files:** `Views/ToolExecutionWindow.xaml`, `ViewModels/ToolExecutionViewModel.cs`, `Helpers/AnsiColorParser.cs`

---

#### Directive 12: Picture-in-Picture Mode (CUT)

[Cut per Agent 3 -- tools open their own WinForms GUI. Users are not browsing while tools run. The execution window stays open.]

---

#### Directive 13: Button Ripple Effects (P2 - NICE)

[Modified per Agent 3 -- zero custom work, just leave MaterialDesign defaults on]

**What:** MaterialDesignThemes provides ripple for free. Leave it enabled globally. Do not write any custom ripple code.

**Implementation:**
- Ensure `materialDesign:RippleAssist.IsDisabled` is NOT set to True anywhere
- That is it. Zero developer time. If it works out of the box, great. If any custom button does not have ripple, do not fix it

---

#### Directive 14: System Tray Icon (P0 - MUST)

[Accepted by Agent 3 -- minor simplification to tray menu]

**What:** System tray integration with context menu.

**Implementation:**
- Use `Hardcodet.NotifyIcon.Wpf` NuGet package
- Tray icon = Bepoz logo
- Right-click menu: "Open Bepoz Toolkit", separator, top 3 most-used tools (from stats, not dynamic favorites -- simpler), separator, "Refresh Tools", separator, "Exit"
- Double-click: restore main window
- When `Settings.MinimizeToSystemTray == true`: X button hides to tray. True exit via tray "Exit" or `Alt+F4`
- Balloon tooltip on first minimize: "Bepoz Toolkit is still running in the system tray"

**Files:** `Helpers/SystemTrayManager.cs`, `MainWindow.xaml.cs`, `App.xaml.cs`

---

#### Directive 15: Keyboard Navigation (P0 - MUST, reduced scope)

[Modified per Agent 3 -- cut ? overlay, reduced scope, kept core accessibility]

**What:** Core keyboard navigation. No ? overlay. Keyboard shortcuts listed in Settings tab.

**Implementation:**
- Tab navigation: `Ctrl+1` through `Ctrl+4` for Dashboard/Tools/Logs/Settings
- `Ctrl+K` for command palette (if implemented -- P1)
- `Ctrl+R` refreshes tool catalog from any tab
- `Ctrl+D` toggles theme
- `Esc` closes any open overlay
- `Enter` on focused tool card runs it. `Space` toggles favorite
- All tabs and cards are focusable via Tab key
- Focus indicators: visible blue outline via `FocusVisualStyle`
- Tab order: logical left-to-right, top-to-bottom
- Keyboard shortcuts reference: a simple list in the Settings tab (not a separate overlay)
- `AutomationProperties.Name` on major interactive controls (buttons, tool cards, navigation items). Not on every decorative element

**Files:** `MainWindow.xaml`, all View XAML files, `Resources/Styles.xaml`, `Views/SettingsView.xaml`

---

#### Directive 16: Status Bar with Health Indicators (P0 - MUST)

[Accepted by Agent 3 -- simplified popover to tooltip]

**What:** Bottom status bar with GitHub, cache, and PowerShell health indicators.

**Implementation:**
- `StatusPill` control: small rounded rectangle with colored dot and label
- Three indicators:
  1. **GitHub:** Green = connected, Amber = stale (>5 min), Red = disconnected. Check on startup + every 5 minutes
  2. **Cache:** Green = all cached, Amber = some expired, Red = empty. Count and total size
  3. **PowerShell:** Green = 7.x, Amber = 5.1, Red = not found
- "Last sync: Xm ago" with live-updating relative time
- Clicking a pill shows a tooltip (not a custom popover) with details

**Files:** `Controls/StatusPill.xaml`, `MainWindow.xaml`, `ViewModels/MainViewModel.cs`

---

#### Directive 17: Floating Action Button (CUT)

[Cut per Agent 3 -- each tab already has its primary action as a regular button. A FAB adds visual noise.]

---

#### Directive 18: Success/Failure Feedback (P1 - SHOULD)

[Modified per Agent 3 -- cut confetti and window shake, kept subtle color feedback]

**What:** Subtle visual feedback on tool completion. No confetti. No shake.

**Implementation:**
- **Success:** Brief green border flash on execution window (opacity 0 -> 0.2 -> 0 over 300ms). Then toast: "Tool completed successfully (Xm Xs)"
- **Failure:** Brief red border flash (same timing). Then toast: "Tool failed: [error summary]" (persists until dismissed)
- Respect `Settings.EnableAnimations`. If off, skip the flash, still show the toast

**Files:** `Views/ToolExecutionWindow.xaml`, `ViewModels/ToolExecutionViewModel.cs`

---

#### Directive 19: High DPI and Scaling Support (P0 - MUST)

[Accepted by Agent 3 -- no changes]

**What:** Crisp rendering on all DPI scaling levels.

**Implementation:**
- `App.manifest`: `<dpiAwareness>PerMonitorV2</dpiAwareness>`
- All sizing in device-independent pixels
- All icons vector-based (XAML paths from MaterialDesign). No raster images except app icon
- App icon (`icon.ico`): include 16, 24, 32, 48, 64, 128, 256px sizes
- `UseLayoutRounding="True"` and `SnapsToDevicePixels="True"` on root element

**Files:** `App.manifest`, `MainWindow.xaml`, `Resources/Icons.xaml`

---

#### Directive 20: Smooth Scroll and Momentum (P2 - NICE)

[No change -- correctly scoped as NICE by both Agent 1 and Agent 3]

Post-launch stretch goal. If implemented, use attached behavior `SmoothScrollBehavior` on `ScrollViewer`.

---

#### Directive 21: Grid/List View Toggle (P2 - NICE)

[No change -- correctly scoped as NICE by both Agent 1 and Agent 3]

Post-launch stretch goal. Toggle between card grid and compact DataGrid table view for tools.

---

#### Directive 22: Breadcrumb Navigation (CUT)

[Cut per Agent 3 -- two-level navigation does not need breadcrumbs. Tab bar is sufficient.]

---

#### Directive 23: ANSI Color Support in Output (P0 - MUST)

[Accepted by Agent 3 -- minor scope note]

**What:** Parse and render ANSI escape codes in tool execution output.

**Implementation:**
- `Helpers/AnsiColorParser.cs`: parse raw output into `Run` elements with WPF `Foreground`, `FontWeight`, `TextDecoration`
- Support: 8 standard ANSI colors (30-37, 40-47), bright variants (90-97, 100-107), bold (1), underline (4), reset (0)
- No 256-color. No TrueColor. The Bepoz tools do not use them
- Unrecognized codes: strip silently, never display raw escape sequences
- Feed parsed `Run` elements into `FlowDocument` `Paragraph` in the execution window

**Files:** `Helpers/AnsiColorParser.cs`, `Views/ToolExecutionWindow.xaml`, `ViewModels/ToolExecutionViewModel.cs`

---

#### Directive 24: Auto-Save Settings (P1 - SHOULD)

[Accepted by Agent 3 -- no changes]

**What:** Settings auto-save with debounce and toast confirmation.

**Implementation:**
- 500ms debounce timer in `SettingsViewModel` on any property change
- On save: subtle toast "Settings saved" (2-second auto-dismiss)
- No Save/Cancel buttons. Keep "Reset to Defaults" with modal confirmation dialog (per Directive 5 modal pattern)
- Inline red validation messages for invalid values

**Files:** `ViewModels/SettingsViewModel.cs`, `Views/SettingsView.xaml`

---

### New Directives from Agent 3's "What Agent 1 Missed"

These are the practical features Agent 3 correctly identified as more valuable than visual polish. All are accepted and integrated.

---

#### Directive 25: Connection String Manager (P0 - MUST) [NEW - Agent 3]

**What:** First-class UI for saving, selecting, and managing database connection strings. This eliminates the single most repetitive task IT staff face daily.

**Implementation:**
- New section in Settings tab: "Saved Connections"
- Each saved connection has: friendly name (e.g., "Production - BEPOZ-SQL01"), server, database, authentication type (Windows Auth / SQL Auth), username (if SQL Auth), password (encrypted at rest using DPAPI)
- Add/Edit/Delete connections. "Test Connection" button with inline pass/fail indicator
- When launching a tool that `RequiresDatabase == true`, show a connection picker dropdown pre-filled with the last-used connection. User confirms or selects a different one
- Pass connection details to PowerShell script as parameters (`-SqlServer`, `-Database`, `-UseWindowsAuth`, `-SqlUser`, `-SqlPassword`)
- Store connections in SQLite in a new `SavedConnections` table. Encrypt passwords with `System.Security.Cryptography.ProtectedData` (DPAPI -- machine-scoped)
- Default the connection picker to the last-used connection for that specific tool

**New DB Table:**
```sql
CREATE TABLE SavedConnections (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    Server TEXT NOT NULL,
    Database TEXT NOT NULL,
    AuthType TEXT NOT NULL,       -- 'Windows' or 'SQL'
    Username TEXT,
    EncryptedPassword BLOB,
    LastUsedAt TEXT,
    CreatedAt TEXT NOT NULL
);
```

**Files:** `Views/SettingsView.xaml` (connections section), `Models/SavedConnection.cs`, `Services/IConnectionService.cs`, `Services/ConnectionService.cs`, `Views/ConnectionPickerDialog.xaml`

---

#### Directive 26: Parameter Pre-fill and Tool Configuration (P0 - MUST) [NEW - Agent 3]

**What:** Save default parameters per tool so users do not retype the same values every run.

**Implementation:**
- Before launching a tool, show a "Launch Configuration" dialog with the tool's parameters pre-filled from last-used values
- Parameters are defined in `manifest.json` per tool (extend the manifest schema with a `parameters` array: `{ "name": "SqlServer", "type": "string", "required": true, "description": "SQL Server hostname" }`)
- The dialog shows each parameter with a labeled TextBox, pre-filled with the last-used value for this tool
- "Save as defaults" checkbox to persist current values for future runs
- User reviews, optionally edits, clicks "Run"
- Store saved parameters in SQLite `ToolParameters` table

**New DB Table:**
```sql
CREATE TABLE ToolParameters (
    ToolId TEXT NOT NULL,
    ParameterName TEXT NOT NULL,
    SavedValue TEXT,
    LastUsedAt TEXT NOT NULL,
    PRIMARY KEY (ToolId, ParameterName)
);
```

**Files:** `Views/LaunchConfigDialog.xaml`, `ViewModels/LaunchConfigViewModel.cs`, `Models/ToolParameter.cs`, update `Tool.cs` model

---

#### Directive 27: Tool Output History (P1 - SHOULD) [NEW - Agent 3]

**What:** Save the last N execution outputs so users can review past runs.

**Implementation:**
- After each tool execution, save full output text to SQLite `ExecutionHistory` table (keep last 50 runs across all tools)
- In the Logs tab, add a "History" sub-section or make log entries clickable to view full output
- Each history entry shows: tool name, timestamp, duration, success/failure, and a "View Output" button
- "View Output" opens a read-only version of the execution window with the saved output (with ANSI color rendering)
- Auto-prune: delete entries older than 30 days or when count exceeds 50

**New DB Table:**
```sql
CREATE TABLE ExecutionHistory (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ToolId TEXT NOT NULL,
    ToolName TEXT NOT NULL,
    ExecutedAt TEXT NOT NULL,
    DurationMs INTEGER NOT NULL,
    Success INTEGER NOT NULL,
    FullOutput TEXT NOT NULL,
    ErrorOutput TEXT,
    Parameters TEXT             -- JSON of parameters used
);

CREATE INDEX idx_history_date ON ExecutionHistory(ExecutedAt);
```

**Files:** `Models/ExecutionHistoryEntry.cs`, `Services/IHistoryService.cs`, `Services/HistoryService.cs`, `Views/LogsView.xaml`, `ViewModels/LogsViewModel.cs`

---

#### Directive 28: Error Recovery Actions (P0 - MUST) [NEW - Agent 3]

**What:** When a tool fails, provide actionable recovery options, not just a red toast.

**Implementation:**
- On tool failure, the execution window shows an "Error Recovery" panel below the output:
  - "Retry with same parameters" button
  - "Retry as Administrator" button (if error contains permission-related keywords: "access denied", "not have admin", "elevation required")
  - "Copy Error to Clipboard" button (for support tickets)
  - "Open Log File" button (opens the Serilog file in default text editor)
  - "View Full Error" expandable section showing the complete stack trace / error details
- The error recovery panel replaces the progress bar area when a failure occurs
- Error toast still fires (per Directive 5) but the actionable buttons are in the execution window itself

**Files:** `Views/ToolExecutionWindow.xaml`, `ViewModels/ToolExecutionViewModel.cs`

---

#### Directive 29: Pre-flight Checks Before Tool Launch (P0 - MUST) [NEW - Agent 3]

**What:** Verify prerequisites are met before committing to a tool run.

**Implementation:**
- After the user clicks "Run" (and after parameter dialog if applicable), show a pre-flight checklist dialog:
  - Database reachable? (if `RequiresDatabase`): Test TCP connection to SQL Server on port 1433. Green check / red X
  - Running as admin? (if `RequiresAdmin`): Check `WindowsIdentity.GetCurrent().Owner.IsWellKnown(WellKnownSidType.BuiltinAdministratorsSid)`. Green check / red X with "Restart as Admin" button
  - Dependencies available? (for each module in `Dependencies`): Check if cached and loadable. Green check / red X with "Download" button
  - PowerShell available?: Verify PS runtime. Green check / red X
- If all green: auto-proceed to execution after 1 second (or user clicks "Run Now" to skip the delay)
- If any red: block execution. User must fix the issue (using provided action buttons) or click "Run Anyway" (at their own risk)
- Pre-flight dialog is a lightweight `MaterialDesign:DialogHost` content, not a separate window

**Files:** `Views/PreFlightDialog.xaml`, `ViewModels/PreFlightViewModel.cs`, `Services/IPreFlightService.cs`, `Services/PreFlightService.cs`

---

#### Directive 30: Machine Tracking in Logs (P1 - SHOULD) [NEW - Agent 3]

**What:** Track and surface which machine each execution ran on.

**Implementation:**
- `UsageStatistics` table already has `ComputerName`. Ensure it is always populated with `Environment.MachineName`
- In the Logs tab, add a "Machine" column to log entries (or a filter dropdown for machine name)
- In Dashboard stats, show "Runs by Machine" breakdown if executions span multiple machines
- This is mostly about surfacing data that is already being captured. Low implementation cost

**Files:** `Views/LogsView.xaml`, `ViewModels/LogsViewModel.cs`, `ViewModels/DashboardViewModel.cs`

---

#### Directive 31: Tool Dependency Verification (P0 - MUST) [NEW - Agent 3]

**What:** Verify all module dependencies are cached and loadable before executing a tool.

**Implementation:**
- This is integrated into Directive 29 (Pre-flight Checks) as one of the checklist items
- Additionally: when the tool catalog loads, check each tool's `Dependencies` array against the cache
- If any dependency is missing or corrupt (SHA256 mismatch), show an amber status on the tool card and auto-download the dependency in the background
- If download fails (offline), mark the tool as "Dependencies unavailable" with a clear message
- On the tool card, the status dot reflects dependency health: if tool is cached but a dependency is missing, show amber, not green

**Files:** `Services/ICacheService.cs` (add dependency verification), `ViewModels/ToolsViewModel.cs`, `Controls/ToolCard.xaml`

---

#### Directive 32: Offline Mode Indicator and Behavior (P0 - MUST) [NEW - Agent 3]

**What:** Clear, prominent UI when running in offline mode.

**Implementation:**
- When GitHub is unreachable (detected by status bar health check, Directive 16):
  - Show a persistent amber banner at the top of the main window: "OFFLINE MODE -- Running cached tools. Last sync: [timestamp]"
  - The banner has a "Retry Connection" button
  - All tool cards show their cache age: "Cached 3 hours ago" below the version number
  - Tools with no cached version show "Unavailable offline" with the tool card grayed out and Run button disabled
  - The status bar GitHub pill turns red (already in Directive 16)
- When connection is restored: banner auto-dismisses, tools refresh from GitHub, toast: "Connection restored. Tools updated."

**Files:** `MainWindow.xaml` (banner), `ViewModels/MainViewModel.cs`, `Controls/ToolCard.xaml`, `ViewModels/ToolsViewModel.cs`

---

### Final Priority Summary

| Priority | Directives | Count | Description |
|----------|-----------|-------|-------------|
| **P0 - MUST** | 1, 2, 5, 7, 11, 14, 15, 16, 19, 23, 25, 26, 28, 29, 31, 32 | 16 | Core framework, theme, notifications, tool cards, execution, tray, keyboard, status bar, DPI, ANSI, connection manager, parameters, error recovery, pre-flight, dependency checks, offline mode |
| **P1 - SHOULD** | 3, 6, 8, 9, 18, 24, 27, 30 | 8 | Tab fade, command palette, sparklines, activity feed, success/failure flash, auto-save settings, output history, machine tracking |
| **P2 - NICE** | 13, 20, 21 | 3 | Ripple (free), smooth scroll, grid/list toggle |
| **CUT** | 4, 10, 12, 17, 22 | 5 | Skeleton loaders, drag-drop, PiP, FAB, breadcrumbs |

---

### Revised Phase 4 Timeline (UI Implementation)

Agent 3 is right that the original 6-day Phase 4 was unrealistic. With the cuts and additions, here is the revised plan. Phase 4 now spans **Days 9-16** (8 working days) by borrowing 2 days from the original Phase 5 (performance optimization folded into ongoing work, auto-update moved to Day 17).

**Total remaining features after cuts:** 27 active directives (16 P0 + 8 P1 + 3 P2). P2 items are not scheduled -- they happen if there is spare time or post-launch.

---

### Sprint Plan: Phase 4 Daily Breakdown

#### Day 9: Foundation Shell

**Goal:** The app opens, looks modern, and has the right bones.

| Task | Directive | Priority |
|------|-----------|----------|
| Custom borderless window with WindowChrome | D1 | P0 |
| Bepoz Light / Bepoz Dark theme system (both ResourceDictionaries) | D2 | P0 |
| PerMonitorV2 DPI manifest + UseLayoutRounding | D19 | P0 |
| Main window layout: title bar, tab navigation, content area, status bar | D1, D16 | P0 |
| ViewModelBase, RelayCommand, DI container setup | -- | P0 |
| Window position memory (save/restore size and position) | D1 | P0 |

**Deliverable:** App opens with themed borderless window, tabs visible, status bar placeholder, both themes switchable.

---

#### Day 10: Infrastructure Services

**Goal:** Toast system, status bar health, system tray -- the plumbing everything else depends on.

| Task | Directive | Priority |
|------|-----------|----------|
| Build IToastService + toast overlay control (in-house) | D5 | P0 |
| Build themed modal dialog helper (for destructive confirmations) | D5 | P0 |
| StatusPill control + 3 health indicators (GitHub, cache, PS) | D16 | P0 |
| System tray icon with context menu | D14 | P0 |
| Minimize-to-tray behavior | D14 | P0 |
| Keyboard shortcuts framework (Ctrl+1-4 tabs, Ctrl+R refresh, Ctrl+D theme, Esc close) | D15 | P0 |

**Deliverable:** Toasts fire, status bar shows live health, system tray works, keyboard navigation functional.

---

#### Day 11: Tool Cards and Tools Tab

**Goal:** Users can see all tools, search/filter, favorite them, and understand their status at a glance.

| Task | Directive | Priority |
|------|-----------|----------|
| ToolCard custom control (shadow, status dot, star, context menu) | D7 | P0 |
| ToolsViewModel (load from manifest, search, filter by category) | D7 | P0 |
| ToolsView layout (category pill filters, card grid, search box) | D7 | P0 |
| Right-click context menu (Run, Run as Admin, Favorite, Pin, GitHub, Copy Path, Clear Cache) | D7 | P0 |
| Offline behavior on tool cards (cache age, "unavailable offline" state) | D32 | P0 |
| Offline mode banner on main window | D32 | P0 |

**Deliverable:** Tools tab fully functional with cards, search, filter, favorites, context menu, offline awareness.

---

#### Day 12: Connection Manager and Launch Config

**Goal:** The features Agent 3 correctly identified as the highest-value additions.

| Task | Directive | Priority |
|------|-----------|----------|
| SavedConnection model + SavedConnections DB table | D25 | P0 |
| ConnectionService (CRUD + DPAPI encryption + test connection) | D25 | P0 |
| Settings tab: Saved Connections management UI (add/edit/delete/test) | D25 | P0 |
| ToolParameter model + ToolParameters DB table | D26 | P0 |
| LaunchConfigDialog (parameter pre-fill, connection picker, save defaults) | D26 | P0 |
| Update manifest.json schema to include tool parameters | D26 | P0 |

**Deliverable:** Users can save connections, pre-fill parameters, and launch tools without repetitive typing.

---

#### Day 13: Pre-flight Checks and Execution Window

**Goal:** Tools launch safely with prerequisite verification and a proper execution experience.

| Task | Directive | Priority |
|------|-----------|----------|
| PreFlightService (DB reachability, admin check, dependency check, PS check) | D29 | P0 |
| PreFlightDialog UI (checklist with green/red, action buttons, "Run Anyway") | D29 | P0 |
| Dependency verification in cache service | D31 | P0 |
| Execution window: split-pane layout (output left 75%, info right 25%) | D11 | P0 |
| Execution window: progress bar, stop/restart buttons, copy output | D11 | P0 |
| AnsiColorParser for output rendering | D23 | P0 |

**Deliverable:** Full launch flow: parameters -> pre-flight -> execution with ANSI-colored output.

---

#### Day 14: Error Recovery, Output History, Dashboard

**Goal:** What happens after tools run. Plus the Dashboard.

| Task | Directive | Priority |
|------|-----------|----------|
| Error recovery panel in execution window (retry, retry as admin, copy error, open log) | D28 | P0 |
| Success/failure border flash + toast | D18 | P1 |
| ExecutionHistory table + HistoryService (save output, auto-prune) | D27 | P1 |
| DashboardViewModel (stats from SQLite, pinned tools, recent activity) | D9 | P1 |
| DashboardView (stat cards, Quick Run bar for pinned tools, activity list) | D9 | P1 |

**Deliverable:** Error recovery works, output is saved for later review, Dashboard shows useful stats and activity.

---

#### Day 15: Logs, Settings, Polish

**Goal:** Complete the remaining tabs and P1 items.

| Task | Directive | Priority |
|------|-----------|----------|
| LogsViewModel (load from DB/files, filter by level and machine, color-coded rows) | D30 | P1 |
| LogsView with "View Output" for history entries | D27 | P1 |
| Settings tab: auto-save with debounce + toast | D24 | P1 |
| Settings tab: keyboard shortcuts reference section | D15 | P0 |
| Settings tab: inline validation | D24 | P1 |
| Sparkline Polylines on Dashboard stat cards | D8 | P1 |

**Deliverable:** All four tabs fully functional. Settings auto-save. Logs show machine info and link to output history.

---

#### Day 16: Command Palette, Tab Transitions, Integration Testing

**Goal:** P1 polish and end-to-end smoke testing of the complete UI flow.

| Task | Directive | Priority |
|------|-----------|----------|
| Command Palette overlay (Ctrl+K, search, results list, keyboard nav) | D6 | P1 |
| Tab fade transitions (100ms opacity) | D3 | P1 |
| Focus indicators on all major interactive controls | D15 | P0 |
| AutomationProperties.Name on major controls | D15 | P0 |
| End-to-end smoke test: launch app -> select tool -> configure params -> pre-flight -> run -> view output -> check logs -> check history | -- | -- |
| Fix visual bugs, binding errors, layout issues found during testing | -- | -- |

**Deliverable:** All P0 and P1 features implemented. App tested end-to-end. Ready for Phase 5.

---

### Revised Phase 5+ Timeline

With Phase 4 now ending at Day 16:

| Phase | Days | Focus |
|-------|------|-------|
| Phase 5: Auto-Update + Error Handling | Days 17-18 | Launcher self-update, comprehensive error handling, crash reporting |
| Phase 6: Installer + Deployment | Days 19-20 | WiX MSI installer, silent install, GPO-ready |
| Phase 7: Testing + Documentation | Day 21 | Final testing on Win10/Win11/Server2019, user guide |

---

### NuGet Package List (Final)

| Package | Status | Notes |
|---------|--------|-------|
| **MaterialDesignThemes.Wpf** | KEEP | Foundation UI toolkit |
| **System.Management.Automation** | KEEP | PowerShell hosting |
| **Microsoft.Data.Sqlite** | KEEP | Local database |
| **Octokit** | KEEP | GitHub API |
| **Serilog + Serilog.Sinks.File** | KEEP | Logging |
| **Hardcodet.NotifyIcon.Wpf** | KEEP | System tray |
| ~~Notification.Wpf~~ | REMOVED | Build toast in-house |
| ~~LiveCharts2 / SkiaSharp~~ | REMOVED | Use WPF Polyline instead |

---

### Settings Model Update

The Settings model from the Data Models section should be updated to reflect reconciled decisions:

```csharp
public class Settings
{
    // GitHub
    public string GitHubOwner { get; set; } = "StephenShawBepoz";
    public string GitHubRepo { get; set; } = "bepoz-toolkit";
    public string GitHubBranch { get; set; } = "main";

    // Cache
    public int CacheExpirationMinutes { get; set; } = 60;

    // Behavior
    public bool CheckForUpdatesOnStartup { get; set; } = true;
    public bool EnableUsageTracking { get; set; } = true;
    public bool EnableLogging { get; set; } = true;
    public string LogLevel { get; set; } = "Information";
    public bool ConfirmToolExecution { get; set; } = false;

    // Theme (reconciled: 2 themes instead of 3)
    public string Theme { get; set; } = "BepozLight";  // BepozLight or BepozDark

    // UI
    public bool MinimizeToSystemTray { get; set; } = true;
    public bool EnableAnimations { get; set; } = true;  // Agent 1 overruled: default ON
    public bool EnableToastNotifications { get; set; } = true;

    // Window position
    public double WindowLeft { get; set; } = -1;
    public double WindowTop { get; set; } = -1;
    public double WindowWidth { get; set; } = 1100;
    public double WindowHeight { get; set; } = 750;

    // Favorites and pins
    public List<string> FavoriteToolIds { get; set; } = new();
    public List<string> PinnedToolIds { get; set; } = new();

    // Connection management (NEW - Agent 3)
    public string LastUsedConnectionId { get; set; } = "";
}
```

---

### Database Schema Additions

Add these tables to the Database Schema section:

```sql
-- Directive 25: Saved Connections
CREATE TABLE SavedConnections (
    Id TEXT PRIMARY KEY,
    Name TEXT NOT NULL,
    Server TEXT NOT NULL,
    DatabaseName TEXT NOT NULL,
    AuthType TEXT NOT NULL,
    Username TEXT,
    EncryptedPassword BLOB,
    LastUsedAt TEXT,
    CreatedAt TEXT NOT NULL
);

-- Directive 26: Tool Parameters
CREATE TABLE ToolParameters (
    ToolId TEXT NOT NULL,
    ParameterName TEXT NOT NULL,
    SavedValue TEXT,
    LastUsedAt TEXT NOT NULL,
    PRIMARY KEY (ToolId, ParameterName)
);

-- Directive 27: Execution History
CREATE TABLE ExecutionHistory (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ToolId TEXT NOT NULL,
    ToolName TEXT NOT NULL,
    ExecutedAt TEXT NOT NULL,
    DurationMs INTEGER NOT NULL,
    Success INTEGER NOT NULL,
    FullOutput TEXT NOT NULL,
    ErrorOutput TEXT,
    Parameters TEXT,
    ConnectionId TEXT
);

CREATE INDEX idx_history_date ON ExecutionHistory(ExecutedAt);
CREATE INDEX idx_history_tool ON ExecutionHistory(ToolId);
```

---

### Definition of Done

Agent 2: a feature is "done" when:

1. It works on Windows 10 (1809+) and Windows 11
2. It works in both Bepoz Light and Bepoz Dark themes
3. It handles errors gracefully (no unhandled exceptions, no raw stack traces to the user)
4. Keyboard navigation works for the feature (Tab, Enter, Esc as appropriate)
5. It looks acceptable at 100%, 150%, and 200% DPI scaling

If you cannot meet all 5 for a P0 item, raise it immediately. Do not ship broken.

---

## Implementation Phases

### Phase 1: Foundation (Days 1-3)

**Goal:** Set up project structure and core services

**Tasks:**
1. Create Visual Studio solution with 3 projects (App, Core, Tests)
2. Install NuGet packages:
   - MaterialDesignThemes.Wpf
   - System.Management.Automation
   - Microsoft.Data.Sqlite
   - Octokit
   - Serilog
   - Notification.Wpf (toast notifications - Directive 5)
   - LiveChartsCore.SkiaSharpView.WPF (sparkline charts - Directive 8)
   - Hardcodet.NotifyIcon.Wpf (system tray icon - Directive 14)
3. Implement core models (Tool, Category, Settings, etc.)
4. Create IGitHubService interface + implementation
5. Test GitHub API connectivity and manifest.json fetching
6. Set up SQLite database with initial schema
7. Implement ISettingsService for persistence

**Deliverable:** Solution compiles, can fetch manifest.json from GitHub, store settings in SQLite

---

### Phase 2: PowerShell Execution Engine (Days 4-6)

**Goal:** Enable PowerShell script execution from C#

**Tasks:**
1. Implement IPowerShellHost interface
2. Create PowerShell runspace with System.Management.Automation
3. Implement script execution with parameter passing
4. Capture standard output and error streams in real-time
5. Add progress reporting mechanism
6. Implement stop/cancel functionality
7. Test with simple PowerShell scripts
8. Test with actual Bepoz tools (WeekSchedule, WebAPI Settings)
9. Verify module dot-sourcing works correctly

**Deliverable:** Can execute any PS1 file from C# with real-time output capture

---

### Phase 3: Data Persistence & Caching (Days 7-8)

**Goal:** Implement local caching and statistics tracking

**Tasks:**
1. Implement ICacheService for file caching
   - Store downloaded PS1 files in %LOCALAPPDATA%\BepozToolkit\Cache
   - Implement cache expiration (1 hour default)
   - Track cache metadata (file path, download date, size)
2. Implement IStatsService for usage tracking
   - Record every tool execution with timestamp, duration, success/failure
   - Store in SQLite database
   - Implement queries for dashboard statistics
3. Add cache cleanup on startup (remove expired files)
4. Test offline mode (should work with cached files)

**Deliverable:** Tools cached locally, statistics tracked in database

---

### Phase 4: WPF UI Implementation (Days 9-14)

**Goal:** Build complete user interface with MaterialDesign

**Tasks:**

**Day 9-10: Main Window & Navigation**
1. Create MainWindow.xaml with MaterialDesign theme + Mica backdrop (Directive 1)
2. Add navigation tabs with animated underline (Dashboard, Tools, Logs, Settings)
3. Implement animated tab transitions - slide/fade (Directive 3)
4. Implement ViewModelBase with INotifyPropertyChanged
5. Create MainViewModel with navigation logic
6. Implement Dark/Light/Bepoz theme system (Directive 2)
7. Add Bepoz branding (colors, logo)
8. Implement status bar with health indicators (Directive 16)
9. Set up toast notification overlay host (Directive 5)
10. Implement keyboard shortcuts framework (Directive 15)
11. Implement window position memory (Directive 1)
12. Set up PerMonitorV2 DPI awareness (Directive 19)

**Day 11-12: Dashboard & Tools Tabs**
1. Implement DashboardViewModel
   - Load statistics from IStatsService
   - Display quick stats cards with animated count-up
   - Add sparkline charts to stat cards (Directive 8)
   - Show favorited/pinned tools in Quick Run bar
   - Implement live activity feed with slide-in animations (Directive 9)
2. Create DashboardView.xaml with cards, sparklines, and activity feed
3. Implement skeleton loading states for dashboard (Directive 4)
4. Implement ToolsViewModel
   - Load tools from GitHub manifest
   - Implement search/filter/category pill tabs functionality
   - Display tools grouped by category (collapsible)
   - Implement favorite star toggle
   - Add batch selection and batch action bar
5. Create ToolsView.xaml with enhanced tool cards
6. Create ToolCard custom control with hover expansion, status dots, context menu (Directive 7)
7. Implement breadcrumb navigation for category drill-down (Directive 22)
8. Implement drag-and-drop favorite pinning (Directive 10)

**Day 13: Tool Execution Window**
1. Create ToolExecutionWindow.xaml with split-pane layout (Directive 11)
   - Left pane: output with ANSI color support (Directive 23)
   - Right pane: live variables/state panel
   - Resizable GridSplitter between panes
2. Implement ToolExecutionViewModel
   - Connect to IPowerShellHost
   - Display real-time output with color parsing
   - Show animated gradient progress bar
   - Handle stop/cancel/restart
   - Implement Ctrl+F search in output (Directive 11)
3. Add collapsible timestamp sections in output
4. Implement success confetti / failure shake animations (Directive 18)
5. Implement picture-in-picture mode (Directive 12)
6. Add breadcrumb trail at top of execution window

**Day 14: Logs & Settings Tabs + Global Features**
1. Implement LogsViewModel
   - Load logs from Serilog with virtualized scrolling
   - Filter by level (toggleable pills) and tool
   - Color-coded log level rows
   - Inline actions on error rows (Copy Error, Retry Tool)
2. Create LogsView.xaml with enhanced log viewer
3. Implement SettingsViewModel with auto-save + debounce (Directive 24)
   - Bind to ISettingsService
   - Real-time inline validation
   - Test database connection with inline result (no popup)
   - Theme preview thumbnails
   - Keyboard shortcuts reference section
4. Create SettingsView.xaml with toggle switches and settings form
5. Implement Command Palette overlay (Directive 6)
6. Implement system tray icon with quick-launch menu (Directive 14)
7. Implement floating action button per-tab (Directive 17)

**Deliverable:** Fully functional WPF application with all tabs working

---

### Phase 5: Advanced Features (Days 15-17)

**Goal:** Add polish and advanced functionality

**Tasks:**

**Day 15: Auto-Update**
1. Implement launcher self-update check on startup
2. Check GitHub Releases API for new versions
3. Download and install updates automatically
4. Add update notification UI

**Day 16: Error Handling & Logging**
1. Add comprehensive error handling throughout app
2. Configure Serilog to write to file and UI
3. Implement crash reporting
4. Add diagnostic information collection

**Day 17: Performance Optimization**
1. Profile application startup time
2. Implement lazy loading of tools
3. Optimize database queries
4. Add splash screen for startup

**Deliverable:** Polished app with auto-update and robust error handling

---

### Phase 6: Installer & Deployment (Days 18-19)

**Goal:** Create professional MSI installer

**Tasks:**
1. Install WiX Toolset v4
2. Create installer project (BepozToolkit.Installer)
3. Define installer components:
   - Install BepozToolkit.exe to Program Files
   - Create Start Menu shortcut
   - Create Desktop shortcut (optional)
   - Register file associations (optional)
   - Set up auto-start on login (optional)
4. Add custom installer UI with Bepoz branding
5. Test installer on clean Windows machine
6. Test uninstaller (should remove all files and settings)
7. Create silent install option: `BepozToolkit.msi /quiet`

**Deliverable:** Working MSI installer that deploys application

---

### Phase 7: Testing & Documentation (Days 20-21)

**Goal:** Ensure quality and provide documentation

**Tasks:**

**Day 20: Testing**
1. Write unit tests for services (GitHubService, PowerShellHost, etc.)
2. Write integration tests (end-to-end tool execution)
3. Manual testing on Windows 10 and Windows 11
4. Test with/without admin privileges
5. Test offline mode
6. Test with slow network connection
7. Load testing (execute 50+ tools in sequence)

**Day 21: Documentation**
1. Update README.md with:
   - Installation instructions
   - Screenshots
   - System requirements
   - Troubleshooting
2. Create USER_GUIDE.md for end users
3. Create API.md for developers
4. Record demo video (optional)
5. Update GitHub wiki

**Deliverable:** Tested application with complete documentation

---

## Database Schema

### SQLite Database: `BepozToolkit.db`

**Location:** `%LOCALAPPDATA%\BepozToolkit\BepozToolkit.db`

#### Table: Settings

```sql
CREATE TABLE Settings (
    Key TEXT PRIMARY KEY,
    Value TEXT NOT NULL,
    Type TEXT NOT NULL,  -- 'String', 'Int', 'Bool', etc.
    UpdatedAt TEXT NOT NULL
);

-- Example rows:
INSERT INTO Settings VALUES ('GitHubOwner', 'StephenShawBepoz', 'String', '2026-02-12T10:00:00Z');
INSERT INTO Settings VALUES ('GitHubRepo', 'bepoz-toolkit', 'String', '2026-02-12T10:00:00Z');
INSERT INTO Settings VALUES ('CacheExpirationMinutes', '60', 'Int', '2026-02-12T10:00:00Z');
```

#### Table: UsageStatistics

```sql
CREATE TABLE UsageStatistics (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ToolId TEXT NOT NULL,
    ToolName TEXT NOT NULL,
    ExecutedAt TEXT NOT NULL,  -- ISO 8601 format
    UserName TEXT NOT NULL,
    ComputerName TEXT NOT NULL,
    Success INTEGER NOT NULL,  -- 0 = false, 1 = true
    DurationMs INTEGER NOT NULL,
    ErrorMessage TEXT
);

CREATE INDEX idx_usage_tool ON UsageStatistics(ToolId);
CREATE INDEX idx_usage_date ON UsageStatistics(ExecutedAt);
CREATE INDEX idx_usage_success ON UsageStatistics(Success);
```

#### Table: CacheMetadata

```sql
CREATE TABLE CacheMetadata (
    FilePath TEXT PRIMARY KEY,     -- Relative path in GitHub repo
    LocalPath TEXT NOT NULL,        -- Absolute path on disk
    DownloadedAt TEXT NOT NULL,     -- ISO 8601 format
    ExpiresAt TEXT NOT NULL,        -- ISO 8601 format
    SizeBytes INTEGER NOT NULL,
    SHA256 TEXT NOT NULL            -- File hash for integrity
);
```

#### Table: Favorites (Agent 1 Addition)

```sql
CREATE TABLE Favorites (
    ToolId TEXT PRIMARY KEY,           -- Tool identifier
    Position INTEGER NOT NULL,          -- Sort order (for drag-and-drop reordering)
    IsPinned INTEGER NOT NULL DEFAULT 0, -- 1 = pinned to Dashboard Quick Run bar
    AddedAt TEXT NOT NULL               -- ISO 8601 format
);

CREATE INDEX idx_favorites_position ON Favorites(Position);
```

#### Table: Logs (optional - if not using file logging)

```sql
CREATE TABLE Logs (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Timestamp TEXT NOT NULL,
    Level TEXT NOT NULL,            -- 'DEBUG', 'INFO', 'WARN', 'ERROR'
    Message TEXT NOT NULL,
    Exception TEXT,
    ToolId TEXT
);

CREATE INDEX idx_logs_timestamp ON Logs(Timestamp);
CREATE INDEX idx_logs_level ON Logs(Level);
```

---

## Deployment Strategy

### Installation Package

**Installer Type:** MSI (Windows Installer)

**File:** `BepozToolkit-Setup-v2.0.0.msi`

**Installation Path:** `C:\Program Files\Bepoz\BepozToolkit\`

**Components:**
- `BepozToolkit.exe` (main launcher)
- `BepozToolkit.Core.dll`
- Dependencies (MaterialDesignThemes, System.Management.Automation, etc.)
- `icon.ico`

**Data Path:** `%LOCALAPPDATA%\BepozToolkit\`
- `BepozToolkit.db` (SQLite database)
- `Cache\` (cached PS1 files)
- `Logs\` (Serilog log files)

**Shortcuts:**
- Start Menu: `Bepoz\Bepoz Toolkit`
- Desktop: `Bepoz Toolkit` (optional)

### System Requirements

- **OS:** Windows 10 version 1809 or later, Windows 11, Windows Server 2019+
- **Framework:** .NET 6 Runtime or later (included in installer)
- **PowerShell:** PowerShell 5.1+ (built into Windows)
- **RAM:** 512 MB minimum
- **Disk:** 100 MB for application + cache
- **Network:** Internet connection (for tool updates)

### Unattended Installation

```powershell
# Silent install
msiexec /i BepozToolkit-Setup-v2.0.0.msi /quiet /qn

# Silent install with log
msiexec /i BepozToolkit-Setup-v2.0.0.msi /quiet /qn /l*v install.log

# Unattended with custom install path
msiexec /i BepozToolkit-Setup-v2.0.0.msi /quiet INSTALLDIR="C:\Custom\Path"
```

### Group Policy Deployment

**MSI supports deployment via GPO:**

1. Place MSI on network share
2. Create new GPO in Active Directory
3. Assign package to Computers or Users
4. Application installs automatically on login/startup

---

## Auto-Update Mechanism

### Launcher Updates

**Check on Startup:**

1. On application start, call `IGitHubService.CheckForLauncherUpdateAsync()`
2. Compare current version with latest GitHub Release
3. If newer version available:
   - Show notification: "Update available: v2.1.0 → Download & Install"
   - User clicks → Download new MSI
   - Run installer with `/quiet /passive` flags
   - Exit current application
   - New version launches automatically

**Version Storage:**
- Current version stored in `AssemblyInfo.cs` and `Product.wxs`
- GitHub Releases tagged as `v2.0.0`, `v2.1.0`, etc.
- Release assets include MSI file

### Tool Updates

**Automatic and Transparent:**

1. Tools are never "updated" locally - they're always fetched fresh
2. Cache expires after 1 hour (configurable)
3. When tool is run:
   - Check if cached version exists and not expired
   - If expired or missing → download from GitHub
   - Cache locally
   - Execute
4. User always gets latest tool version automatically

**Benefits:**
- No user intervention required
- Tools update without launcher updates
- IT team can push tool fixes instantly

---

## Migration Path

### Backward Compatibility

**Existing PS1 tools work without modification!**

The launcher executes PS1 files exactly as they are today. No changes required.

### Transition Plan

**Phase 1: Parallel Deployment (Weeks 1-2)**
- Deploy Hybrid Launcher to pilot users (IT team)
- Keep existing `Invoke-BepozToolkit-GUI.ps1` available
- Monitor for issues

**Phase 2: Gradual Rollout (Weeks 3-4)**
- Deploy to 25% of users
- Gather feedback
- Fix any compatibility issues

**Phase 3: Full Deployment (Week 5)**
- Deploy to all users via Group Policy
- Deprecate old PS1 launcher

**Phase 4: Cleanup (Week 6+)**
- Remove old shortcuts
- Archive `bootstrap/` folder in GitHub repo

### Fallback Strategy

If critical issues found:
1. Launcher can be uninstalled via Control Panel
2. Old PS1 launcher still works from GitHub
3. No data loss (tools remain unchanged)

---

## Risk Analysis

### Technical Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **PowerShell execution fails from C#** | High | Extensive testing with System.Management.Automation SDK; fallback to Process.Start if needed |
| **Module dot-sourcing doesn't work** | Medium | Test with actual Bepoz modules early; ensure paths are absolute |
| **GitHub API rate limiting** | Medium | Implement caching; use authenticated requests (higher rate limit) |
| **Offline mode fails** | Medium | Robust cache validation; clear error messages when tools unavailable |
| **Installer conflicts with existing software** | Low | Test on clean VMs; use standard MSI practices |
| **Performance issues on older hardware** | Low | Profile on low-end machines; optimize startup time |

### User Experience Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Users confused by new UI** | Medium | Training session; user guide; tooltips; maintain familiar concepts |
| **Admin elevation issues** | Medium | Clear prompts for tools requiring admin; test elevation flow |
| **Database corruption** | Low | SQLite is robust; implement backup/restore; database is small |

### Schedule Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| **21-day timeline too aggressive** | Medium | Focus on MVP first; defer advanced features if needed; modularity allows phased delivery |
| **Unexpected technical blockers** | Medium | Build in 2-3 day buffer; parallel workstreams where possible |

---

## Success Metrics

### Technical Metrics

- **Startup Time:** < 2 seconds (from double-click to UI ready)
- **Tool Execution Time:** < 5 seconds overhead (download + cache + launch)
- **Cache Hit Rate:** > 80% (most tools run from cache)
- **Success Rate:** > 95% (tool executions complete successfully)
- **Crash Rate:** < 1% (application crashes per session)

### User Experience Metrics

- **User Satisfaction:** > 4.0/5.0 (survey after 2 weeks)
- **Tool Discovery:** Users find 25% more tools than with old launcher
- **Support Tickets:** < 5 tickets per 100 users in first month
- **Adoption Rate:** > 90% of users switch within 4 weeks

### Business Metrics

- **Deployment Time:** < 1 hour for full organization
- **Maintenance Time:** < 2 hours/week for IT team
- **Tool Update Speed:** < 5 minutes from commit to user availability

---

## Timeline

### Gantt Chart (Text Format)

```
Week 1: Foundation & Core Services
├─ Day 1:  Project setup, NuGet packages                    ████
├─ Day 2:  Core models, IGitHubService                      ████
├─ Day 3:  SQLite setup, ISettingsService                   ████
├─ Day 4:  IPowerShellHost interface                        ████
├─ Day 5:  PowerShell execution engine                      ████
├─ Day 6:  PS1 testing, module loading                      ████
└─ Day 7:  Cache & stats services                           ████

Week 2: UI Implementation
├─ Day 8:  Cache completion & testing                       ████
├─ Day 9:  MainWindow, navigation                           ████
├─ Day 10: Dashboard UI                                     ████
├─ Day 11: Tools browser                                    ████
├─ Day 12: Tool cards, search/filter                        ████
├─ Day 13: Tool execution window                            ████
└─ Day 14: Logs & Settings tabs                             ████

Week 3: Polish, Deploy, Test
├─ Day 15: Auto-update mechanism                            ████
├─ Day 16: Error handling & logging                         ████
├─ Day 17: Performance optimization                         ████
├─ Day 18: WiX installer                                    ████
├─ Day 19: Installer testing                                ████
├─ Day 20: Unit & integration tests                         ████
└─ Day 21: Documentation & demo                             ████
```

### Milestones

- **Day 3:** ✅ Solution compiles, can fetch manifest from GitHub
- **Day 6:** ✅ Can execute PS1 files from C# successfully
- **Day 8:** ✅ Tools cached locally, statistics tracked
- **Day 14:** ✅ Fully functional UI, all tabs working
- **Day 17:** ✅ Feature complete
- **Day 19:** ✅ Installer ready
- **Day 21:** ✅ **LAUNCH READY** 🚀

---

## Next Steps

### Immediate Actions (Before Coding)

1. ✅ **This document** - Implementation plan created
2. **User Review** - Get approval from IT team on architecture and UI mockups
3. **Environment Setup** - Install Visual Studio 2022, WiX Toolset
4. **GitHub Prep** - Create GitHub project board with tasks from this plan
5. **Pilot Users** - Identify 5-10 IT staff for beta testing

### Development Kickoff (Day 1)

1. Create Visual Studio solution: `BepozToolkit.sln`
2. Create GitHub issues for all 21 days of tasks
3. Set up CI/CD pipeline (GitHub Actions)
4. Begin Phase 1: Foundation

---

## Appendix A: Alternative Approaches Considered

### Option 1: Pure PowerShell (Current)
❌ **Rejected** - Limitations in UI, persistence, startup speed

### Option 2: Pure Compiled Exe
❌ **Rejected** - Loses auto-update flexibility for tools

### Option 3: Hybrid Launcher (SELECTED)
✅ **Best of both worlds** - Modern UI + tool flexibility

### Option 4: Web Application
❌ **Rejected** - Requires IIS/hosting, internet dependency, overkill

---

## Appendix B: Code Snippets

### Example: PowerShell Execution from C#

```csharp
public async Task<ToolExecutionResult> ExecuteScriptAsync(
    string scriptPath,
    Action<string> outputCallback = null)
{
    using var runspace = RunspaceFactory.CreateRunspace();
    runspace.Open();

    using var powershell = PowerShell.Create();
    powershell.Runspace = runspace;

    // Add script
    powershell.AddScript(File.ReadAllText(scriptPath));

    // Capture output
    powershell.Streams.Information.DataAdded += (sender, e) =>
    {
        var info = powershell.Streams.Information[e.Index];
        outputCallback?.Invoke(info.ToString());
    };

    // Execute
    var results = await Task.Run(() => powershell.Invoke());

    return new ToolExecutionResult
    {
        Success = !powershell.HadErrors,
        Output = string.Join("\n", results),
        Error = string.Join("\n", powershell.Streams.Error)
    };
}
```

### Example: GitHub File Download

```csharp
public async Task<string> GetFileContentAsync(string filePath)
{
    var client = new GitHubClient(new ProductHeaderValue("BepozToolkit"));

    var contents = await client.Repository.Content.GetAllContents(
        _settings.GitHubOwner,
        _settings.GitHubRepo,
        filePath
    );

    return contents[0].Content;
}
```

---

## Appendix C: Resources

### Documentation
- [WPF Documentation](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/)
- [MaterialDesignInXaml](https://github.com/MaterialDesignInXAML/MaterialDesignInXamlToolkit)
- [System.Management.Automation SDK](https://learn.microsoft.com/en-us/powershell/scripting/developer/hosting/windows-powershell-host-quickstart)
- [Octokit.NET](https://octokitnet.readthedocs.io/)
- [WiX Toolset](https://wixtoolset.org/docs/)

### Sample Projects
- [ModernWpfApp](https://github.com/Kinnara/ModernWpf) - Modern WPF UI
- [PowerShellHostSample](https://github.com/PowerShell/PowerShell/tree/master/docs/host-powershell) - Hosting PowerShell

---

**END OF DOCUMENT**

---

*This implementation plan provides a complete roadmap for building the Bepoz Toolkit Hybrid Launcher. All sections are designed to be actionable and include sufficient technical detail for immediate development work.*

*For questions or clarifications, contact the Bepoz IT team or refer to the GitHub repository wiki.*
