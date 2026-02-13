using System.ComponentModel;
using System.Windows;
using System.Windows.Shell;
using BepozToolkit.App.ViewModels;
using BepozToolkit.Core.Services;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace BepozToolkit.App;

/// <summary>
/// MainWindow code-behind. Handles window chrome interactions (minimize, maximize, close),
/// window position persistence, and minimize-to-tray behavior.
/// </summary>
public partial class MainWindow : Window
{
    public MainWindow()
    {
        // Pre-load resources before XAML parsing to work around Application.Resources
        // not being available during InitializeComponent() (stale build artifact issue).
        Resources.MergedDictionaries.Add(new ResourceDictionary
        {
            Source = new Uri("Resources/Styles.xaml", UriKind.Relative)
        });
        Resources[nameof(Helpers.BoolToThemeIconConverter)] = new Helpers.BoolToThemeIconConverter();
        Resources[nameof(Helpers.ToastTypeToColorConverter)] = new Helpers.ToastTypeToColorConverter();
        Resources["BooleanToVisibilityConverter"] = new Converters.BoolToVisibilityConverter();

        InitializeComponent();
        StateChanged += MainWindow_StateChanged;
    }

    // ======================================================================
    // Window Chrome Button Handlers
    // ======================================================================

    private void MinimizeButton_Click(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void MaximizeRestoreButton_Click(object sender, RoutedEventArgs e)
    {
        if (WindowState == WindowState.Maximized)
        {
            WindowState = WindowState.Normal;
        }
        else
        {
            WindowState = WindowState.Maximized;
        }
    }

    private async void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        // Check if "minimize to tray" is enabled
        try
        {
            var settingsService = App.Services.GetRequiredService<ISettingsService>();
            var settings = await settingsService.LoadSettingsAsync();

            if (settings.MinimizeToSystemTray)
            {
                // Minimize to tray instead of closing
                WindowState = WindowState.Minimized;
                Hide();
                Log.Debug("Window minimized to tray");
                return;
            }
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to check minimize-to-tray setting");
        }

        // Actually close the application
        Application.Current.Shutdown();
    }

    // ======================================================================
    // Window State Changed (update maximize/restore icon)
    // ======================================================================

    private void MainWindow_StateChanged(object? sender, EventArgs e)
    {
        if (WindowState == WindowState.Maximized)
        {
            MaximizeRestoreIcon.Kind = MaterialDesignThemes.Wpf.PackIconKind.WindowRestore;
            MaximizeRestoreButton.ToolTip = "Restore";
            WindowBorderOverlay.BorderThickness = new Thickness(0);
        }
        else
        {
            MaximizeRestoreIcon.Kind = MaterialDesignThemes.Wpf.PackIconKind.WindowMaximize;
            MaximizeRestoreButton.ToolTip = "Maximize";
            WindowBorderOverlay.BorderThickness = new Thickness(1);
        }
    }

    // ======================================================================
    // Window Position Save / Restore
    // ======================================================================

    private async void Window_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            var settingsService = App.Services.GetRequiredService<ISettingsService>();
            var settings = await settingsService.LoadSettingsAsync();

            // Restore position, but clamp to screen bounds
            var screenWidth = SystemParameters.VirtualScreenWidth;
            var screenHeight = SystemParameters.VirtualScreenHeight;

            if (settings.WindowLeft >= 0 && settings.WindowLeft < screenWidth - 100)
                Left = settings.WindowLeft;
            if (settings.WindowTop >= 0 && settings.WindowTop < screenHeight - 100)
                Top = settings.WindowTop;
            if (settings.WindowWidth >= MinWidth && settings.WindowWidth <= screenWidth)
                Width = settings.WindowWidth;
            if (settings.WindowHeight >= MinHeight && settings.WindowHeight <= screenHeight)
                Height = settings.WindowHeight;

            // Apply theme state to ViewModel
            if (DataContext is MainViewModel vm)
            {
                vm.IsDarkTheme = settings.Theme == "BepozDark";
            }

            // Wire up child view DataContexts from DI
            WireUpChildViews();

            Log.Debug("Window position restored: {Left},{Top} {Width}x{Height}",
                settings.WindowLeft, settings.WindowTop, settings.WindowWidth, settings.WindowHeight);
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to restore window position");
        }
    }

    // ======================================================================
    // Child View DataContext Wiring
    // ======================================================================

    private void WireUpChildViews()
    {
        try
        {
            DashboardContent.DataContext = App.Services.GetRequiredService<ViewModels.DashboardViewModel>();
            ToolsContent.DataContext = App.Services.GetRequiredService<ViewModels.ToolsViewModel>();
            LogsContent.DataContext = App.Services.GetRequiredService<ViewModels.LogsViewModel>();
            SettingsContent.DataContext = App.Services.GetRequiredService<ViewModels.SettingsViewModel>();

            // Trigger initial data loads
            if (DashboardContent.DataContext is ViewModels.DashboardViewModel dashVm)
                _ = dashVm.LoadDashboardAsync();
            if (ToolsContent.DataContext is ViewModels.ToolsViewModel toolsVm)
                _ = toolsVm.LoadToolsAsync();
            if (LogsContent.DataContext is ViewModels.LogsViewModel logsVm)
                _ = logsVm.LoadLogsAsync();
            if (SettingsContent.DataContext is ViewModels.SettingsViewModel settingsVm)
                _ = settingsVm.LoadSettingsAsync();

            Log.Debug("Child view DataContexts wired up successfully");
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to wire up child view DataContexts");
        }
    }

    private bool _closingHandled;

    private async void Window_Closing(object? sender, CancelEventArgs e)
    {
        if (_closingHandled) return;

        // Cancel the close to allow async save, then re-close
        e.Cancel = true;

        try
        {
            var settingsService = App.Services.GetRequiredService<ISettingsService>();
            var settings = await settingsService.LoadSettingsAsync();

            // Only save position if not maximized
            if (WindowState == WindowState.Normal)
            {
                settings.WindowLeft = Left;
                settings.WindowTop = Top;
                settings.WindowWidth = Width;
                settings.WindowHeight = Height;
            }

            await settingsService.SaveSettingsAsync(settings);
            Log.Debug("Window position saved");
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Failed to save window position on close");
        }

        // Dispose the ViewModel
        if (DataContext is MainViewModel vm)
        {
            vm.Dispose();
        }

        // Now allow the close to proceed
        _closingHandled = true;
        Close();
    }
}
