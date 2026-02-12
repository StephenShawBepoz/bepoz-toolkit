using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Provides a notification system for displaying transient toast messages to the user,
/// supporting success, error, warning, and informational message types.
/// </summary>
public interface IToastService
{
    /// <summary>
    /// Displays a toast notification with full control over title, message, and type.
    /// </summary>
    /// <param name="title">The bold heading text of the toast.</param>
    /// <param name="message">The body text of the toast.</param>
    /// <param name="type">The visual style of the toast. Defaults to <see cref="ToastType.Info"/>.</param>
    void Show(string title, string message, ToastType type = ToastType.Info);

    /// <summary>
    /// Displays a success toast with the default title.
    /// </summary>
    /// <param name="message">The body text of the toast.</param>
    void ShowSuccess(string message);

    /// <summary>
    /// Displays an error toast with the default title.
    /// </summary>
    /// <param name="message">The body text of the toast.</param>
    void ShowError(string message);

    /// <summary>
    /// Displays a warning toast with the default title.
    /// </summary>
    /// <param name="message">The body text of the toast.</param>
    void ShowWarning(string message);

    /// <summary>
    /// Displays an informational toast with the default title.
    /// </summary>
    /// <param name="message">The body text of the toast.</param>
    void ShowInfo(string message);

    /// <summary>
    /// Raised when a toast notification should be displayed by the UI layer.
    /// Subscribers (typically the layout component) listen to this event to render toast messages.
    /// </summary>
    event Action<ToastMessage> OnToastRequested;
}
