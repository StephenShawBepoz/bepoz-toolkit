using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Tracks and retrieves tool usage statistics for dashboards, reporting, and usage analytics.
/// </summary>
public interface IStatsService
{
    /// <summary>
    /// Records a single tool execution event in the statistics store.
    /// </summary>
    /// <param name="stat">The <see cref="UsageStatistic"/> describing the execution.</param>
    Task RecordExecutionAsync(UsageStatistic stat);

    /// <summary>
    /// Retrieves the most frequently executed tools, ordered by execution count descending.
    /// </summary>
    /// <param name="count">The maximum number of tools to return.</param>
    /// <returns>A list of <see cref="UsageStatistic"/> entries for the top tools.</returns>
    Task<List<UsageStatistic>> GetTopToolsAsync(int count = 10);

    /// <summary>
    /// Retrieves the execution history for a specific tool.
    /// </summary>
    /// <param name="toolId">The unique identifier of the tool.</param>
    /// <param name="limit">The maximum number of records to return.</param>
    /// <returns>A list of <see cref="UsageStatistic"/> entries for the specified tool.</returns>
    Task<List<UsageStatistic>> GetToolHistoryAsync(string toolId, int limit = 50);

    /// <summary>
    /// Gets the total number of tool executions ever recorded.
    /// </summary>
    /// <returns>The total execution count.</returns>
    Task<int> GetTotalExecutionCountAsync();

    /// <summary>
    /// Calculates the overall success rate across all recorded executions.
    /// </summary>
    /// <returns>The success rate as a percentage (0.0 to 100.0).</returns>
    Task<double> GetSuccessRateAsync();

    /// <summary>
    /// Retrieves daily execution counts for the specified number of past days.
    /// </summary>
    /// <param name="days">The number of days to look back.</param>
    /// <returns>A list of date/count pairs ordered chronologically.</returns>
    Task<List<(DateTime Date, int Count)>> GetDailyExecutionCountsAsync(int days = 7);

    /// <summary>
    /// Removes statistics older than the specified retention period.
    /// </summary>
    /// <param name="retentionDays">The number of days of statistics to keep.</param>
    Task CleanOldStatsAsync(int retentionDays = 90);
}
