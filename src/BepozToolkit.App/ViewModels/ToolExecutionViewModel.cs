using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Input;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;

namespace BepozToolkit.App.ViewModels;

public class ToolExecutionViewModel : ViewModelBase
{
    private readonly IGitHubService _gitHubService;
    private readonly IPowerShellHost _powerShellHost;
    private readonly IHistoryService _historyService;
    private readonly IStatsService _statsService;
    private readonly IToastService _toastService;

    private Tool? _tool;
    private string _toolName = "";
    private string _toolVersion = "";
    private string _toolCategory = "";
    private string _toolDescription = "";
    private bool _isRunning;
    private bool _hasError;
    private int _progress;
    private string _statusText = "Ready";
    private string _errorMessage = "";
    private Stopwatch _stopwatch = new();

    public ToolExecutionViewModel(
        IGitHubService gitHubService,
        IPowerShellHost powerShellHost,
        IHistoryService historyService,
        IStatsService statsService,
        IToastService toastService)
    {
        _gitHubService = gitHubService;
        _powerShellHost = powerShellHost;
        _historyService = historyService;
        _statsService = statsService;
        _toastService = toastService;

        OutputLines = new ObservableCollection<string>();

        StopCommand = new RelayCommand(Stop, () => IsRunning);
        RestartCommand = new AsyncRelayCommand(RestartAsync, () => !IsRunning);
        CopyOutputCommand = new RelayCommand(CopyOutput);
        RetryCommand = new AsyncRelayCommand(RetryAsync, () => HasError && !IsRunning);
        RetryAsAdminCommand = new RelayCommand(RetryAsAdmin, () => HasError && !IsRunning);
        CopyErrorCommand = new RelayCommand(CopyError, () => HasError);
        OpenLogCommand = new RelayCommand(OpenLog);
    }

    public string ToolName
    {
        get => _toolName;
        set => SetProperty(ref _toolName, value);
    }

    public string ToolVersion
    {
        get => _toolVersion;
        set => SetProperty(ref _toolVersion, value);
    }

    public string ToolCategory
    {
        get => _toolCategory;
        set => SetProperty(ref _toolCategory, value);
    }

    public string ToolDescription
    {
        get => _toolDescription;
        set => SetProperty(ref _toolDescription, value);
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

    public ObservableCollection<string> OutputLines { get; }

    public ICommand StopCommand { get; }
    public ICommand RestartCommand { get; }
    public ICommand CopyOutputCommand { get; }
    public ICommand RetryCommand { get; }
    public ICommand RetryAsAdminCommand { get; }
    public ICommand CopyErrorCommand { get; }
    public ICommand OpenLogCommand { get; }

    public void SetTool(Tool tool)
    {
        _tool = tool;
        ToolName = tool.Name;
        ToolVersion = tool.Version;
        ToolCategory = tool.Category;
        ToolDescription = tool.Description;
    }

    public async Task StartExecutionAsync()
    {
        if (_tool is null) return;

        IsRunning = true;
        HasError = false;
        ErrorMessage = "";
        Progress = 0;
        StatusText = "Downloading script...";
        OutputLines.Clear();
        _stopwatch = Stopwatch.StartNew();

        try
        {
            var scriptPath = await _gitHubService.DownloadAndCacheFileAsync(_tool.File);

            StatusText = "Executing...";
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] Starting {_tool.Name} v{_tool.Version}...");
            AppendOutput(new string('-', 60));

            var result = await _powerShellHost.ExecuteScriptAsync(
                scriptPath,
                null,
                line => Application.Current.Dispatcher.Invoke(() => AppendOutput(line)),
                line => Application.Current.Dispatcher.Invoke(() => AppendOutput($"[ERROR] {line}")),
                pct => Application.Current.Dispatcher.Invoke(() => Progress = pct));

            _stopwatch.Stop();

            if (result.Success)
            {
                StatusText = $"Completed in {FormatDuration(_stopwatch.ElapsedMilliseconds)}";
                Progress = 100;
                AppendOutput(new string('-', 60));
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] Completed successfully. Duration: {FormatDuration(_stopwatch.ElapsedMilliseconds)}");
                _toastService.ShowSuccess($"{_tool.Name} completed successfully.");
            }
            else
            {
                HasError = true;
                ErrorMessage = result.ErrorOutput;
                StatusText = "Failed";
                AppendOutput(new string('-', 60));
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] FAILED: {result.ErrorOutput}");
                _toastService.ShowError($"{_tool.Name} failed: {TruncateMessage(result.ErrorOutput)}");
            }

            await RecordExecutionAsync(result);
        }
        catch (Exception ex)
        {
            _stopwatch.Stop();
            HasError = true;
            ErrorMessage = ex.Message;
            StatusText = "Error";
            AppendOutput($"[{DateTime.Now:HH:mm:ss}] EXCEPTION: {ex.Message}");
            _toastService.ShowError($"Execution error: {ex.Message}");
        }
        finally
        {
            IsRunning = false;
        }
    }

    private void Stop()
    {
        if (!IsRunning) return;

        _powerShellHost.StopExecution();
        StatusText = "Stopping...";
        AppendOutput($"[{DateTime.Now:HH:mm:ss}] Execution stop requested.");
    }

    private async Task RestartAsync()
    {
        await StartExecutionAsync();
    }

    private void CopyOutput()
    {
        var text = string.Join(Environment.NewLine, OutputLines);
        if (!string.IsNullOrWhiteSpace(text))
        {
            Clipboard.SetText(text);
            _toastService.ShowInfo("Output copied to clipboard.");
        }
    }

    private async Task RetryAsync()
    {
        HasError = false;
        ErrorMessage = "";
        await StartExecutionAsync();
    }

    private void RetryAsAdmin()
    {
        try
        {
            _powerShellHost.RestartAsAdmin();
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to restart as admin: {ex.Message}");
        }
    }

    private void CopyError()
    {
        if (!string.IsNullOrWhiteSpace(ErrorMessage))
        {
            Clipboard.SetText(ErrorMessage);
            _toastService.ShowInfo("Error details copied to clipboard.");
        }
    }

    private void OpenLog()
    {
        try
        {
            var logPath = BepozToolkit.Core.Constants.LogPath;
            if (System.IO.Directory.Exists(logPath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = logPath,
                    UseShellExecute = true
                });
            }
            else
            {
                _toastService.ShowWarning("Log directory does not exist yet.");
            }
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to open log folder: {ex.Message}");
        }
    }

    private void AppendOutput(string line)
    {
        OutputLines.Add(line);
    }

    private async Task RecordExecutionAsync(ToolExecutionResult result)
    {
        if (_tool is null) return;

        var historyEntry = new ExecutionHistoryEntry
        {
            ToolId = _tool.Id,
            ToolName = _tool.Name,
            ExecutedAt = result.ExecutedAt,
            DurationMs = _stopwatch.ElapsedMilliseconds,
            Success = result.Success,
            FullOutput = result.Output,
            ErrorOutput = result.ErrorOutput
        };

        await _historyService.SaveExecutionAsync(historyEntry);

        var stat = new UsageStatistic
        {
            ToolId = _tool.Id,
            ToolName = _tool.Name,
            ExecutionCount = 1,
            SuccessCount = result.Success ? 1 : 0,
            FailureCount = result.Success ? 0 : 1,
            TotalDurationMs = _stopwatch.ElapsedMilliseconds,
            LastExecutedAt = result.ExecutedAt
        };

        await _statsService.RecordExecutionAsync(stat);
    }

    private static string FormatDuration(long ms)
    {
        if (ms < 1000) return $"{ms}ms";
        if (ms < 60000) return $"{ms / 1000.0:F1}s";
        return $"{ms / 60000.0:F1}m";
    }

    private static string TruncateMessage(string message)
    {
        if (string.IsNullOrWhiteSpace(message)) return "Unknown error";
        var firstLine = message.Split('\n').FirstOrDefault()?.Trim() ?? message;
        return firstLine.Length > 80 ? firstLine[..77] + "..." : firstLine;
    }
}
