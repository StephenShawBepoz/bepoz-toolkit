using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Input;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;

namespace BepozToolkit.App.ViewModels;

public class TSPlusManagerViewModel : ViewModelBase
{
    private readonly ITSPlusService _tsPlusService;
    private readonly IHistoryService _historyService;
    private readonly IStatsService _statsService;
    private readonly IToastService _toastService;

    // General state
    private int _selectedTabIndex;
    private bool _isLoading;
    private string _statusText = "Ready";

    // Uninstaller tab
    private bool _backupBeforeUninstall = true;
    private bool _isUninstalling;
    private int _uninstallProgress;

    // License tab
    private string _licenseKey = "";
    private TSPlusLicenseInfo _licenseInfo = new();
    private bool _isApplyingLicense;

    // Services tab
    private TSPlusServiceInfo? _selectedService;

    // Backup tab
    private string _backupDescription = "";
    private TSPlusBackupInfo? _selectedBackup;
    private bool _isBackingUp;
    private bool _isRestoring;

    // Updates tab
    private string _currentVersion = "";
    private string _updateUrl = "https://dl-files.com/TSplus-Setup.exe";
    private bool _isDownloadingUpdate;
    private int _updateProgress;

    // Ports tab
    private bool _isCreatingFirewallRules;

    // Connections tab
    private bool _isRefreshingConnections;

    // Shared
    private CancellationTokenSource? _cts;

    public TSPlusManagerViewModel(
        ITSPlusService tsPlusService,
        IHistoryService historyService,
        IStatsService statsService,
        IToastService toastService)
    {
        _tsPlusService = tsPlusService;
        _historyService = historyService;
        _statsService = statsService;
        _toastService = toastService;

        OutputLines = new ObservableCollection<string>();
        Services = new ObservableCollection<TSPlusServiceInfo>();
        Backups = new ObservableCollection<TSPlusBackupInfo>();
        Ports = new ObservableCollection<TSPlusPortInfo>();
        Connections = new ObservableCollection<TSPlusConnectionInfo>();

        // Uninstaller commands
        UninstallCommand = new AsyncRelayCommand(UninstallAsync, () => !IsUninstalling);

        // License commands
        ApplyLicenseCommand = new AsyncRelayCommand(ApplyLicenseAsync, () => !IsApplyingLicense && !string.IsNullOrWhiteSpace(LicenseKey));
        RefreshLicenseCommand = new AsyncRelayCommand(RefreshLicenseAsync);
        OpenAdminToolCommand = new RelayCommand(() => _tsPlusService.OpenAdminTool());

        // Services commands
        StartServiceCommand = new AsyncRelayCommand(StartServiceAsync, () => SelectedService != null);
        StopServiceCommand = new AsyncRelayCommand(StopServiceAsync, () => SelectedService != null);
        RestartServiceCommand = new AsyncRelayCommand(RestartServiceAsync, () => SelectedService != null);
        RefreshServicesCommand = new AsyncRelayCommand(RefreshServicesAsync);

        // Backup commands
        CreateBackupCommand = new AsyncRelayCommand(CreateBackupAsync, () => !IsBackingUp);
        RestoreBackupCommand = new AsyncRelayCommand(RestoreBackupAsync, () => SelectedBackup != null && !IsRestoring);
        RefreshBackupsCommand = new AsyncRelayCommand(RefreshBackupsAsync);

        // Updates commands
        DownloadUpdateCommand = new AsyncRelayCommand(DownloadUpdateAsync, () => !IsDownloadingUpdate);

        // Ports commands
        RefreshPortsCommand = new AsyncRelayCommand(RefreshPortsAsync);
        CreateFirewallRulesCommand = new AsyncRelayCommand(CreateFirewallRulesAsync, () => !IsCreatingFirewallRules);

        // Connections commands
        RefreshConnectionsCommand = new AsyncRelayCommand(RefreshConnectionsAsync, () => !IsRefreshingConnections);

        // Copy/Log
        CopyLogCommand = new RelayCommand(CopyLog);
        OpenLogCommand = new RelayCommand(OpenLog);
    }

    // ======================================================================
    // Collections
    // ======================================================================

    public ObservableCollection<string> OutputLines { get; }
    public ObservableCollection<TSPlusServiceInfo> Services { get; }
    public ObservableCollection<TSPlusBackupInfo> Backups { get; }
    public ObservableCollection<TSPlusPortInfo> Ports { get; }
    public ObservableCollection<TSPlusConnectionInfo> Connections { get; }

    // ======================================================================
    // General Properties
    // ======================================================================

    public int SelectedTabIndex
    {
        get => _selectedTabIndex;
        set
        {
            if (SetProperty(ref _selectedTabIndex, value))
                _ = OnTabChangedAsync(value);
        }
    }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public string StatusText
    {
        get => _statusText;
        set => SetProperty(ref _statusText, value);
    }

    // ======================================================================
    // Uninstaller Properties
    // ======================================================================

    public bool BackupBeforeUninstall
    {
        get => _backupBeforeUninstall;
        set => SetProperty(ref _backupBeforeUninstall, value);
    }

    public bool IsUninstalling
    {
        get => _isUninstalling;
        set => SetProperty(ref _isUninstalling, value);
    }

    public int UninstallProgress
    {
        get => _uninstallProgress;
        set => SetProperty(ref _uninstallProgress, value);
    }

    // ======================================================================
    // License Properties
    // ======================================================================

    public string LicenseKey
    {
        get => _licenseKey;
        set => SetProperty(ref _licenseKey, value);
    }

    public TSPlusLicenseInfo LicenseInfo
    {
        get => _licenseInfo;
        set => SetProperty(ref _licenseInfo, value);
    }

    public bool IsApplyingLicense
    {
        get => _isApplyingLicense;
        set => SetProperty(ref _isApplyingLicense, value);
    }

    // ======================================================================
    // Services Properties
    // ======================================================================

    public TSPlusServiceInfo? SelectedService
    {
        get => _selectedService;
        set => SetProperty(ref _selectedService, value);
    }

    // ======================================================================
    // Backup Properties
    // ======================================================================

    public string BackupDescription
    {
        get => _backupDescription;
        set => SetProperty(ref _backupDescription, value);
    }

    public TSPlusBackupInfo? SelectedBackup
    {
        get => _selectedBackup;
        set => SetProperty(ref _selectedBackup, value);
    }

    public bool IsBackingUp
    {
        get => _isBackingUp;
        set => SetProperty(ref _isBackingUp, value);
    }

    public bool IsRestoring
    {
        get => _isRestoring;
        set => SetProperty(ref _isRestoring, value);
    }

    // ======================================================================
    // Updates Properties
    // ======================================================================

    public string CurrentVersion
    {
        get => _currentVersion;
        set => SetProperty(ref _currentVersion, value);
    }

    public string UpdateUrl
    {
        get => _updateUrl;
        set => SetProperty(ref _updateUrl, value);
    }

    public bool IsDownloadingUpdate
    {
        get => _isDownloadingUpdate;
        set => SetProperty(ref _isDownloadingUpdate, value);
    }

    public int UpdateProgress
    {
        get => _updateProgress;
        set => SetProperty(ref _updateProgress, value);
    }

    // ======================================================================
    // Ports Properties
    // ======================================================================

    public bool IsCreatingFirewallRules
    {
        get => _isCreatingFirewallRules;
        set => SetProperty(ref _isCreatingFirewallRules, value);
    }

    // ======================================================================
    // Connections Properties
    // ======================================================================

    public bool IsRefreshingConnections
    {
        get => _isRefreshingConnections;
        set => SetProperty(ref _isRefreshingConnections, value);
    }

    // ======================================================================
    // Commands
    // ======================================================================

    // Uninstaller
    public ICommand UninstallCommand { get; }

    // License
    public ICommand ApplyLicenseCommand { get; }
    public ICommand RefreshLicenseCommand { get; }
    public ICommand OpenAdminToolCommand { get; }

    // Services
    public ICommand StartServiceCommand { get; }
    public ICommand StopServiceCommand { get; }
    public ICommand RestartServiceCommand { get; }
    public ICommand RefreshServicesCommand { get; }

    // Backup
    public ICommand CreateBackupCommand { get; }
    public ICommand RestoreBackupCommand { get; }
    public ICommand RefreshBackupsCommand { get; }

    // Updates
    public ICommand DownloadUpdateCommand { get; }

    // Ports
    public ICommand RefreshPortsCommand { get; }
    public ICommand CreateFirewallRulesCommand { get; }

    // Connections
    public ICommand RefreshConnectionsCommand { get; }

    // Shared
    public ICommand CopyLogCommand { get; }
    public ICommand OpenLogCommand { get; }

    // ======================================================================
    // Initialization
    // ======================================================================

    public async Task InitializeAsync()
    {
        await RefreshCurrentVersionAsync();
        await OnTabChangedAsync(0);
    }

    private async Task OnTabChangedAsync(int tabIndex)
    {
        switch (tabIndex)
        {
            case 0: // Uninstaller - no auto-load needed
                break;
            case 1: // License
                await RefreshLicenseAsync();
                break;
            case 2: // Services
                await RefreshServicesAsync();
                break;
            case 3: // Backup
                await RefreshBackupsAsync();
                break;
            case 4: // Updates
                await RefreshCurrentVersionAsync();
                break;
            case 5: // Ports
                await RefreshPortsAsync();
                break;
            case 6: // Connections
                await RefreshConnectionsAsync();
                break;
        }
    }

    // ======================================================================
    // Tab 1: Uninstaller
    // ======================================================================

    private async Task UninstallAsync()
    {
        IsUninstalling = true;
        UninstallProgress = 0;
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Starting TSPlus uninstallation...");

        try
        {
            if (BackupBeforeUninstall)
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Creating configuration backup...");
                UninstallProgress = 20;
                var backupPath = await _tsPlusService.BackupConfigAsync();
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Backup saved: {backupPath}");
            }

            UninstallProgress = 40;
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Running silent uninstall...");

            var success = await _tsPlusService.RunSilentUninstallAsync(
                line => Application.Current.Dispatcher.Invoke(() => AppendOutput($"  {line}")));

            UninstallProgress = 100;

            if (success)
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] TSPlus uninstalled successfully.");
                _toastService.ShowSuccess("TSPlus uninstalled successfully.");
            }
            else
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Uninstall may have failed. Check logs.");
                _toastService.ShowWarning("TSPlus uninstall completed with warnings.");
            }

            await RecordExecutionAsync("tsplus-uninstall", "TSPlus Uninstall", success);
        }
        catch (Exception ex)
        {
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] ERROR: {ex.Message}");
            _toastService.ShowError($"Uninstall failed: {ex.Message}");
            await RecordExecutionAsync("tsplus-uninstall", "TSPlus Uninstall", false);
        }
        finally
        {
            IsUninstalling = false;
        }
    }

    // ======================================================================
    // Tab 2: License
    // ======================================================================

    private async Task RefreshLicenseAsync()
    {
        LicenseInfo = await _tsPlusService.GetLicenseStatusAsync();
        StatusText = $"License: {LicenseInfo.Status}";
    }

    private async Task ApplyLicenseAsync()
    {
        if (string.IsNullOrWhiteSpace(LicenseKey)) return;

        IsApplyingLicense = true;
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Applying license key...");

        try
        {
            var success = await _tsPlusService.ApplyLicenseKeyAsync(LicenseKey);
            if (success)
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] License key applied successfully.");
                _toastService.ShowSuccess("License key applied successfully.");
                await RefreshLicenseAsync();
            }
            else
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Failed to apply license key.");
                _toastService.ShowError("Failed to apply license key.");
            }
        }
        catch (Exception ex)
        {
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] ERROR: {ex.Message}");
            _toastService.ShowError($"License error: {ex.Message}");
        }
        finally
        {
            IsApplyingLicense = false;
        }
    }

    // ======================================================================
    // Tab 3: Services
    // ======================================================================

    private async Task RefreshServicesAsync()
    {
        Services.Clear();
        var services = await _tsPlusService.GetTSPlusServicesAsync();
        foreach (var svc in services) Services.Add(svc);
        StatusText = $"{services.Count} services found";
    }

    private async Task StartServiceAsync()
    {
        if (SelectedService == null) return;
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Starting {SelectedService.DisplayName}...");

        var success = await _tsPlusService.StartServiceAsync(SelectedService.Name);
        _toastService.Show("Service", success
            ? $"{SelectedService.DisplayName} started."
            : $"Failed to start {SelectedService.DisplayName}.");

        await RefreshServicesAsync();
    }

    private async Task StopServiceAsync()
    {
        if (SelectedService == null) return;
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Stopping {SelectedService.DisplayName}...");

        var success = await _tsPlusService.StopServiceAsync(SelectedService.Name);
        _toastService.Show("Service", success
            ? $"{SelectedService.DisplayName} stopped."
            : $"Failed to stop {SelectedService.DisplayName}.");

        await RefreshServicesAsync();
    }

    private async Task RestartServiceAsync()
    {
        if (SelectedService == null) return;
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Restarting {SelectedService.DisplayName}...");

        var success = await _tsPlusService.RestartServiceAsync(SelectedService.Name);
        _toastService.Show("Service", success
            ? $"{SelectedService.DisplayName} restarted."
            : $"Failed to restart {SelectedService.DisplayName}.");

        await RefreshServicesAsync();
    }

    // ======================================================================
    // Tab 4: Backup & Restore
    // ======================================================================

    private async Task RefreshBackupsAsync()
    {
        Backups.Clear();
        var backups = await _tsPlusService.GetBackupsAsync();
        foreach (var b in backups) Backups.Add(b);
        StatusText = $"{backups.Count} backups found";
    }

    private async Task CreateBackupAsync()
    {
        IsBackingUp = true;
        var desc = string.IsNullOrWhiteSpace(BackupDescription)
            ? $"Manual backup {DateTime.Now:yyyy-MM-dd HH:mm}"
            : BackupDescription;

        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Creating backup: {desc}");

        try
        {
            var backup = await _tsPlusService.CreateBackupAsync(desc);
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Backup created: {backup.FilePath} ({backup.SizeBytes:N0} bytes)");
            _toastService.ShowSuccess("Backup created successfully.");
            BackupDescription = "";
            await RefreshBackupsAsync();
        }
        catch (Exception ex)
        {
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] ERROR: {ex.Message}");
            _toastService.ShowError($"Backup failed: {ex.Message}");
        }
        finally
        {
            IsBackingUp = false;
        }
    }

    private async Task RestoreBackupAsync()
    {
        if (SelectedBackup == null) return;

        IsRestoring = true;
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Restoring backup: {SelectedBackup.Description}");

        try
        {
            var success = await _tsPlusService.RestoreBackupAsync(SelectedBackup);
            if (success)
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Backup restored successfully.");
                _toastService.ShowSuccess("Backup restored successfully.");
            }
            else
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Restore failed.");
                _toastService.ShowError("Failed to restore backup.");
            }
        }
        catch (Exception ex)
        {
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] ERROR: {ex.Message}");
            _toastService.ShowError($"Restore failed: {ex.Message}");
        }
        finally
        {
            IsRestoring = false;
        }
    }

    // ======================================================================
    // Tab 5: Updates
    // ======================================================================

    private async Task RefreshCurrentVersionAsync()
    {
        CurrentVersion = await _tsPlusService.GetCurrentVersionAsync();
    }

    private async Task DownloadUpdateAsync()
    {
        if (string.IsNullOrWhiteSpace(UpdateUrl)) return;

        IsDownloadingUpdate = true;
        UpdateProgress = 0;
        _cts = new CancellationTokenSource();
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Downloading update from: {UpdateUrl}");

        try
        {
            var progress = new Progress<float>(p =>
            {
                Application.Current.Dispatcher.Invoke(() =>
                {
                    UpdateProgress = (int)(p * 100);
                    StatusText = $"Downloading update... {p:P0}";
                });
            });

            var filePath = await _tsPlusService.DownloadUpdateAsync(UpdateUrl, progress, _cts.Token);
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Update downloaded: {filePath}");
            _toastService.ShowSuccess("Update downloaded. Run the installer to apply.");
            StatusText = "Update downloaded";
        }
        catch (OperationCanceledException)
        {
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Download cancelled.");
            _toastService.ShowWarning("Update download cancelled.");
        }
        catch (Exception ex)
        {
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] ERROR: {ex.Message}");
            _toastService.ShowError($"Download failed: {ex.Message}");
        }
        finally
        {
            IsDownloadingUpdate = false;
            _cts?.Dispose();
            _cts = null;
        }
    }

    // ======================================================================
    // Tab 6: Ports
    // ======================================================================

    private async Task RefreshPortsAsync()
    {
        Ports.Clear();
        var ports = await _tsPlusService.GetPortStatusAsync();
        foreach (var p in ports) Ports.Add(p);
        StatusText = $"{ports.Count} ports checked";
    }

    private async Task CreateFirewallRulesAsync()
    {
        IsCreatingFirewallRules = true;
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Creating firewall rules for TSPlus ports...");

        try
        {
            var success = await _tsPlusService.CreateFirewallRulesAsync();
            if (success)
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Firewall rules created successfully.");
                _toastService.ShowSuccess("Firewall rules created.");
            }
            else
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Some firewall rules may have failed.");
                _toastService.ShowWarning("Some firewall rules may have failed.");
            }

            await RefreshPortsAsync();
        }
        catch (Exception ex)
        {
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] ERROR: {ex.Message}");
            _toastService.ShowError($"Firewall rules failed: {ex.Message}");
        }
        finally
        {
            IsCreatingFirewallRules = false;
        }
    }

    // ======================================================================
    // Tab 7: Connections
    // ======================================================================

    private async Task RefreshConnectionsAsync()
    {
        IsRefreshingConnections = true;

        try
        {
            Connections.Clear();
            var connections = await _tsPlusService.GetActiveConnectionsAsync();
            foreach (var c in connections) Connections.Add(c);
            StatusText = $"{connections.Count} active connections";
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to get connections: {ex.Message}");
        }
        finally
        {
            IsRefreshingConnections = false;
        }
    }

    // ======================================================================
    // Shared
    // ======================================================================

    private void AppendOutput(string line)
    {
        OutputLines.Add(line);
    }

    private void CopyLog()
    {
        var text = string.Join(Environment.NewLine, OutputLines);
        if (!string.IsNullOrWhiteSpace(text))
        {
            Clipboard.SetText(text);
            _toastService.ShowInfo("Log copied to clipboard.");
        }
    }

    private void OpenLog()
    {
        try
        {
            var logPath = BepozToolkit.Core.Constants.LogPath;
            if (System.IO.Directory.Exists(logPath))
            {
                Process.Start(new ProcessStartInfo { FileName = logPath, UseShellExecute = true });
            }
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to open log folder: {ex.Message}");
        }
    }

    private async Task RecordExecutionAsync(string toolId, string toolName, bool success)
    {
        var entry = new ExecutionHistoryEntry
        {
            ToolId = toolId,
            ToolName = toolName,
            ExecutedAt = DateTime.UtcNow,
            DurationMs = 0,
            Success = success,
            FullOutput = string.Join(Environment.NewLine, OutputLines),
            ErrorOutput = ""
        };

        await _historyService.SaveExecutionAsync(entry);

        var stat = new UsageStatistic
        {
            ToolId = "tsplus-manager",
            ToolName = "TSPlus Manager",
            ExecutionCount = 1,
            SuccessCount = success ? 1 : 0,
            FailureCount = success ? 0 : 1,
            TotalDurationMs = 0,
            LastExecutedAt = DateTime.UtcNow
        };

        await _statsService.RecordExecutionAsync(stat);
    }
}
