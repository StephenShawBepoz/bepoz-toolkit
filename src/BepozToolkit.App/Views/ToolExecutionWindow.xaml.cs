using System.Collections.Specialized;
using System.Windows;
using System.Windows.Controls;

namespace BepozToolkit.App.Views;

public partial class ToolExecutionWindow : Window
{
    public ToolExecutionWindow()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private void OnLoaded(object sender, RoutedEventArgs e)
    {
        // Auto-scroll the output listbox when new items are added
        if (DataContext is ViewModels.ToolExecutionViewModel vm)
        {
            vm.OutputLines.CollectionChanged += OnOutputLinesChanged;
        }
    }

    private void OnOutputLinesChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (e.Action == NotifyCollectionChangedAction.Add)
        {
            // Find the ListBox in the visual tree and scroll to the bottom
            Dispatcher.BeginInvoke(() =>
            {
                var listBox = FindListBox(this);
                if (listBox is not null && listBox.Items.Count > 0)
                {
                    listBox.ScrollIntoView(listBox.Items[^1]);
                }
            });
        }
    }

    private static ListBox? FindListBox(DependencyObject parent)
    {
        for (int i = 0; i < System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent); i++)
        {
            var child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i);
            if (child is ListBox lb)
                return lb;
            var result = FindListBox(child);
            if (result is not null)
                return result;
        }
        return null;
    }

    protected override void OnClosed(EventArgs e)
    {
        if (DataContext is ViewModels.ToolExecutionViewModel vm)
        {
            vm.OutputLines.CollectionChanged -= OnOutputLinesChanged;
        }
        base.OnClosed(e);
    }
}
