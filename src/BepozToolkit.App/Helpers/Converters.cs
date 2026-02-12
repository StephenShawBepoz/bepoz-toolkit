using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;
using BepozToolkit.Core.Models;
using MaterialDesignThemes.Wpf;

namespace BepozToolkit.App.Helpers;

/// <summary>
/// Converts a boolean (IsDarkTheme) to the appropriate PackIconKind for the theme toggle button.
/// Dark = moon icon, Light = sun icon.
/// </summary>
public class BoolToThemeIconConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is bool isDark && isDark)
            return PackIconKind.WeatherNight;
        return PackIconKind.WeatherSunny;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

/// <summary>
/// Converts a ToastType enum to a Color for the accent bar and border of toast notifications.
/// </summary>
public class ToastTypeToColorConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is ToastType type)
        {
            return type switch
            {
                ToastType.Success => Color.FromRgb(0x4C, 0xAF, 0x50),  // #4CAF50
                ToastType.Error   => Color.FromRgb(0xF4, 0x43, 0x36),  // #F44336
                ToastType.Warning => Color.FromRgb(0xFF, 0x98, 0x00),  // #FF9800
                ToastType.Info    => Color.FromRgb(0x21, 0x96, 0xF3),  // #2196F3
                _ => Color.FromRgb(0x21, 0x96, 0xF3),
            };
        }
        return Color.FromRgb(0x21, 0x96, 0xF3);
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotImplementedException();
}

// BooleanToVisibilityConverter removed - use BepozToolkit.App.Converters.BoolToVisibilityConverter instead
