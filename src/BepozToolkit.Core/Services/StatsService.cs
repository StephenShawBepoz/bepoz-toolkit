using BepozToolkit.Core.Database;
using BepozToolkit.Core.Models;
using Microsoft.Data.Sqlite;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Tracks and retrieves tool usage statistics using the SQLite UsageStatistics table.
/// Provides aggregation methods for dashboards, reporting, and usage analytics.
/// </summary>
public sealed class StatsService : IStatsService
{
    private readonly BepozToolkitDb _db;
    private readonly ILogger _logger;

    public StatsService(BepozToolkitDb db, ILogger logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task RecordExecutionAsync(UsageStatistic stat)
    {
        _logger.Debug("Recording execution for tool: {ToolId} ({ToolName})", stat.ToolId, stat.ToolName);

        // Check if a row already exists for this tool
        var existing = await _db.ExecuteScalarAsync(
            "SELECT Id FROM UsageStatistics WHERE ToolId = @ToolId;",
            new SqliteParameter("@ToolId", stat.ToolId));

        if (existing is not null and not DBNull)
        {
            // Update existing row by incrementing counters
            const string updateSql = """
                UPDATE UsageStatistics SET
                    ExecutionCount  = ExecutionCount + @ExecutionCount,
                    SuccessCount    = SuccessCount + @SuccessCount,
                    FailureCount    = FailureCount + @FailureCount,
                    TotalDurationMs = TotalDurationMs + @TotalDurationMs,
                    LastExecutedAt  = @LastExecutedAt
                WHERE ToolId = @ToolId;
                """;

            await _db.ExecuteNonQueryAsync(updateSql,
                new SqliteParameter("@ToolId", stat.ToolId),
                new SqliteParameter("@ExecutionCount", stat.ExecutionCount),
                new SqliteParameter("@SuccessCount", stat.SuccessCount),
                new SqliteParameter("@FailureCount", stat.FailureCount),
                new SqliteParameter("@TotalDurationMs", stat.TotalDurationMs),
                new SqliteParameter("@LastExecutedAt", stat.LastExecutedAt.ToString("o")));
        }
        else
        {
            // Insert new row
            const string insertSql = """
                INSERT INTO UsageStatistics (ToolId, ToolName, ExecutionCount, SuccessCount, FailureCount, TotalDurationMs, LastExecutedAt)
                VALUES (@ToolId, @ToolName, @ExecutionCount, @SuccessCount, @FailureCount, @TotalDurationMs, @LastExecutedAt);
                """;

            await _db.ExecuteNonQueryAsync(insertSql,
                new SqliteParameter("@ToolId", stat.ToolId),
                new SqliteParameter("@ToolName", stat.ToolName),
                new SqliteParameter("@ExecutionCount", stat.ExecutionCount),
                new SqliteParameter("@SuccessCount", stat.SuccessCount),
                new SqliteParameter("@FailureCount", stat.FailureCount),
                new SqliteParameter("@TotalDurationMs", stat.TotalDurationMs),
                new SqliteParameter("@LastExecutedAt", stat.LastExecutedAt.ToString("o")));
        }

        _logger.Debug("Execution recorded for {ToolId}", stat.ToolId);
    }

    /// <inheritdoc />
    public async Task<List<UsageStatistic>> GetTopToolsAsync(int count = 10)
    {
        _logger.Debug("Getting top {Count} tools", count);

        const string sql = """
            SELECT ToolId, ToolName, ExecutionCount, SuccessCount, FailureCount, TotalDurationMs, LastExecutedAt
            FROM UsageStatistics
            ORDER BY ExecutionCount DESC
            LIMIT @Limit;
            """;

        return await _db.ExecuteReaderAsync(sql, MapUsageStatistic,
            new SqliteParameter("@Limit", count));
    }

    /// <inheritdoc />
    public async Task<List<UsageStatistic>> GetToolHistoryAsync(string toolId, int limit = 50)
    {
        _logger.Debug("Getting history for tool: {ToolId} (limit={Limit})", toolId, limit);

        const string sql = """
            SELECT ToolId, ToolName, ExecutionCount, SuccessCount, FailureCount, TotalDurationMs, LastExecutedAt
            FROM UsageStatistics
            WHERE ToolId = @ToolId
            ORDER BY LastExecutedAt DESC
            LIMIT @Limit;
            """;

        return await _db.ExecuteReaderAsync(sql, MapUsageStatistic,
            new SqliteParameter("@ToolId", toolId),
            new SqliteParameter("@Limit", limit));
    }

    /// <inheritdoc />
    public async Task<int> GetTotalExecutionCountAsync()
    {
        _logger.Debug("Getting total execution count");

        var result = await _db.ExecuteScalarAsync(
            "SELECT COALESCE(SUM(ExecutionCount), 0) FROM UsageStatistics;");

        return result is not null and not DBNull ? Convert.ToInt32(result) : 0;
    }

    /// <inheritdoc />
    public async Task<double> GetSuccessRateAsync()
    {
        _logger.Debug("Calculating overall success rate");

        var totalResult = await _db.ExecuteScalarAsync(
            "SELECT COALESCE(SUM(ExecutionCount), 0) FROM UsageStatistics;");
        var successResult = await _db.ExecuteScalarAsync(
            "SELECT COALESCE(SUM(SuccessCount), 0) FROM UsageStatistics;");

        var totalCount = totalResult is not null and not DBNull ? Convert.ToInt32(totalResult) : 0;
        var successCount = successResult is not null and not DBNull ? Convert.ToInt32(successResult) : 0;

        if (totalCount == 0)
            return 0.0;

        return (double)successCount / totalCount * 100.0;
    }

    /// <inheritdoc />
    public async Task<List<(DateTime Date, int Count)>> GetDailyExecutionCountsAsync(int days = 7)
    {
        _logger.Debug("Getting daily execution counts for the last {Days} days", days);

        // We query from ExecutionHistory for per-day granularity since UsageStatistics
        // is an aggregate table. Fall back to UsageStatistics if ExecutionHistory is empty.
        var cutoff = DateTime.UtcNow.AddDays(-days).ToString("o");

        const string sql = """
            SELECT date(ExecutedAt) AS ExecDate, COUNT(*) AS ExecCount
            FROM ExecutionHistory
            WHERE ExecutedAt >= @Cutoff
            GROUP BY date(ExecutedAt)
            ORDER BY ExecDate ASC;
            """;

        var results = await _db.ExecuteReaderAsync(sql,
            reader =>
            {
                var dateStr = reader.GetString(0);
                var count = reader.GetInt32(1);
                var date = DateTime.TryParse(dateStr, out var d) ? d : DateTime.MinValue;
                return (Date: date, Count: count);
            },
            new SqliteParameter("@Cutoff", cutoff));

        // Fill in missing days with zero counts for a complete series
        var filled = new List<(DateTime Date, int Count)>();
        var startDate = DateTime.UtcNow.Date.AddDays(-days + 1);

        for (var i = 0; i < days; i++)
        {
            var date = startDate.AddDays(i);
            var existing = results.FirstOrDefault(r => r.Date.Date == date);
            filled.Add(existing.Date != DateTime.MinValue
                ? existing
                : (date, 0));
        }

        return filled;
    }

    /// <inheritdoc />
    public async Task CleanOldStatsAsync(int retentionDays = 90)
    {
        _logger.Information("Cleaning statistics older than {RetentionDays} days", retentionDays);

        var cutoff = DateTime.UtcNow.AddDays(-retentionDays).ToString("o");

        var deleted = await _db.ExecuteNonQueryAsync(
            "DELETE FROM UsageStatistics WHERE LastExecutedAt < @Cutoff;",
            new SqliteParameter("@Cutoff", cutoff));

        _logger.Information("Removed {Count} old statistics entries", deleted);
    }

    private static UsageStatistic MapUsageStatistic(Microsoft.Data.Sqlite.SqliteDataReader reader)
    {
        return new UsageStatistic
        {
            ToolId = reader.GetString(0),
            ToolName = reader.GetString(1),
            ExecutionCount = reader.GetInt32(2),
            SuccessCount = reader.GetInt32(3),
            FailureCount = reader.GetInt32(4),
            TotalDurationMs = reader.GetInt64(5),
            LastExecutedAt = DateTime.TryParse(reader.GetString(6), out var dt)
                ? dt
                : DateTime.MinValue
        };
    }
}
