using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Input;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;

namespace BepozToolkit.App.ViewModels;

public class LogEntryDisplay
{
    public string Id { get; set; } = "";
    public string ToolName { get; set; } = "";
    public DateTime Timestamp { get; set; }
    public string TimestampFormatted => Timestamp.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss");
    public string Level { get; set; } = "Info";
    public long DurationMs { get; set; }
    public string Message { get; set; } = "";
    public string MachineName { get; set; } = "";
    public string FullOutput { get; set; } = "";
    public bool Success { get; set; }
}

public class LogsViewModel : ViewModelBase
{
    private readonly IHistoryService _historyService;
    private readonly IToastService _toastService;

    private string _selectedLevel = "All";
    private string _selectedMachine = "All";
    private bool _isLoading;
    private List<LogEntryDisplay> _allEntries = [];

    public LogsViewModel(IHistoryService historyService, IToastService toastService)
    {
        _historyService = historyService;
        _toastService = toastService;

        LogEntries = new ObservableCollection<LogEntryDisplay>();
        Machines = new ObservableCollection<string> { "All" };
        Levels = new ObservableCollection<string> { "All", "Info", "Warning", "Error", "Success" };

        LoadLogsCommand = new AsyncRelayCommand(LoadLogsAsync);
        ViewOutputCommand = new RelayCommand<LogEntryDisplay>(ViewOutput);
        RefreshCommand = new AsyncRelayCommand(LoadLogsAsync);
    }

    public string SelectedLevel
    {
        get => _selectedLevel;
        set
        {
            if (SetProperty(ref _selectedLevel, value))
                ApplyFilters();
        }
    }

    public string SelectedMachine
    {
        get => _selectedMachine;
        set
        {
            if (SetProperty(ref _selectedMachine, value))
                ApplyFilters();
        }
    }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public ObservableCollection<LogEntryDisplay> LogEntries { get; }
    public ObservableCollection<string> Machines { get; }
    public ObservableCollection<string> Levels { get; }

    public ICommand LoadLogsCommand { get; }
    public ICommand ViewOutputCommand { get; }
    public ICommand RefreshCommand { get; }

    public async Task LoadLogsAsync()
    {
        IsLoading = true;
        try
        {
            var entries = await _historyService.GetRecentExecutionsAsync(200);

            _allEntries = entries.Select(e => new LogEntryDisplay
            {
                Id = e.Id,
                ToolName = e.ToolName,
                Timestamp = e.ExecutedAt,
                Level = DetermineLevel(e),
                DurationMs = e.DurationMs,
                Message = e.Success
                    ? $"Completed successfully in {FormatDuration(e.DurationMs)}"
                    : TruncateMessage(e.ErrorOutput),
                MachineName = Environment.MachineName,
                FullOutput = e.FullOutput,
                Success = e.Success
            }).ToList();

            Machines.Clear();
            Machines.Add("All");
            foreach (var machine in _allEntries
                .Select(e => e.MachineName)
                .Distinct()
                .OrderBy(m => m))
            {
                Machines.Add(machine);
            }

            ApplyFilters();
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to load logs: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private void ApplyFilters()
    {
        var filtered = _allEntries.AsEnumerable();

        if (SelectedLevel != "All")
        {
            filtered = filtered.Where(e =>
                e.Level.Equals(SelectedLevel, StringComparison.OrdinalIgnoreCase));
        }

        if (SelectedMachine != "All")
        {
            filtered = filtered.Where(e =>
                e.MachineName.Equals(SelectedMachine, StringComparison.OrdinalIgnoreCase));
        }

        LogEntries.Clear();
        foreach (var entry in filtered.OrderByDescending(e => e.Timestamp))
        {
            LogEntries.Add(entry);
        }
    }

    private void ViewOutput(LogEntryDisplay? entry)
    {
        if (entry is null || string.IsNullOrWhiteSpace(entry.FullOutput)) return;

        Clipboard.SetText(entry.FullOutput);
        _toastService.ShowInfo("Output copied to clipboard.");
    }

    private static string DetermineLevel(ExecutionHistoryEntry entry)
    {
        if (!entry.Success && !string.IsNullOrWhiteSpace(entry.ErrorOutput))
            return "Error";
        if (entry.Success)
            return "Success";
        return "Info";
    }

    private static string FormatDuration(long ms)
    {
        if (ms < 1000) return $"{ms}ms";
        if (ms < 60000) return $"{ms / 1000.0:F1}s";
        return $"{ms / 60000.0:F1}m";
    }

    private static string TruncateMessage(string message)
    {
        if (string.IsNullOrWhiteSpace(message)) return "No error details";
        var firstLine = message.Split('\n').FirstOrDefault()?.Trim() ?? message;
        return firstLine.Length > 120 ? firstLine[..117] + "..." : firstLine;
    }
}
