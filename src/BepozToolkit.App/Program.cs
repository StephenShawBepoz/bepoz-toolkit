using System;
using System.Windows;

namespace BepozToolkit.App;

/// <summary>
/// Custom entry point to catch exceptions during XAML initialization.
/// </summary>
public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        try
        {
            var app = new App();
            app.InitializeComponent();
            app.Run();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Fatal error during app initialization:\n\n{ex}",
                "Bepoz Toolkit - Fatal Error",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
    }
}
