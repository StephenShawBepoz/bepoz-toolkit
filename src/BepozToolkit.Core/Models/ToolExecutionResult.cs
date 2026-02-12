namespace BepozToolkit.Core.Models;

public class ToolExecutionResult
{
    public bool Success { get; set; }
    public int ExitCode { get; set; }
    public string Output { get; set; } = "";
    public string ErrorOutput { get; set; } = "";
    public long DurationMs { get; set; }
    public DateTime ExecutedAt { get; set; } = DateTime.UtcNow;
    public string ToolId { get; set; } = "";
    public string ToolName { get; set; } = "";
}
