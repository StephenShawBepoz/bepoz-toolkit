using System.Collections.ObjectModel;
using System.Windows.Input;
using System.Windows.Threading;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;

namespace BepozToolkit.App.ViewModels;

public class SettingsViewModel : ViewModelBase
{
    private readonly ISettingsService _settingsService;
    private readonly IConnectionService _connectionService;
    private readonly ICacheService _cacheService;
    private readonly IToastService _toastService;
    private readonly DispatcherTimer _debounceTimer;

    private string _theme = "BepozLight";
    private bool _enableAnimations = true;
    private bool _enableToastNotifications = true;
    private bool _minimizeToSystemTray = true;
    private string _gitHubOwner = "";
    private string _gitHubRepo = "";
    private string _gitHubBranch = "";
    private int _cacheExpirationMinutes = 60;
    private string _logLevel = "Info";
    private long _cacheSize;
    private int _cacheFileCount;
    private bool _isLoading;
    private SavedConnection? _selectedConnection;
    private bool _isTesting;
    private string _testResult = "";

    public SettingsViewModel(
        ISettingsService settingsService,
        IConnectionService connectionService,
        ICacheService cacheService,
        IToastService toastService)
    {
        _settingsService = settingsService;
        _connectionService = connectionService;
        _cacheService = cacheService;
        _toastService = toastService;

        SavedConnections = new ObservableCollection<SavedConnection>();
        LogLevels = new ObservableCollection<string> { "Verbose", "Debug", "Info", "Warning", "Error" };

        LoadSettingsCommand = new AsyncRelayCommand(LoadSettingsAsync);
        ResetToDefaultsCommand = new AsyncRelayCommand(ResetToDefaultsAsync);
        AddConnectionCommand = new AsyncRelayCommand(AddConnectionAsync);
        EditConnectionCommand = new AsyncRelayCommand(EditConnectionAsync);
        DeleteConnectionCommand = new AsyncRelayCommand(DeleteConnectionAsync);
        TestConnectionCommand = new AsyncRelayCommand(TestConnectionAsync);
        ClearCacheCommand = new AsyncRelayCommand(ClearCacheAsync);
        SaveSettingsCommand = new AsyncRelayCommand(SaveSettingsAsync);

        _debounceTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500)
        };
        _debounceTimer.Tick += async (_, _) =>
        {
            _debounceTimer.Stop();
            await SaveSettingsAsync();
        };
    }

    public string Theme
    {
        get => _theme;
        set
        {
            if (SetProperty(ref _theme, value))
            {
                OnPropertyChanged(nameof(IsDarkTheme));
                ScheduleAutoSave();
            }
        }
    }

    public bool IsDarkTheme
    {
        get => _theme == "BepozDark";
        set => Theme = value ? "BepozDark" : "BepozLight";
    }

    public bool EnableAnimations
    {
        get => _enableAnimations;
        set
        {
            if (SetProperty(ref _enableAnimations, value))
                ScheduleAutoSave();
        }
    }

    public bool EnableToastNotifications
    {
        get => _enableToastNotifications;
        set
        {
            if (SetProperty(ref _enableToastNotifications, value))
                ScheduleAutoSave();
        }
    }

    public bool MinimizeToSystemTray
    {
        get => _minimizeToSystemTray;
        set
        {
            if (SetProperty(ref _minimizeToSystemTray, value))
                ScheduleAutoSave();
        }
    }

    public string GitHubOwner
    {
        get => _gitHubOwner;
        set
        {
            if (SetProperty(ref _gitHubOwner, value))
                ScheduleAutoSave();
        }
    }

    public string GitHubRepo
    {
        get => _gitHubRepo;
        set
        {
            if (SetProperty(ref _gitHubRepo, value))
                ScheduleAutoSave();
        }
    }

    public string GitHubBranch
    {
        get => _gitHubBranch;
        set
        {
            if (SetProperty(ref _gitHubBranch, value))
                ScheduleAutoSave();
        }
    }

    public int CacheExpirationMinutes
    {
        get => _cacheExpirationMinutes;
        set
        {
            if (SetProperty(ref _cacheExpirationMinutes, value))
                ScheduleAutoSave();
        }
    }

    public string LogLevel
    {
        get => _logLevel;
        set
        {
            if (SetProperty(ref _logLevel, value))
                ScheduleAutoSave();
        }
    }

    public long CacheSize
    {
        get => _cacheSize;
        set => SetProperty(ref _cacheSize, value);
    }

    public int CacheFileCount
    {
        get => _cacheFileCount;
        set => SetProperty(ref _cacheFileCount, value);
    }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public SavedConnection? SelectedConnection
    {
        get => _selectedConnection;
        set => SetProperty(ref _selectedConnection, value);
    }

    public bool IsTesting
    {
        get => _isTesting;
        set => SetProperty(ref _isTesting, value);
    }

    public string TestResult
    {
        get => _testResult;
        set => SetProperty(ref _testResult, value);
    }

    public ObservableCollection<SavedConnection> SavedConnections { get; }
    public ObservableCollection<string> LogLevels { get; }

    public ICommand LoadSettingsCommand { get; }
    public ICommand ResetToDefaultsCommand { get; }
    public ICommand AddConnectionCommand { get; }
    public ICommand EditConnectionCommand { get; }
    public ICommand DeleteConnectionCommand { get; }
    public ICommand TestConnectionCommand { get; }
    public ICommand ClearCacheCommand { get; }
    public ICommand SaveSettingsCommand { get; }

    public async Task LoadSettingsAsync()
    {
        IsLoading = true;
        try
        {
            var settings = await _settingsService.LoadSettingsAsync();

            _theme = settings.Theme;
            _enableAnimations = settings.EnableAnimations;
            _enableToastNotifications = settings.EnableToastNotifications;
            _minimizeToSystemTray = settings.MinimizeToSystemTray;

            OnPropertyChanged(nameof(Theme));
            OnPropertyChanged(nameof(EnableAnimations));
            OnPropertyChanged(nameof(EnableToastNotifications));
            OnPropertyChanged(nameof(MinimizeToSystemTray));

            GitHubOwner = await _settingsService.GetSettingAsync("GitHubOwner", BepozToolkit.Core.Constants.GitHubOwner);
            GitHubRepo = await _settingsService.GetSettingAsync("GitHubRepo", BepozToolkit.Core.Constants.GitHubRepo);
            GitHubBranch = await _settingsService.GetSettingAsync("GitHubBranch", BepozToolkit.Core.Constants.GitHubBranch);
            CacheExpirationMinutes = await _settingsService.GetSettingAsync("CacheExpirationMinutes", BepozToolkit.Core.Constants.DefaultCacheExpirationMinutes);
            LogLevel = await _settingsService.GetSettingAsync("LogLevel", "Info");

            CacheSize = _cacheService.GetCacheSizeBytes();
            CacheFileCount = _cacheService.GetCacheFileCount();

            var connections = await _connectionService.GetAllConnectionsAsync();
            SavedConnections.Clear();
            foreach (var conn in connections)
            {
                SavedConnections.Add(conn);
            }
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to load settings: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async Task SaveSettingsAsync()
    {
        try
        {
            var settings = await _settingsService.LoadSettingsAsync();

            settings.Theme = Theme;
            settings.EnableAnimations = EnableAnimations;
            settings.EnableToastNotifications = EnableToastNotifications;
            settings.MinimizeToSystemTray = MinimizeToSystemTray;

            await _settingsService.SaveSettingsAsync(settings);

            await _settingsService.SetSettingAsync("GitHubOwner", GitHubOwner);
            await _settingsService.SetSettingAsync("GitHubRepo", GitHubRepo);
            await _settingsService.SetSettingAsync("GitHubBranch", GitHubBranch);
            await _settingsService.SetSettingAsync("CacheExpirationMinutes", CacheExpirationMinutes);
            await _settingsService.SetSettingAsync("LogLevel", LogLevel);
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to save settings: {ex.Message}");
        }
    }

    private void ScheduleAutoSave()
    {
        if (_isLoading) return; // Don't auto-save during initial load
        _debounceTimer.Stop();
        _debounceTimer.Start();
    }

    private async Task ResetToDefaultsAsync()
    {
        await _settingsService.ResetToDefaultsAsync();
        await LoadSettingsAsync();
        _toastService.ShowSuccess("Settings reset to defaults.");
    }

    private async Task AddConnectionAsync()
    {
        var newConnection = new SavedConnection
        {
            Name = "New Connection",
            Server = "localhost",
            DatabaseName = "BepozDB",
            AuthType = "Windows"
        };

        await _connectionService.SaveConnectionAsync(newConnection);
        SavedConnections.Add(newConnection);
        SelectedConnection = newConnection;
        _toastService.ShowInfo("New connection added. Edit the details below.");
    }

    private async Task EditConnectionAsync()
    {
        if (SelectedConnection is null)
        {
            _toastService.ShowWarning("Select a connection to edit.");
            return;
        }

        await _connectionService.SaveConnectionAsync(SelectedConnection);
        _toastService.ShowSuccess($"Connection '{SelectedConnection.Name}' saved.");
    }

    private async Task DeleteConnectionAsync()
    {
        if (SelectedConnection is null)
        {
            _toastService.ShowWarning("Select a connection to delete.");
            return;
        }

        var name = SelectedConnection.Name;
        await _connectionService.DeleteConnectionAsync(SelectedConnection.Id);
        SavedConnections.Remove(SelectedConnection);
        SelectedConnection = SavedConnections.FirstOrDefault();
        _toastService.ShowSuccess($"Connection '{name}' deleted.");
    }

    private async Task TestConnectionAsync()
    {
        if (SelectedConnection is null)
        {
            _toastService.ShowWarning("Select a connection to test.");
            return;
        }

        IsTesting = true;
        TestResult = "Testing connection...";

        try
        {
            var (success, message) = await _connectionService.TestConnectionAsync(SelectedConnection);
            TestResult = message;

            if (success)
                _toastService.ShowSuccess($"Connection to '{SelectedConnection.Name}' successful.");
            else
                _toastService.ShowError($"Connection test failed: {message}");
        }
        catch (Exception ex)
        {
            TestResult = $"Error: {ex.Message}";
            _toastService.ShowError($"Connection test error: {ex.Message}");
        }
        finally
        {
            IsTesting = false;
        }
    }

    private async Task ClearCacheAsync()
    {
        try
        {
            await _cacheService.ClearCacheAsync();
            CacheSize = _cacheService.GetCacheSizeBytes();
            CacheFileCount = _cacheService.GetCacheFileCount();
            _toastService.ShowSuccess("Cache cleared successfully.");
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to clear cache: {ex.Message}");
        }
    }
}
