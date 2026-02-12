using BepozToolkit.Core.Database;
using BepozToolkit.Core.Models;
using Microsoft.Data.Sqlite;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages the execution history log stored in the SQLite ExecutionHistory table.
/// Provides storage, retrieval, and automatic pruning of past tool execution records.
/// </summary>
public sealed class HistoryService : IHistoryService
{
    private readonly BepozToolkitDb _db;
    private readonly ILogger _logger;

    public HistoryService(BepozToolkitDb db, ILogger logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task SaveExecutionAsync(ExecutionHistoryEntry entry)
    {
        _logger.Debug("Saving execution history for tool: {ToolId} ({ToolName})", entry.ToolId, entry.ToolName);

        const string sql = """
            INSERT INTO ExecutionHistory (ToolId, ToolName, ExecutedAt, DurationMs, Success, FullOutput, ErrorOutput, Parameters, ConnectionId)
            VALUES (@ToolId, @ToolName, @ExecutedAt, @DurationMs, @Success, @FullOutput, @ErrorOutput, @Parameters, @ConnectionId);
            """;

        await _db.ExecuteNonQueryAsync(sql,
            new SqliteParameter("@ToolId", entry.ToolId),
            new SqliteParameter("@ToolName", entry.ToolName),
            new SqliteParameter("@ExecutedAt", entry.ExecutedAt.ToString("o")),
            new SqliteParameter("@DurationMs", entry.DurationMs),
            new SqliteParameter("@Success", entry.Success ? 1 : 0),
            new SqliteParameter("@FullOutput", entry.FullOutput),
            new SqliteParameter("@ErrorOutput", entry.ErrorOutput),
            new SqliteParameter("@Parameters", entry.Parameters),
            new SqliteParameter("@ConnectionId", (object?)entry.ConnectionId ?? DBNull.Value));

        _logger.Debug("Execution history saved for {ToolId}", entry.ToolId);

        // Auto-prune after every save to keep the table bounded
        await PruneOldEntriesAsync();
    }

    /// <inheritdoc />
    public async Task<List<ExecutionHistoryEntry>> GetRecentExecutionsAsync(int count = 20)
    {
        _logger.Debug("Getting {Count} most recent executions", count);

        const string sql = """
            SELECT Id, ToolId, ToolName, ExecutedAt, DurationMs, Success, FullOutput, ErrorOutput, Parameters, ConnectionId
            FROM ExecutionHistory
            ORDER BY ExecutedAt DESC
            LIMIT @Limit;
            """;

        return await _db.ExecuteReaderAsync(sql, MapHistoryEntry,
            new SqliteParameter("@Limit", count));
    }

    /// <inheritdoc />
    public async Task<List<ExecutionHistoryEntry>> GetToolExecutionsAsync(string toolId, int count = 10)
    {
        _logger.Debug("Getting {Count} executions for tool: {ToolId}", count, toolId);

        const string sql = """
            SELECT Id, ToolId, ToolName, ExecutedAt, DurationMs, Success, FullOutput, ErrorOutput, Parameters, ConnectionId
            FROM ExecutionHistory
            WHERE ToolId = @ToolId
            ORDER BY ExecutedAt DESC
            LIMIT @Limit;
            """;

        return await _db.ExecuteReaderAsync(sql, MapHistoryEntry,
            new SqliteParameter("@ToolId", toolId),
            new SqliteParameter("@Limit", count));
    }

    /// <inheritdoc />
    public async Task<ExecutionHistoryEntry?> GetExecutionAsync(string id)
    {
        _logger.Debug("Getting execution history entry: {Id}", id);

        const string sql = """
            SELECT Id, ToolId, ToolName, ExecutedAt, DurationMs, Success, FullOutput, ErrorOutput, Parameters, ConnectionId
            FROM ExecutionHistory
            WHERE Id = @Id;
            """;

        var results = await _db.ExecuteReaderAsync(sql, MapHistoryEntry,
            new SqliteParameter("@Id", id));

        return results.FirstOrDefault();
    }

    /// <inheritdoc />
    public async Task PruneOldEntriesAsync()
    {
        _logger.Debug("Pruning execution history older than {Days} days", Constants.HistoryRetentionDays);

        var cutoff = DateTime.UtcNow.AddDays(-Constants.HistoryRetentionDays).ToString("o");

        // Delete entries older than retention period
        var deletedByAge = await _db.ExecuteNonQueryAsync(
            "DELETE FROM ExecutionHistory WHERE ExecutedAt < @Cutoff;",
            new SqliteParameter("@Cutoff", cutoff));

        if (deletedByAge > 0)
        {
            _logger.Information("Pruned {Count} execution history entries by age", deletedByAge);
        }

        // Also enforce maximum entry count
        var countResult = await _db.ExecuteScalarAsync("SELECT COUNT(*) FROM ExecutionHistory;");
        var totalCount = countResult is not null and not DBNull ? Convert.ToInt32(countResult) : 0;

        if (totalCount > Constants.MaxExecutionHistoryEntries)
        {
            var excess = totalCount - Constants.MaxExecutionHistoryEntries;
            var deletedByCount = await _db.ExecuteNonQueryAsync(
                """
                DELETE FROM ExecutionHistory
                WHERE Id IN (
                    SELECT Id FROM ExecutionHistory
                    ORDER BY ExecutedAt ASC
                    LIMIT @Excess
                );
                """,
                new SqliteParameter("@Excess", excess));

            if (deletedByCount > 0)
            {
                _logger.Information("Pruned {Count} execution history entries by count limit", deletedByCount);
            }
        }
    }

    private static ExecutionHistoryEntry MapHistoryEntry(SqliteDataReader reader)
    {
        return new ExecutionHistoryEntry
        {
            Id = reader.GetInt32(0).ToString(),
            ToolId = reader.GetString(1),
            ToolName = reader.GetString(2),
            ExecutedAt = DateTime.TryParse(reader.GetString(3), out var dt) ? dt : DateTime.MinValue,
            DurationMs = reader.GetInt64(4),
            Success = reader.GetInt32(5) == 1,
            FullOutput = reader.GetString(6),
            ErrorOutput = reader.GetString(7),
            Parameters = reader.GetString(8),
            ConnectionId = reader.IsDBNull(9) ? null : reader.GetString(9)
        };
    }
}
