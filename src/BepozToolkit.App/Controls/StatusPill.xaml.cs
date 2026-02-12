using System.Windows;
using System.Windows.Controls;

namespace BepozToolkit.App.Controls;

/// <summary>
/// Status indicator values for the StatusPill control.
/// </summary>
public enum StatusPillStatus
{
    Healthy,
    Warning,
    Error
}

/// <summary>
/// A compact health indicator control displaying a colored dot and text label.
/// Shows detail text in a ToolTip on hover.
/// </summary>
public partial class StatusPill : UserControl
{
    public StatusPill()
    {
        InitializeComponent();
    }

    #region DependencyProperties

    public static readonly DependencyProperty LabelProperty =
        DependencyProperty.Register(nameof(Label), typeof(string), typeof(StatusPill),
            new PropertyMetadata("Status"));

    public string Label
    {
        get => (string)GetValue(LabelProperty);
        set => SetValue(LabelProperty, value);
    }

    public static readonly DependencyProperty StatusProperty =
        DependencyProperty.Register(nameof(Status), typeof(StatusPillStatus), typeof(StatusPill),
            new PropertyMetadata(StatusPillStatus.Healthy));

    public StatusPillStatus Status
    {
        get => (StatusPillStatus)GetValue(StatusProperty);
        set => SetValue(StatusProperty, value);
    }

    public static readonly DependencyProperty DetailProperty =
        DependencyProperty.Register(nameof(Detail), typeof(string), typeof(StatusPill),
            new PropertyMetadata(""));

    public string Detail
    {
        get => (string)GetValue(DetailProperty);
        set => SetValue(DetailProperty, value);
    }

    #endregion
}
