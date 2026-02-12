using System.Windows.Input;

namespace BepozToolkit.App.Helpers;

/// <summary>
/// A simple ICommand implementation that delegates to Action/Func callbacks.
/// Supports parameterless commands and an optional CanExecute predicate.
/// </summary>
public class RelayCommand : ICommand
{
    private readonly Action _execute;
    private readonly Func<bool>? _canExecute;

    public RelayCommand(Action execute, Func<bool>? canExecute = null)
    {
        _execute = execute ?? throw new ArgumentNullException(nameof(execute));
        _canExecute = canExecute;
    }

    public event EventHandler? CanExecuteChanged
    {
        add => CommandManager.RequerySuggested += value;
        remove => CommandManager.RequerySuggested -= value;
    }

    public bool CanExecute(object? parameter) => _canExecute?.Invoke() ?? true;

    public void Execute(object? parameter) => _execute();

    /// <summary>
    /// Forces a re-evaluation of CanExecute for all commands.
    /// </summary>
    public static void RaiseCanExecuteChanged() => CommandManager.InvalidateRequerySuggested();
}

/// <summary>
/// A typed ICommand implementation that accepts a parameter of type T.
/// </summary>
public class RelayCommand<T> : ICommand
{
    private readonly Action<T?> _execute;
    private readonly Predicate<T?>? _canExecute;

    public RelayCommand(Action<T?> execute, Predicate<T?>? canExecute = null)
    {
        _execute = execute ?? throw new ArgumentNullException(nameof(execute));
        _canExecute = canExecute;
    }

    public event EventHandler? CanExecuteChanged
    {
        add => CommandManager.RequerySuggested += value;
        remove => CommandManager.RequerySuggested -= value;
    }

    public bool CanExecute(object? parameter)
    {
        if (_canExecute is null) return true;
        if (parameter is T typed) return _canExecute(typed);
        if (parameter is null) return _canExecute(default);
        return false;
    }

    public void Execute(object? parameter)
    {
        if (parameter is T typed)
            _execute(typed);
        else if (parameter is null)
            _execute(default);
    }
}

/// <summary>
/// An ICommand implementation for async operations. Prevents concurrent execution by default
/// and correctly marshals back to the UI thread via the captured SynchronizationContext.
/// </summary>
public class AsyncRelayCommand : ICommand
{
    private readonly Func<Task> _execute;
    private readonly Func<bool>? _canExecute;
    private bool _isExecuting;

    public AsyncRelayCommand(Func<Task> execute, Func<bool>? canExecute = null)
    {
        _execute = execute ?? throw new ArgumentNullException(nameof(execute));
        _canExecute = canExecute;
    }

    public event EventHandler? CanExecuteChanged
    {
        add => CommandManager.RequerySuggested += value;
        remove => CommandManager.RequerySuggested -= value;
    }

    public bool CanExecute(object? parameter) => !_isExecuting && (_canExecute?.Invoke() ?? true);

    public async void Execute(object? parameter)
    {
        if (_isExecuting) return;

        _isExecuting = true;
        RelayCommand.RaiseCanExecuteChanged();

        try
        {
            await _execute();
        }
        finally
        {
            _isExecuting = false;
            RelayCommand.RaiseCanExecuteChanged();
        }
    }
}

/// <summary>
/// A typed async ICommand implementation accepting a parameter of type T.
/// </summary>
public class AsyncRelayCommand<T> : ICommand
{
    private readonly Func<T?, Task> _execute;
    private readonly Predicate<T?>? _canExecute;
    private bool _isExecuting;

    public AsyncRelayCommand(Func<T?, Task> execute, Predicate<T?>? canExecute = null)
    {
        _execute = execute ?? throw new ArgumentNullException(nameof(execute));
        _canExecute = canExecute;
    }

    public event EventHandler? CanExecuteChanged
    {
        add => CommandManager.RequerySuggested += value;
        remove => CommandManager.RequerySuggested -= value;
    }

    public bool CanExecute(object? parameter)
    {
        if (_isExecuting) return false;
        if (_canExecute is null) return true;
        if (parameter is T typed) return _canExecute(typed);
        if (parameter is null) return _canExecute(default);
        return false;
    }

    public async void Execute(object? parameter)
    {
        if (_isExecuting) return;

        _isExecuting = true;
        RelayCommand.RaiseCanExecuteChanged();

        try
        {
            if (parameter is T typed)
                await _execute(typed);
            else
                await _execute(default);
        }
        finally
        {
            _isExecuting = false;
            RelayCommand.RaiseCanExecuteChanged();
        }
    }
}
