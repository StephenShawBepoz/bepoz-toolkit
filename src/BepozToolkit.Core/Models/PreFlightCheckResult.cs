namespace BepozToolkit.Core.Models;

public class PreFlightCheckResult
{
    public string CheckName { get; set; } = "";
    public bool Passed { get; set; }
    public string Message { get; set; } = "";
    public string? ActionLabel { get; set; }
    public PreFlightActionType ActionType { get; set; } = PreFlightActionType.None;
}

public enum PreFlightActionType
{
    None,
    RestartAsAdmin,
    DownloadDependency,
    RetryConnection
}
