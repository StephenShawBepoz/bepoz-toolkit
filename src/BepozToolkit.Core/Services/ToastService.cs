using BepozToolkit.Core.Models;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Event-based toast notification service. When <see cref="Show"/> is called, a
/// <see cref="ToastMessage"/> is created and the <see cref="OnToastRequested"/> event is fired.
/// The UI layer subscribes to this event to render toast notifications.
/// </summary>
public sealed class ToastService : IToastService
{
    private readonly ILogger _logger;

    /// <inheritdoc />
    public event Action<ToastMessage>? OnToastRequested;

    public ToastService(ILogger logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public void Show(string title, string message, ToastType type = ToastType.Info)
    {
        _logger.Debug("Toast [{Type}] {Title}: {Message}", type, title, message);

        var toast = new ToastMessage
        {
            Title = title,
            Message = message,
            Type = type,
            AutoDismiss = true,
            DismissAfterMs = Constants.ToastAutoCloseMs
        };

        OnToastRequested?.Invoke(toast);
    }

    /// <inheritdoc />
    public void ShowSuccess(string message)
    {
        Show("Success", message, ToastType.Success);
    }

    /// <inheritdoc />
    public void ShowError(string message)
    {
        Show("Error", message, ToastType.Error);
    }

    /// <inheritdoc />
    public void ShowWarning(string message)
    {
        Show("Warning", message, ToastType.Warning);
    }

    /// <inheritdoc />
    public void ShowInfo(string message)
    {
        Show("Information", message, ToastType.Info);
    }
}
