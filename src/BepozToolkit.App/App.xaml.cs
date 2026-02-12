using System.IO;
using System.Windows;
using System.Windows.Threading;
using BepozToolkit.App.ViewModels;
using BepozToolkit.Core;
using BepozToolkit.Core.Database;
using BepozToolkit.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace BepozToolkit.App;

/// <summary>
/// Application entry point. Configures DI, logging, theme, and launches MainWindow.
/// </summary>
public partial class App : Application
{
    private ServiceProvider? _serviceProvider;

    /// <summary>
    /// Global access to the DI container for places where constructor injection
    /// is not feasible (e.g., XAML converters, design-time view models).
    /// Prefer constructor injection everywhere else.
    /// </summary>
    public static IServiceProvider Services { get; private set; } = null!;

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        try
        {
            // ------------------------------------------------------------------
            // 1. Ensure data directories exist
            // ------------------------------------------------------------------
            EnsureDirectories();

            // ------------------------------------------------------------------
            // 2. Initialize Serilog
            // ------------------------------------------------------------------
            InitializeLogging();

            Log.Information("=== {AppName} v{Version} starting ===", Constants.AppName, Constants.AppVersion);

            // ------------------------------------------------------------------
            // 3. Wire up global exception handlers (before any async work)
            // ------------------------------------------------------------------
            DispatcherUnhandledException += OnDispatcherUnhandledException;
            AppDomain.CurrentDomain.UnhandledException += OnDomainUnhandledException;
            TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;

            // ------------------------------------------------------------------
            // 4. Build DI container
            // ------------------------------------------------------------------
            var services = new ServiceCollection();
            ConfigureServices(services);
            _serviceProvider = services.BuildServiceProvider();
            Services = _serviceProvider;

            // ------------------------------------------------------------------
            // 5. Initialize database
            // ------------------------------------------------------------------
            try
            {
                var db = _serviceProvider.GetRequiredService<BepozToolkitDb>();
                await db.InitializeAsync();
                Log.Information("Database initialized successfully");
            }
            catch (Exception ex)
            {
                Log.Error(ex, "Failed to initialize database");
            }

            // ------------------------------------------------------------------
            // 6. Load user settings and apply theme
            // ------------------------------------------------------------------
            try
            {
                var settingsService = _serviceProvider.GetRequiredService<ISettingsService>();
                var settings = await settingsService.LoadSettingsAsync();
                ApplyTheme(settings.Theme);
            }
            catch (Exception ex)
            {
                Log.Warning(ex, "Failed to load settings on startup; using defaults");
                ApplyTheme("BepozLight");
            }

            // ------------------------------------------------------------------
            // 7. Create and show MainWindow
            // ------------------------------------------------------------------
            var mainWindow = _serviceProvider.GetRequiredService<MainWindow>();
            mainWindow.DataContext = _serviceProvider.GetRequiredService<MainViewModel>();
            MainWindow = mainWindow;
            mainWindow.Show();

            Log.Information("MainWindow shown successfully");
        }
        catch (Exception ex)
        {
            var msg = $"Fatal startup error:\n\n{ex}";
            Log.Fatal(ex, "Fatal startup error");
            MessageBox.Show(msg, "Bepoz Toolkit - Startup Error", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Log.Information("=== {AppName} shutting down ===", Constants.AppName);
        Log.CloseAndFlush();
        _serviceProvider?.Dispose();
        base.OnExit(e);
    }

    // ======================================================================
    // DI Configuration
    // ======================================================================

    private static void ConfigureServices(IServiceCollection services)
    {
        // --- Infrastructure ---
        services.AddSingleton<ILogger>(Log.Logger);
        services.AddSingleton<BepozToolkitDb>();

        // --- Core Services (registered as singletons for app lifetime) ---
        services.AddSingleton<ICacheService, CacheService>();
        services.AddSingleton<IGitHubService, GitHubService>();
        services.AddSingleton<IPowerShellHost, PowerShellHost>();
        services.AddSingleton<ISettingsService, SettingsService>();
        services.AddSingleton<IStatsService, StatsService>();
        services.AddSingleton<IConnectionService, ConnectionService>();
        services.AddSingleton<IPreFlightService, PreFlightService>();
        services.AddSingleton<IHistoryService, HistoryService>();
        services.AddSingleton<IToastService, ToastService>();

        // --- ViewModels ---
        services.AddSingleton<MainViewModel>();
        services.AddTransient<ViewModels.DashboardViewModel>();
        services.AddTransient<ViewModels.ToolsViewModel>();
        services.AddTransient<ViewModels.LogsViewModel>();
        services.AddTransient<ViewModels.SettingsViewModel>();
        services.AddTransient<ViewModels.ToolExecutionViewModel>();

        // --- Views ---
        services.AddTransient<MainWindow>();
    }

    // ======================================================================
    // Theme Management
    // ======================================================================

    /// <summary>
    /// Swaps the Bepoz theme ResourceDictionary at runtime.
    /// Accepts "BepozLight" or "BepozDark".
    /// </summary>
    public static void ApplyTheme(string themeName)
    {
        var themeUri = themeName switch
        {
            "BepozDark" => new Uri("Themes/BepozDarkTheme.xaml", UriKind.Relative),
            _ => new Uri("Themes/BepozLightTheme.xaml", UriKind.Relative),
        };

        var mergedDicts = Current.Resources.MergedDictionaries;

        // Find and replace the existing Bepoz theme dictionary (index 2 by convention)
        for (int i = 0; i < mergedDicts.Count; i++)
        {
            var source = mergedDicts[i].Source;
            if (source != null && source.OriginalString.Contains("BepozLightTheme") ||
                source != null && source.OriginalString.Contains("BepozDarkTheme"))
            {
                mergedDicts[i] = new ResourceDictionary { Source = themeUri };
                Log.Information("Theme changed to {Theme}", themeName);
                return;
            }
        }

        // Fallback: just add it
        mergedDicts.Add(new ResourceDictionary { Source = themeUri });
        Log.Information("Theme added: {Theme}", themeName);
    }

    // ======================================================================
    // Logging
    // ======================================================================

    private static void InitializeLogging()
    {
        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Debug()
            .WriteTo.File(
                path: Path.Combine(Constants.LogPath, "BepozToolkit-.log"),
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 14,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
            .CreateLogger();
    }

    // ======================================================================
    // Directory setup
    // ======================================================================

    private static void EnsureDirectories()
    {
        Directory.CreateDirectory(Constants.AppDataPath);
        Directory.CreateDirectory(Constants.CachePath);
        Directory.CreateDirectory(Constants.LogPath);
    }

    // ======================================================================
    // Global Exception Handlers
    // ======================================================================

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        Log.Fatal(e.Exception, "Unhandled dispatcher exception");
        ShowFatalError(e.Exception);
        e.Handled = true;
    }

    private void OnDomainUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        if (e.ExceptionObject is Exception ex)
        {
            Log.Fatal(ex, "Unhandled domain exception (IsTerminating={IsTerminating})", e.IsTerminating);
        }
    }

    private void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
    {
        Log.Error(e.Exception, "Unobserved task exception");
        e.SetObserved();
    }

    private static void ShowFatalError(Exception ex)
    {
        var message = $"An unexpected error occurred:\n\n{ex.Message}\n\nThe error has been logged. The application will attempt to continue.";
        MessageBox.Show(message, Constants.AppName, MessageBoxButton.OK, MessageBoxImage.Error);
    }
}

