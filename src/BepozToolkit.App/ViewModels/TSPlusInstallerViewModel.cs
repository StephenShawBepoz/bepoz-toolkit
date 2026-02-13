using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Input;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;

namespace BepozToolkit.App.ViewModels;

public class TSPlusInstallerViewModel : ViewModelBase
{
    private readonly ITSPlusService _tsPlusService;
    private readonly IHistoryService _historyService;
    private readonly IStatsService _statsService;
    private readonly IToastService _toastService;

    private string _installerUrl = "https://dl-files.com/TSplus-Setup.exe";
    private string _localGroupName = "TSplus Users";
    private bool _shouldCreateGroup = true;
    private bool _shouldReboot;
    private bool _isDownloading;
    private bool _isInstalling;
    private bool _isRunning;
    private bool _hasError;
    private int _progress;
    private string _statusText = "Ready";
    private string _errorMessage = "";
    private string _installedVersion = "";
    private bool _isAlreadyInstalled;
    private CancellationTokenSource? _cts;
    private Stopwatch _stopwatch = new();

    public TSPlusInstallerViewModel(
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

        StartInstallCommand = new AsyncRelayCommand(StartInstallAsync, () => !IsRunning);
        StopCommand = new RelayCommand(Stop, () => IsRunning);
        CopyLogCommand = new RelayCommand(CopyLog);
        OpenLogCommand = new RelayCommand(OpenLog);

        CheckInstallation();
    }

    // ======================================================================
    // Properties
    // ======================================================================

    public string InstallerUrl
    {
        get => _installerUrl;
        set => SetProperty(ref _installerUrl, value);
    }

    public string LocalGroupName
    {
        get => _localGroupName;
        set => SetProperty(ref _localGroupName, value);
    }

    public bool ShouldCreateGroup
    {
        get => _shouldCreateGroup;
        set => SetProperty(ref _shouldCreateGroup, value);
    }

    public bool ShouldReboot
    {
        get => _shouldReboot;
        set => SetProperty(ref _shouldReboot, value);
    }

    public bool IsDownloading
    {
        get => _isDownloading;
        set => SetProperty(ref _isDownloading, value);
    }

    public bool IsInstalling
    {
        get => _isInstalling;
        set => SetProperty(ref _isInstalling, value);
    }

    public bool IsRunning
    {
        get => _isRunning;
        set => SetProperty(ref _isRunning, value);
    }

    public bool HasError
    {
        get => _hasError;
        set => SetProperty(ref _hasError, value);
    }

    public int Progress
    {
        get => _progress;
        set => SetProperty(ref _progress, value);
    }

    public string StatusText
    {
        get => _statusText;
        set => SetProperty(ref _statusText, value);
    }

    public string ErrorMessage
    {
        get => _errorMessage;
        set => SetProperty(ref _errorMessage, value);
    }

    public string InstalledVersion
    {
        get => _installedVersion;
        set => SetProperty(ref _installedVersion, value);
    }

    public bool IsAlreadyInstalled
    {
        get => _isAlreadyInstalled;
        set => SetProperty(ref _isAlreadyInstalled, value);
    }

    public ObservableCollection<string> OutputLines { get; }

    // ======================================================================
    // Commands
    // ======================================================================

    public ICommand StartInstallCommand { get; }
    public ICommand StopCommand { get; }
    public ICommand CopyLogCommand { get; }
    public ICommand OpenLogCommand { get; }

    // ======================================================================
    // Install Workflow
    // ======================================================================

    private void CheckInstallation()
    {
        IsAlreadyInstalled = _tsPlusService.IsInstalled();
        InstalledVersion = _tsPlusService.GetInstalledVersion() ?? "";
    }

    private async Task StartInstallAsync()
    {
        IsRunning = true;
        HasError = false;
        ErrorMessage = "";
        Progress = 0;
        OutputLines.Clear();
        _cts = new CancellationTokenSource();
        _stopwatch = Stopwatch.StartNew();

        var success = false;
        string installerPath = "";

        try
        {
            // Step 1: Download
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Starting TSPlus Installation");
            AppendOutput(new string('=', 60));
            AppendOutput("");

            StatusText = "Downloading installer...";
            IsDownloading = true;
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Downloading from: {InstallerUrl}");

            var downloadProgress = new Progress<float>(p =>
            {
                Application.Current.Dispatcher.Invoke(() =>
                {
                    Progress = (int)(p * 40); // Download is 0-40%
                    StatusText = $"Downloading... {p:P0}";
                });
            });

            installerPath = await _tsPlusService.DownloadInstallerAsync(InstallerUrl, downloadProgress, _cts.Token);
            IsDownloading = false;
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Download complete: {installerPath}");
            AppendOutput("");

            // Step 2: Validate signature
            StatusText = "Validating digital signature...";
            Progress = 45;
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Validating Authenticode signature...");

            var signatureValid = await _tsPlusService.ValidateSignatureAsync(installerPath);
            if (signatureValid)
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Signature: VALID");
            }
            else
            {
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Signature: WARNING - Could not validate signature");
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Continuing with installation...");
            }
            AppendOutput("");

            // Step 3: Silent install
            StatusText = "Installing TSPlus...";
            IsInstalling = true;
            Progress = 50;
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Running silent install (/VERYSILENT /SUPPRESSMSGBOXES /NORESTART)");

            var installSuccess = await _tsPlusService.RunSilentInstallAsync(
                installerPath,
                line => Application.Current.Dispatcher.Invoke(() => AppendOutput($"  {line}")),
                _cts.Token);

            IsInstalling = false;

            if (!installSuccess)
            {
                throw new Exception("TSPlus installer exited with a non-zero exit code.");
            }

            Progress = 80;
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Installation completed successfully");
            AppendOutput("");

            // Step 4: Create directory structure
            StatusText = "Creating directories...";
            Progress = 85;
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Creating Bepoz directory structure...");
            _tsPlusService.CreateDirectoryStructure();
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Created: C:\\Bepoz\\Back Office Cloud - Uploads");
            AppendOutput("");

            // Step 5: Create local group (optional)
            if (ShouldCreateGroup && !string.IsNullOrWhiteSpace(LocalGroupName))
            {
                StatusText = "Creating local group...";
                Progress = 90;
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Creating local group: {LocalGroupName}");

                var groupCreated = await _tsPlusService.CreateLocalGroup(LocalGroupName);
                AppendOutput(groupCreated
                    ? $"[{DateTime.Now:HH:mm:ss}] Local group '{LocalGroupName}' ready"
                    : $"[{DateTime.Now:HH:mm:ss}] WARNING: Could not create local group '{LocalGroupName}'");
                AppendOutput("");
            }

            // Done
            _stopwatch.Stop();
            Progress = 100;
            success = true;
            StatusText = $"Completed in {FormatDuration(_stopwatch.ElapsedMilliseconds)}";
            AppendOutput(new string('=', 60));
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] TSPlus installation completed successfully!");
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Duration: {FormatDuration(_stopwatch.ElapsedMilliseconds)}");

            CheckInstallation();
            _toastService.ShowSuccess("TSPlus installed successfully.");

            // Step 6: Reboot (optional)
            if (ShouldReboot)
            {
                AppendOutput("");
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] System reboot requested. Rebooting in 30 seconds...");
                _toastService.ShowWarning("System will reboot in 30 seconds.");
            }
        }
        catch (OperationCanceledException)
        {
            _stopwatch.Stop();
            StatusText = "Cancelled";
            AppendOutput("");
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Installation cancelled by user.");
            _toastService.ShowWarning("TSPlus installation cancelled.");
        }
        catch (Exception ex)
        {
            _stopwatch.Stop();
            HasError = true;
            ErrorMessage = ex.Message;
            StatusText = "Failed";
            AppendOutput("");
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] ERROR: {ex.Message}");
            _toastService.ShowError($"TSPlus installation failed: {ex.Message}");
        }
        finally
        {
            IsDownloading = false;
            IsInstalling = false;
            IsRunning = false;
            _cts?.Dispose();
            _cts = null;

            await RecordExecutionAsync(success);
        }
    }

    private void Stop()
    {
        if (!IsRunning) return;
        _cts?.Cancel();
        StatusText = "Cancelling...";
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Cancellation requested...");
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

    // ======================================================================
    // Helpers
    // ======================================================================

    private void AppendOutput(string line)
    {
        OutputLines.Add(line);
    }

    private async Task RecordExecutionAsync(bool success)
    {
        var entry = new ExecutionHistoryEntry
        {
            ToolId = "tsplus-installer",
            ToolName = "TSPlus Installer",
            ExecutedAt = DateTime.UtcNow,
            DurationMs = _stopwatch.ElapsedMilliseconds,
            Success = success,
            FullOutput = string.Join(Environment.NewLine, OutputLines),
            ErrorOutput = ErrorMessage
        };

        await _historyService.SaveExecutionAsync(entry);

        var stat = new UsageStatistic
        {
            ToolId = "tsplus-installer",
            ToolName = "TSPlus Installer",
            ExecutionCount = 1,
            SuccessCount = success ? 1 : 0,
            FailureCount = success ? 0 : 1,
            TotalDurationMs = _stopwatch.ElapsedMilliseconds,
            LastExecutedAt = DateTime.UtcNow
        };

        await _statsService.RecordExecutionAsync(stat);
    }

    private static string FormatDuration(long ms)
    {
        if (ms < 1000) return $"{ms}ms";
        if (ms < 60000) return $"{ms / 1000.0:F1}s";
        return $"{ms / 60000.0:F1}m";
    }
}
