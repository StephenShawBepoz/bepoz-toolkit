using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;
using Serilog;

namespace BepozToolkit.App.ViewModels;

/// <summary>
/// Primary ViewModel for the MainWindow shell. Manages navigation, theme switching,
/// periodic health checks, offline detection, and toast notifications.
/// </summary>
public class MainViewModel : ViewModelBase, IDisposable
{
    private readonly IGitHubService _gitHubService;
    private readonly ICacheService _cacheService;
    private readonly IPowerShellHost _powerShellHost;
    private readonly ISettingsService _settingsService;
    private readonly IToastService _toastService;
    private readonly DispatcherTimer _healthTimer;
    private bool _disposed;

    // ------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------

    public MainViewModel(
        IGitHubService gitHubService,
        ICacheService cacheService,
        IPowerShellHost powerShellHost,
        ISettingsService settingsService,
        IToastService toastService)
    {
        _gitHubService = gitHubService;
        _cacheService = cacheService;
        _powerShellHost = powerShellHost;
        _settingsService = settingsService;
        _toastService = toastService;

        // Commands
        NavigateCommand = new RelayCommand<string>(OnNavigate);
        ToggleThemeCommand = new RelayCommand(OnToggleTheme);
        RefreshCommand = new AsyncRelayCommand(OnRefreshAsync);

        // Toast integration
        _toastService.OnToastRequested += OnToastReceived;

        // Start on Dashboard
        _selectedTab = "Dashboard";

        // Health check timer
        _healthTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(Constants.HealthCheckIntervalMs)
        };
        _healthTimer.Tick += async (_, _) =>
        {
            try { await RunHealthChecksAsync(); }
            catch (Exception ex) { Log.Warning(ex, "Health check failed"); }
        };
        _healthTimer.Start();

        // Run initial health check (fire and forget on UI thread)
        _ = RunHealthChecksAsync();
    }

    // ------------------------------------------------------------------
    // Navigation
    // ------------------------------------------------------------------

    private string _selectedTab;
    public string SelectedTab
    {
        get => _selectedTab;
        set
        {
            if (SetProperty(ref _selectedTab, value))
            {
                OnPropertyChanged(nameof(IsDashboardSelected));
                OnPropertyChanged(nameof(IsToolsSelected));
                OnPropertyChanged(nameof(IsLogsSelected));
                OnPropertyChanged(nameof(IsSettingsSelected));
            }
        }
    }

    public bool IsDashboardSelected => SelectedTab == "Dashboard";
    public bool IsToolsSelected => SelectedTab == "Tools";
    public bool IsLogsSelected => SelectedTab == "Logs";
    public bool IsSettingsSelected => SelectedTab == "Settings";

    public ICommand NavigateCommand { get; }

    private void OnNavigate(string? tab)
    {
        if (!string.IsNullOrEmpty(tab))
        {
            SelectedTab = tab;
            Log.Debug("Navigated to {Tab}", tab);
        }
    }

    // ------------------------------------------------------------------
    // Theme
    // ------------------------------------------------------------------

    private bool _isDarkTheme;
    public bool IsDarkTheme
    {
        get => _isDarkTheme;
        set
        {
            if (SetProperty(ref _isDarkTheme, value))
            {
                var themeName = value ? "BepozDark" : "BepozLight";
                App.ApplyTheme(themeName);
                _ = SaveThemePreferenceAsync(themeName);
            }
        }
    }

    public ICommand ToggleThemeCommand { get; }

    private void OnToggleTheme()
    {
        IsDarkTheme = !IsDarkTheme;
    }

    private async Task SaveThemePreferenceAsync(string themeName)
    {
        try
        {
            var settings = await _settingsService.LoadSettingsAsync();
            settings.Theme = themeName;
            await _settingsService.SaveSettingsAsync(settings);
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to persist theme preference");
        }
    }

    // ------------------------------------------------------------------
    // Refresh (Ctrl+R)
    // ------------------------------------------------------------------

    public ICommand RefreshCommand { get; }

    private async Task OnRefreshAsync()
    {
        Log.Information("Manual refresh triggered");
        await RunHealthChecksAsync();
        _toastService.ShowInfo("Dashboard refreshed.");
    }

    // ------------------------------------------------------------------
    // Health Status
    // ------------------------------------------------------------------

    private string _gitHubStatus = "Checking...";
    public string GitHubStatus
    {
        get => _gitHubStatus;
        set => SetProperty(ref _gitHubStatus, value);
    }

    private string _gitHubStatusLevel = "Info";
    public string GitHubStatusLevel
    {
        get => _gitHubStatusLevel;
        set => SetProperty(ref _gitHubStatusLevel, value);
    }

    private string _cacheStatus = "Checking...";
    public string CacheStatus
    {
        get => _cacheStatus;
        set => SetProperty(ref _cacheStatus, value);
    }

    private string _cacheStatusLevel = "Info";
    public string CacheStatusLevel
    {
        get => _cacheStatusLevel;
        set => SetProperty(ref _cacheStatusLevel, value);
    }

    private string _psStatus = "Checking...";
    public string PsStatus
    {
        get => _psStatus;
        set => SetProperty(ref _psStatus, value);
    }

    private string _psStatusLevel = "Info";
    public string PsStatusLevel
    {
        get => _psStatusLevel;
        set => SetProperty(ref _psStatusLevel, value);
    }

    // ------------------------------------------------------------------
    // Offline Banner
    // ------------------------------------------------------------------

    private bool _isOffline;
    public bool IsOffline
    {
        get => _isOffline;
        set => SetProperty(ref _isOffline, value);
    }

    // ------------------------------------------------------------------
    // Toast Notifications
    // ------------------------------------------------------------------

    public ObservableCollection<ToastMessage> ActiveToasts { get; } = new();

    private void OnToastReceived(ToastMessage toast)
    {
        // Marshal to UI thread
        Application.Current?.Dispatcher.Invoke(() =>
        {
            ActiveToasts.Add(toast);

            if (toast.AutoDismiss)
            {
                var timer = new DispatcherTimer
                {
                    Interval = TimeSpan.FromMilliseconds(toast.DismissAfterMs)
                };
                timer.Tick += (_, _) =>
                {
                    timer.Stop();
                    ActiveToasts.Remove(toast);
                };
                timer.Start();
            }
        });
    }

    public RelayCommand<ToastMessage> DismissToastCommand => new(toast =>
    {
        if (toast != null)
            ActiveToasts.Remove(toast);
    });

    // ------------------------------------------------------------------
    // App info
    // ------------------------------------------------------------------

    public string AppTitle => Constants.AppName;
    public string AppVersion => $"v{Constants.AppVersion}";

    // ------------------------------------------------------------------
    // Health Check Logic
    // ------------------------------------------------------------------

    private async Task RunHealthChecksAsync()
    {
        // GitHub connectivity
        try
        {
            var connected = await _gitHubService.IsConnectedAsync();
            IsOffline = !connected;
            GitHubStatus = connected ? "Connected" : "Offline";
            GitHubStatusLevel = connected ? "Success" : "Error";
        }
        catch (Exception ex)
        {
            IsOffline = true;
            GitHubStatus = "Error";
            GitHubStatusLevel = "Error";
            Log.Warning(ex, "GitHub health check failed");
        }

        // Cache status
        try
        {
            var fileCount = _cacheService.GetCacheFileCount();
            var sizeBytes = _cacheService.GetCacheSizeBytes();
            var sizeMb = sizeBytes / (1024.0 * 1024.0);
            CacheStatus = $"{fileCount} files ({sizeMb:F1} MB)";
            CacheStatusLevel = fileCount > 0 ? "Success" : "Warning";
        }
        catch (Exception ex)
        {
            CacheStatus = "Error";
            CacheStatusLevel = "Error";
            Log.Warning(ex, "Cache health check failed");
        }

        // PowerShell status
        try
        {
            var version = _powerShellHost.GetPowerShellVersion();
            PsStatus = $"PS {version}";
            PsStatusLevel = "Success";
        }
        catch (Exception ex)
        {
            PsStatus = "Unavailable";
            PsStatusLevel = "Error";
            Log.Warning(ex, "PowerShell health check failed");
        }
    }

    // ------------------------------------------------------------------
    // Dispose
    // ------------------------------------------------------------------

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;

        _healthTimer.Stop();
        _toastService.OnToastRequested -= OnToastReceived;

        GC.SuppressFinalize(this);
    }
}
