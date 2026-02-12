using System.Collections.ObjectModel;
using System.Windows.Input;
using BepozToolkit.App.Helpers;
using BepozToolkit.Core.Models;
using BepozToolkit.Core.Services;

namespace BepozToolkit.App.ViewModels;

public class ToolsViewModel : ViewModelBase
{
    private readonly IGitHubService _gitHubService;
    private readonly ISettingsService _settingsService;
    private readonly IHistoryService _historyService;
    private readonly IStatsService _statsService;
    private readonly IPowerShellHost _powerShellHost;
    private readonly IToastService _toastService;

    private string _searchText = "";
    private string _selectedCategory = "All";
    private bool _isLoading;
    private List<Tool> _allTools = [];

    public ToolsViewModel(
        IGitHubService gitHubService,
        ISettingsService settingsService,
        IHistoryService historyService,
        IStatsService statsService,
        IPowerShellHost powerShellHost,
        IToastService toastService)
    {
        _gitHubService = gitHubService;
        _settingsService = settingsService;
        _historyService = historyService;
        _statsService = statsService;
        _powerShellHost = powerShellHost;
        _toastService = toastService;

        Tools = new ObservableCollection<Tool>();
        Categories = new ObservableCollection<string> { "All" };

        LoadToolsCommand = new AsyncRelayCommand(async () => await LoadToolsAsync());
        RefreshCommand = new AsyncRelayCommand(async () => await LoadToolsAsync(forceRefresh: true));
        RunToolCommand = new AsyncRelayCommand<Tool>(RunToolAsync);
        ToggleFavoriteCommand = new AsyncRelayCommand<Tool>(ToggleFavoriteAsync);
    }

    public string SearchText
    {
        get => _searchText;
        set
        {
            if (SetProperty(ref _searchText, value))
                ApplyFilters();
        }
    }

    public string SelectedCategory
    {
        get => _selectedCategory;
        set
        {
            if (SetProperty(ref _selectedCategory, value))
                ApplyFilters();
        }
    }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public ObservableCollection<Tool> Tools { get; }
    public ObservableCollection<string> Categories { get; }

    public ICommand LoadToolsCommand { get; }
    public ICommand RefreshCommand { get; }
    public ICommand RunToolCommand { get; }
    public ICommand ToggleFavoriteCommand { get; }

    public async Task LoadToolsAsync(bool forceRefresh = false)
    {
        IsLoading = true;
        try
        {
            var manifest = await _gitHubService.GetManifestAsync(forceRefresh);
            var settings = await _settingsService.LoadSettingsAsync();

            _allTools = manifest.Tools;

            foreach (var tool in _allTools)
            {
                tool.IsFavorite = settings.FavoriteToolIds.Contains(tool.Id);
                tool.IsPinned = settings.PinnedToolIds.Contains(tool.Id);
            }

            Categories.Clear();
            Categories.Add("All");
            foreach (var cat in manifest.Categories.OrderBy(c => c.Name))
            {
                Categories.Add(cat.Name);
            }

            ApplyFilters();

            if (forceRefresh)
                _toastService.ShowSuccess("Tool list refreshed from GitHub.");
        }
        catch (Exception ex)
        {
            _toastService.ShowError($"Failed to load tools: {ex.Message}");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private void ApplyFilters()
    {
        var filtered = _allTools.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            var search = SearchText.Trim();
            filtered = filtered.Where(t =>
                t.Name.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                t.Description.Contains(search, StringComparison.OrdinalIgnoreCase) ||
                t.Category.Contains(search, StringComparison.OrdinalIgnoreCase));
        }

        if (SelectedCategory != "All")
        {
            filtered = filtered.Where(t =>
                t.Category.Equals(SelectedCategory, StringComparison.OrdinalIgnoreCase));
        }

        Tools.Clear();
        foreach (var tool in filtered.OrderBy(t => t.Name))
        {
            Tools.Add(tool);
        }
    }

    private async Task ToggleFavoriteAsync(Tool? tool)
    {
        if (tool is null) return;

        tool.IsFavorite = !tool.IsFavorite;

        var settings = await _settingsService.LoadSettingsAsync();
        if (tool.IsFavorite)
        {
            if (!settings.FavoriteToolIds.Contains(tool.Id))
                settings.FavoriteToolIds.Add(tool.Id);
        }
        else
        {
            settings.FavoriteToolIds.Remove(tool.Id);
        }

        await _settingsService.SaveSettingsAsync(settings);
        ApplyFilters();

        _toastService.ShowInfo(tool.IsFavorite
            ? $"Added {tool.Name} to favorites."
            : $"Removed {tool.Name} from favorites.");
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
}
