using System.Collections.Specialized;
using System.Windows;
using System.Windows.Controls;

namespace BepozToolkit.App.Views;

public partial class TSPlusManagerWindow : Window
{
    public TSPlusManagerWindow()
    {
        InitializeComponent();
        Loaded += OnLoaded;
    }

    private async void OnLoaded(object sender, RoutedEventArgs e)
    {
        if (DataContext is ViewModels.TSPlusManagerViewModel vm)
        {
            vm.OutputLines.CollectionChanged += OnOutputLinesChanged;
            await vm.InitializeAsync();
        }
    }

    private void OnOutputLinesChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (e.Action == NotifyCollectionChangedAction.Add)
        {
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
            if (child is ListBox lb && lb.FontFamily.Source == "Consolas")
                return lb;
            var result = FindListBox(child);
            if (result is not null)
                return result;
        }
        return null;
    }

    protected override void OnClosed(EventArgs e)
    {
        if (DataContext is ViewModels.TSPlusManagerViewModel vm)
        {
            vm.OutputLines.CollectionChanged -= OnOutputLinesChanged;
        }
        base.OnClosed(e);
    }
}
