using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages the execution history log, providing storage, retrieval, and automatic
/// pruning of past tool execution records.
/// </summary>
public interface IHistoryService
{
    /// <summary>
    /// Persists a new execution history entry.
    /// </summary>
    /// <param name="entry">The <see cref="ExecutionHistoryEntry"/> to save.</param>
    Task SaveExecutionAsync(ExecutionHistoryEntry entry);

    /// <summary>
    /// Retrieves the most recent execution history entries across all tools.
    /// </summary>
    /// <param name="count">The maximum number of entries to return.</param>
    /// <returns>A list of <see cref="ExecutionHistoryEntry"/> records ordered by most recent first.</returns>
    Task<List<ExecutionHistoryEntry>> GetRecentExecutionsAsync(int count = 20);

    /// <summary>
    /// Retrieves execution history entries for a specific tool.
    /// </summary>
    /// <param name="toolId">The unique identifier of the tool.</param>
    /// <param name="count">The maximum number of entries to return.</param>
    /// <returns>A list of <see cref="ExecutionHistoryEntry"/> records for the specified tool.</returns>
    Task<List<ExecutionHistoryEntry>> GetToolExecutionsAsync(string toolId, int count = 10);

    /// <summary>
    /// Retrieves a single execution history entry by its unique identifier.
    /// </summary>
    /// <param name="id">The unique identifier of the history entry.</param>
    /// <returns>The matching <see cref="ExecutionHistoryEntry"/>, or <c>null</c> if not found.</returns>
    Task<ExecutionHistoryEntry?> GetExecutionAsync(string id);

    /// <summary>
    /// Removes execution history entries older than the configured retention period
    /// defined by <see cref="Constants.HistoryRetentionDays"/>.
    /// </summary>
    Task PruneOldEntriesAsync();
}
