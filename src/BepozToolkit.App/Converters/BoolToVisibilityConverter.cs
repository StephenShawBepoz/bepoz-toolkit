using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace BepozToolkit.App.Converters;

/// <summary>
/// Converts a boolean to Visibility. True = Visible, False = Collapsed.
/// Pass "Invert" as parameter to reverse.
/// </summary>
public class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        bool boolValue = value is bool b && b;
        bool invert = parameter is string s && s.Equals("Invert", StringComparison.OrdinalIgnoreCase);

        if (invert) boolValue = !boolValue;

        return boolValue ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        bool visible = value is Visibility v && v == Visibility.Visible;
        bool invert = parameter is string s && s.Equals("Invert", StringComparison.OrdinalIgnoreCase);

        return invert ? !visible : visible;
    }
}

/// <summary>
/// Converts a boolean to a star character for favorite indicators.
/// True = filled star, False = outline star.
/// </summary>
public class BoolToStarConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is bool b && b ? "\u2605" : "\u2606";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is string s && s == "\u2605";
    }
}

/// <summary>
/// Converts a boolean success value to a color brush.
/// True = SuccessColor, False = ErrorColor.
/// </summary>
public class BoolToSuccessBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is bool success && success)
            return Application.Current.TryFindResource("SuccessColor") ?? Brushes.Green;
        return Application.Current.TryFindResource("ErrorColor") ?? Brushes.Red;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Converts a ToolStatus enum to a colored SolidColorBrush.
/// </summary>
public class StatusToBrushConverter : IValueConverter
{
    private static readonly SolidColorBrush FallbackBrush = Brushes.Gray;

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is BepozToolkit.Core.Models.ToolStatus status)
        {
            return status switch
            {
                BepozToolkit.Core.Models.ToolStatus.Available => Application.Current.TryFindResource("SuccessColor") ?? Brushes.Green,
                BepozToolkit.Core.Models.ToolStatus.Cached => Application.Current.TryFindResource("InfoColor") ?? Brushes.Blue,
                BepozToolkit.Core.Models.ToolStatus.Running => Application.Current.TryFindResource("AccentPrimary") ?? Brushes.DodgerBlue,
                BepozToolkit.Core.Models.ToolStatus.Completed => Application.Current.TryFindResource("SuccessColor") ?? Brushes.Green,
                BepozToolkit.Core.Models.ToolStatus.Failed => Application.Current.TryFindResource("ErrorColor") ?? Brushes.Red,
                BepozToolkit.Core.Models.ToolStatus.Stale => Application.Current.TryFindResource("WarningColor") ?? Brushes.Orange,
                BepozToolkit.Core.Models.ToolStatus.UnavailableOffline => Application.Current.TryFindResource("TextDisabled") ?? FallbackBrush,
                _ => Application.Current.TryFindResource("TextSecondary") ?? FallbackBrush,
            };
        }
        return Application.Current.TryFindResource("TextSecondary") ?? FallbackBrush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Converts a log level string to a brush color for level-coded log entries.
/// </summary>
public class LogLevelToBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is string level)
        {
            return level.ToLowerInvariant() switch
            {
                "error" => Application.Current.TryFindResource("ErrorColor") ?? Brushes.Red,
                "warning" => Application.Current.TryFindResource("WarningColor") ?? Brushes.Orange,
                "success" => Application.Current.TryFindResource("SuccessColor") ?? Brushes.Green,
                "info" => Application.Current.TryFindResource("InfoColor") ?? Brushes.Blue,
                _ => Application.Current.TryFindResource("TextSecondary") ?? Brushes.Gray,
            };
        }
        return Application.Current.TryFindResource("TextSecondary") ?? Brushes.Gray;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Converts a duration in milliseconds to a human-readable string.
/// </summary>
public class DurationConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is long ms)
        {
            if (ms < 1000) return $"{ms}ms";
            if (ms < 60000) return $"{ms / 1000.0:F1}s";
            return $"{ms / 60000.0:F1}m";
        }
        return "—";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Converts a boolean to a success/failure icon character.
/// </summary>
public class BoolToSuccessIconConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is bool b && b ? "\u2713" : "\u2717";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Converts a file size in bytes to a human-readable string (KB, MB, GB).
/// </summary>
public class FileSizeConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is long bytes)
        {
            if (bytes < 1024) return $"{bytes} B";
            if (bytes < 1024 * 1024) return $"{bytes / 1024.0:F1} KB";
            if (bytes < 1024 * 1024 * 1024) return $"{bytes / (1024.0 * 1024.0):F1} MB";
            return $"{bytes / (1024.0 * 1024.0 * 1024.0):F2} GB";
        }
        return "0 B";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Converts an enum-based StatusPillStatus to a brush for the pill dot.
/// </summary>
public class StatusPillBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is Controls.StatusPillStatus status)
        {
            return status switch
            {
                Controls.StatusPillStatus.Healthy => Application.Current.TryFindResource("SuccessColor") ?? Brushes.Green,
                Controls.StatusPillStatus.Warning => Application.Current.TryFindResource("WarningColor") ?? Brushes.Orange,
                Controls.StatusPillStatus.Error => Application.Current.TryFindResource("ErrorColor") ?? Brushes.Red,
                _ => Application.Current.TryFindResource("TextSecondary") ?? Brushes.Gray,
            };
        }
        return Application.Current.TryFindResource("TextSecondary") ?? Brushes.Gray;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Returns Visibility.Visible when the string value equals the converter parameter (for radio-style filtering).
/// </summary>
public class EqualityToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is null || parameter is null) return Visibility.Collapsed;
        return value.ToString() == parameter.ToString() ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}

/// <summary>
/// Inverts a boolean value. True becomes False, False becomes True.
/// Used for binding the "Light" theme radio button to IsDarkTheme.
/// </summary>
public class InverseBoolConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is bool b && !b;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is bool b && !b;
    }
}

/// <summary>
/// Converts a non-empty string to Visibility.Visible, empty/null to Collapsed.
/// </summary>
public class StringNotEmptyToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return value is string s && !string.IsNullOrEmpty(s) ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
