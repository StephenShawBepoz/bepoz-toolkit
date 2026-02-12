namespace BepozToolkit.Core.Models;

public class UsageStatistic
{
    public string ToolId { get; set; } = "";
    public string ToolName { get; set; } = "";
    public int ExecutionCount { get; set; }
    public int SuccessCount { get; set; }
    public int FailureCount { get; set; }
    public long TotalDurationMs { get; set; }
    public long AverageDurationMs => ExecutionCount > 0 ? TotalDurationMs / ExecutionCount : 0;
    public DateTime LastExecutedAt { get; set; }
    public double SuccessRate => ExecutionCount > 0 ? (double)SuccessCount / ExecutionCount * 100 : 0;
}
