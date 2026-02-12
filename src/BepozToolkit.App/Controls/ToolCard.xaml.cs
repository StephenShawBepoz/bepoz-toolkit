using System.Windows;
using System.Windows.Controls;
using BepozToolkit.Core.Models;

namespace BepozToolkit.App.Controls;

public partial class ToolCard : UserControl
{
    public ToolCard()
    {
        InitializeComponent();
    }

    #region DependencyProperties

    public static readonly DependencyProperty ToolNameProperty =
        DependencyProperty.Register(nameof(ToolName), typeof(string), typeof(ToolCard),
            new PropertyMetadata(""));

    public string ToolName
    {
        get => (string)GetValue(ToolNameProperty);
        set => SetValue(ToolNameProperty, value);
    }

    public static readonly DependencyProperty VersionProperty =
        DependencyProperty.Register(nameof(Version), typeof(string), typeof(ToolCard),
            new PropertyMetadata(""));

    public new string Version
    {
        get => (string)GetValue(VersionProperty);
        set => SetValue(VersionProperty, value);
    }

    public static readonly DependencyProperty DescriptionProperty =
        DependencyProperty.Register(nameof(Description), typeof(string), typeof(ToolCard),
            new PropertyMetadata(""));

    public string Description
    {
        get => (string)GetValue(DescriptionProperty);
        set => SetValue(DescriptionProperty, value);
    }

    public static readonly DependencyProperty CategoryProperty =
        DependencyProperty.Register(nameof(Category), typeof(string), typeof(ToolCard),
            new PropertyMetadata(""));

    public string Category
    {
        get => (string)GetValue(CategoryProperty);
        set => SetValue(CategoryProperty, value);
    }

    public static readonly DependencyProperty StatusProperty =
        DependencyProperty.Register(nameof(Status), typeof(ToolStatus), typeof(ToolCard),
            new PropertyMetadata(ToolStatus.Available));

    public ToolStatus Status
    {
        get => (ToolStatus)GetValue(StatusProperty);
        set => SetValue(StatusProperty, value);
    }

    public static readonly DependencyProperty IsFavoriteProperty =
        DependencyProperty.Register(nameof(IsFavorite), typeof(bool), typeof(ToolCard),
            new PropertyMetadata(false));

    public bool IsFavorite
    {
        get => (bool)GetValue(IsFavoriteProperty);
        set => SetValue(IsFavoriteProperty, value);
    }

    #endregion

    #region Routed Events

    public static readonly RoutedEvent RunToolClickedEvent =
        EventManager.RegisterRoutedEvent(nameof(RunToolClicked), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(ToolCard));

    public event RoutedEventHandler RunToolClicked
    {
        add => AddHandler(RunToolClickedEvent, value);
        remove => RemoveHandler(RunToolClickedEvent, value);
    }

    public static readonly RoutedEvent ToggleFavoriteClickedEvent =
        EventManager.RegisterRoutedEvent(nameof(ToggleFavoriteClicked), RoutingStrategy.Bubble,
            typeof(RoutedEventHandler), typeof(ToolCard));

    public event RoutedEventHandler ToggleFavoriteClicked
    {
        add => AddHandler(ToggleFavoriteClickedEvent, value);
        remove => RemoveHandler(ToggleFavoriteClickedEvent, value);
    }

    #endregion

    private void OnRunToolClick(object sender, RoutedEventArgs e)
    {
        RaiseEvent(new RoutedEventArgs(RunToolClickedEvent, this));
    }

    private void OnToggleFavoriteClick(object sender, RoutedEventArgs e)
    {
        IsFavorite = !IsFavorite;
        RaiseEvent(new RoutedEventArgs(ToggleFavoriteClickedEvent, this));
    }

    private void OnCopyNameClick(object sender, RoutedEventArgs e)
    {
        if (!string.IsNullOrWhiteSpace(ToolName))
        {
            Clipboard.SetText(ToolName);
        }
    }
}
