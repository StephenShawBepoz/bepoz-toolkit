using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Input;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;

namespace BepozToolkit.App.ViewModels;

public class DashboardViewModel : ViewModelBase
{
    private readonly IStatsService _statsService;
    private readonly IHistoryService _historyService;
    private readonly ISettingsService _settingsService;
    private readonly IGitHubService _gitHubService;
    private readonly IPowerShellHost _powerShellHost;
    private readonly IToastService _toastService;

    private int _totalRuns;
    private int _toolCount;
    private double _successRate;
    private bool _isLoading;

    public DashboardViewModel(
        IStatsService statsService,
        IHistoryService historyService,
        ISettingsService settingsService,
        IGitHubService gitHubService,
        IPowerShellHost powerShellHost,
        IToastService toastService)
    {
        _statsService = statsService;
        _historyService = historyService;
        _settingsService = settingsService;
        _gitHubService = gitHubService;
        _powerShellHost = powerShellHost;
        _toastService = toastService;

        PinnedTools = new ObservableCollection<Tool>();
        RecentActivity = new ObservableCollection<ActivityFeedItem>();
        SparklineData = new ObservableCollection<Point>();

        LoadDashboardCommand = new AsyncRelayCommand(LoadDashboardAsync);
        RunToolCommand = new AsyncRelayCommand<Tool>(RunToolAsync);
        RefreshCommand = new AsyncRelayCommand(LoadDashboardAsync);
    }

    public int TotalRuns
    {
        get => _totalRuns;
        set => SetProperty(ref _totalRuns, value);
    }

    public int ToolCount
    {
        get => _toolCount;
        set => SetProperty(ref _toolCount, value);
    }

    public double SuccessRate
    {
        get => _successRate;
        set => SetProperty(ref _successRate, value);
    }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public ObservableCollection<Tool> PinnedTools { get; }
    public ObservableCollection<ActivityFeedItem> RecentActivity { get; }
    public ObservableCollection<Point> SparklineData { get; }

    public ICommand LoadDashboardCommand { get; }
    public ICommand RunToolCommand { get; }
    public ICommand RefreshCommand { get; }

    public async Task LoadDashboardAsync()
    {
        IsLoading = true;
        try
        {
            TotalRuns = await _statsService.GetTotalExecutionCountAsync();
            SuccessRate = await _statsService.GetSuccessRateAsync();

            var manifest = await _gitHubService.GetManifestAsync();
            ToolCount = manifest.Tools.Count;

            var settings = await _settingsService.LoadSettingsAsync();
            PinnedTools.Clear();
            foreach (var tool in manifest.Tools.Where(t => settings.PinnedToolIds.Contains(t.Id)))
            {
                PinnedTools.Add(tool);
            }

            var recentExecutions = await _historyService.GetRecentExecutionsAsync(10);
            RecentActivity.Clear();
            foreach (var entry in recentExecutions)
            {
                RecentActivity.Add(new ActivityFeedItem
                {
                    ToolName = entry.ToolName,
                    Timestamp = entry.ExecutedAt,
                    RelativeTime = FormatRelativeTime(entry.ExecutedAt),
                    Success = entry.Success,
                    ErrorMessage = entry.Success ? null : entry.ErrorOutput,
                    Duration = FormatDuration(entry.DurationMs),
                    Icon = entry.Success ? "\u2713" : "\u2717"
                });
            }

            var dailyCounts = await _statsService.GetDailyExecutionCountsAsync(7);
            SparklineData.Clear();
            if (dailyCounts.Count > 0)
            {
                int maxCount = dailyCounts.Max(d => d.Count);
                if (maxCount == 0) maxCount = 1;
                for (int i = 0; i < dailyCounts.Count; i++)
                {
                    double x = dailyCounts.Count > 1 ? (double)i / (dailyCounts.Count - 1) * 200 : 100;
                    double y = 50 - ((double)dailyCounts[i].Count / maxCount * 40);
                    SparklineData.Add(new Point(x, y));
                }
            }
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to load dashboard: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async Task RunToolAsync(Tool? tool)
    {
        if (tool is null) return;

        var executionVm = new ToolExecutionViewModel(
            _gitHubService,
            _powerShellHost,
            _historyService,
            _statsService,
            _toastService);

        executionVm.SetTool(tool);

        var window = new Views.ToolExecutionWindow
        {
            DataContext = executionVm
        };
        window.Show();
        await executionVm.StartExecutionAsync();
    }

    private static string FormatRelativeTime(DateTime utcTime)
    {
        var span = DateTime.UtcNow - utcTime;

        if (span.TotalSeconds < 60) return "Just now";
        if (span.TotalMinutes < 60) return $"{(int)span.TotalMinutes}m ago";
        if (span.TotalHours < 24) return $"{(int)span.TotalHours}h ago";
        if (span.TotalDays < 7) return $"{(int)span.TotalDays}d ago";
        return utcTime.ToLocalTime().ToString("MMM dd");
    }

    private static string FormatDuration(long ms)
    {
        if (ms < 1000) return $"{ms}ms";
        if (ms < 60000) return $"{ms / 1000.0:F1}s";
        return $"{ms / 60000.0:F1}m";
    }
}
