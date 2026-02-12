namespace BepozToolkit.Core.Models;

public class ActivityFeedItem
{
    public string ToolName { get; set; } = "";
    public DateTime Timestamp { get; set; }
    public string RelativeTime { get; set; } = "";
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
    public string Duration { get; set; } = "";
    public string Icon { get; set; } = "";
}
