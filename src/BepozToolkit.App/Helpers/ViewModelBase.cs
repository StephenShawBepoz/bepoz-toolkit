using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace BepozToolkit.App.Helpers;

/// <summary>
/// Base class for all ViewModels. Provides INotifyPropertyChanged implementation
/// and convenient SetProperty helper for clean MVVM data binding.
/// </summary>
public abstract class ViewModelBase : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>
    /// Sets the backing field to the new value and raises PropertyChanged if the value changed.
    /// Returns true if the value was different and the event was raised.
    /// </summary>
    protected bool SetProperty<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return false;

        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    /// <summary>
    /// Raises the PropertyChanged event for the specified property.
    /// When called without arguments, uses the caller's member name.
    /// </summary>
    protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
