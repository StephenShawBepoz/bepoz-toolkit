namespace BepozToolkit.Core.Models;

public class ExecutionHistoryEntry
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string ToolId { get; set; } = "";
    public string ToolName { get; set; } = "";
    public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;
    public long DurationMs { get; set; }
    public bool Success { get; set; }
    public string FullOutput { get; set; } = "";
    public string ErrorOutput { get; set; } = "";
    public string Parameters { get; set; } = "{}";
    public string? ConnectionId { get; set; }
}
