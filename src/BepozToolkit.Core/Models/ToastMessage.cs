using BepozToolkit.Core;

namespace BepozToolkit.Core.Models;

public class ToastMessage
{
    public string Title { get; set; } = "";
    public string Message { get; set; } = "";
    public ToastType Type { get; set; } = ToastType.Info;
    public bool AutoDismiss { get; set; } = true;
    public int DismissAfterMs { get; set; } = Constants.ToastAutoCloseMs;
}

public enum ToastType
{
    Success,
    Error,
    Warning,
    Info
}
