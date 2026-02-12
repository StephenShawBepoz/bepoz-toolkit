using Microsoft.Data.Sqlite;
using Serilog;

namespace BepozToolkit.Core.Database;

/// <summary>
/// Pure SQLite database context using Microsoft.Data.Sqlite (no EF Core).
/// Manages all table creation, connection pooling, and provides helper methods
/// for executing queries against the local application database.
/// </summary>
public sealed class BepozToolkitDb : IDisposable
{
    private readonly string _connectionString;
    private readonly ILogger _logger;
    private readonly SemaphoreSlim _semaphore = new(1, 1);
    private bool _disposed;

    public BepozToolkitDb(ILogger logger)
    {
        _logger = logger;
        var dbPath = Constants.DatabasePath;
        _connectionString = $"Data Source={dbPath}";
    }

    /// <summary>
    /// Initializes the database by creating all required tables if they do not already exist.
    /// Must be called once at application startup before any other database operations.
    /// </summary>
    public async Task InitializeAsync()
    {
        _logger.Information("Initializing database at {DatabasePath}", Constants.DatabasePath);

        // Ensure the directory exists
        var directory = Path.GetDirectoryName(Constants.DatabasePath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync();

        // Enable WAL mode for better concurrent read/write performance
        await using (var walCmd = connection.CreateCommand())
        {
            walCmd.CommandText = "PRAGMA journal_mode=WAL;";
            await walCmd.ExecuteNonQueryAsync();
        }

        // Enable foreign keys
        await using (var fkCmd = connection.CreateCommand())
        {
            fkCmd.CommandText = "PRAGMA foreign_keys=ON;";
            await fkCmd.ExecuteNonQueryAsync();
        }

        var tablesSql = GetCreateTablesSql();
        await using var command = connection.CreateCommand();
        command.CommandText = tablesSql;
        await command.ExecuteNonQueryAsync();

        _logger.Information("Database initialization complete");
    }

    /// <summary>
    /// Creates a new SQLite connection. Callers are responsible for opening and disposing.
    /// </summary>
    public SqliteConnection CreateConnection()
    {
        return new SqliteConnection(_connectionString);
    }

    /// <summary>
    /// Executes a non-query SQL command (INSERT, UPDATE, DELETE) and returns the number of rows affected.
    /// </summary>
    public async Task<int> ExecuteNonQueryAsync(string sql, params SqliteParameter[] parameters)
    {
        await _semaphore.WaitAsync();
        try
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = sql;
            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }
            return await command.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Error executing non-query: {Sql}", sql);
            throw;
        }
        finally
        {
            _semaphore.Release();
        }
    }

    /// <summary>
    /// Executes a scalar SQL query and returns the first column of the first row.
    /// </summary>
    public async Task<object?> ExecuteScalarAsync(string sql, params SqliteParameter[] parameters)
    {
        await _semaphore.WaitAsync();
        try
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = sql;
            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }
            return await command.ExecuteScalarAsync();
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Error executing scalar: {Sql}", sql);
            throw;
        }
        finally
        {
            _semaphore.Release();
        }
    }

    /// <summary>
    /// Executes a SQL query and returns the results via a reader callback.
    /// The callback receives each row as the reader iterates.
    /// </summary>
    public async Task<List<T>> ExecuteReaderAsync<T>(
        string sql,
        Func<SqliteDataReader, T> mapper,
        params SqliteParameter[] parameters)
    {
        await _semaphore.WaitAsync();
        try
        {
            var results = new List<T>();
            await using var connection = CreateConnection();
            await connection.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = sql;
            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                results.Add(mapper(reader));
            }
            return results;
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Error executing reader: {Sql}", sql);
            throw;
        }
        finally
        {
            _semaphore.Release();
        }
    }

    /// <summary>
    /// Executes multiple SQL statements inside a single transaction for atomicity.
    /// </summary>
    public async Task ExecuteInTransactionAsync(Func<SqliteConnection, SqliteTransaction, Task> action)
    {
        await _semaphore.WaitAsync();
        try
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync();
            await using var transaction = connection.BeginTransaction();
            try
            {
                await action(connection, transaction);
                await transaction.CommitAsync();
            }
            catch
            {
                await transaction.RollbackAsync();
                throw;
            }
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Error executing transaction");
            throw;
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private static string GetCreateTablesSql()
    {
        return """
            CREATE TABLE IF NOT EXISTS Settings (
                Key         TEXT PRIMARY KEY NOT NULL,
                Value       TEXT NOT NULL,
                UpdatedAt   TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS UsageStatistics (
                Id              INTEGER PRIMARY KEY AUTOINCREMENT,
                ToolId          TEXT    NOT NULL,
                ToolName        TEXT    NOT NULL,
                ExecutionCount  INTEGER NOT NULL DEFAULT 0,
                SuccessCount    INTEGER NOT NULL DEFAULT 0,
                FailureCount    INTEGER NOT NULL DEFAULT 0,
                TotalDurationMs INTEGER NOT NULL DEFAULT 0,
                LastExecutedAt  TEXT    NOT NULL DEFAULT (datetime('now')),
                CreatedAt       TEXT    NOT NULL DEFAULT (datetime('now'))
            );

            CREATE INDEX IF NOT EXISTS IX_UsageStatistics_ToolId
                ON UsageStatistics(ToolId);

            CREATE INDEX IF NOT EXISTS IX_UsageStatistics_LastExecutedAt
                ON UsageStatistics(LastExecutedAt);

            CREATE TABLE IF NOT EXISTS CacheMetadata (
                RelativePath    TEXT PRIMARY KEY NOT NULL,
                LocalPath       TEXT    NOT NULL,
                Sha256Hash      TEXT    NOT NULL,
                CachedAt        TEXT    NOT NULL DEFAULT (datetime('now')),
                FileSizeBytes   INTEGER NOT NULL DEFAULT 0,
                ExpiresAt       TEXT    NOT NULL
            );

            CREATE TABLE IF NOT EXISTS SavedConnections (
                Id                  TEXT PRIMARY KEY NOT NULL,
                Name                TEXT NOT NULL,
                Server              TEXT NOT NULL,
                DatabaseName        TEXT NOT NULL,
                AuthType            TEXT NOT NULL DEFAULT 'Windows',
                Username            TEXT NOT NULL DEFAULT '',
                EncryptedPassword   BLOB NOT NULL DEFAULT X'',
                LastUsedAt          TEXT NOT NULL DEFAULT (datetime('now')),
                CreatedAt           TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS ToolParameters (
                Id          INTEGER PRIMARY KEY AUTOINCREMENT,
                ToolId      TEXT NOT NULL,
                Name        TEXT NOT NULL,
                Value       TEXT NOT NULL DEFAULT '',
                SavedAt     TEXT NOT NULL DEFAULT (datetime('now')),
                UNIQUE(ToolId, Name)
            );

            CREATE INDEX IF NOT EXISTS IX_ToolParameters_ToolId
                ON ToolParameters(ToolId);

            CREATE TABLE IF NOT EXISTS ExecutionHistory (
                Id          INTEGER PRIMARY KEY AUTOINCREMENT,
                ToolId      TEXT    NOT NULL,
                ToolName    TEXT    NOT NULL,
                ExecutedAt  TEXT    NOT NULL DEFAULT (datetime('now')),
                DurationMs  INTEGER NOT NULL DEFAULT 0,
                Success     INTEGER NOT NULL DEFAULT 0,
                FullOutput  TEXT    NOT NULL DEFAULT '',
                ErrorOutput TEXT    NOT NULL DEFAULT '',
                Parameters  TEXT    NOT NULL DEFAULT '{}',
                ConnectionId TEXT
            );

            CREATE INDEX IF NOT EXISTS IX_ExecutionHistory_ToolId
                ON ExecutionHistory(ToolId);

            CREATE INDEX IF NOT EXISTS IX_ExecutionHistory_ExecutedAt
                ON ExecutionHistory(ExecutedAt);

            CREATE TABLE IF NOT EXISTS Logs (
                Id          INTEGER PRIMARY KEY AUTOINCREMENT,
                Timestamp   TEXT    NOT NULL DEFAULT (datetime('now')),
                Level       TEXT    NOT NULL DEFAULT 'Information',
                Message     TEXT    NOT NULL,
                Exception   TEXT,
                Properties  TEXT
            );

            CREATE INDEX IF NOT EXISTS IX_Logs_Timestamp
                ON Logs(Timestamp);

            CREATE INDEX IF NOT EXISTS IX_Logs_Level
                ON Logs(Level);
            """;
    }

    /// <summary>
    /// Executes a scalar SQL query synchronously with semaphore protection.
    /// Used for synchronous callers that cannot use async (e.g., IsCacheStale).
    /// </summary>
    public object? ExecuteScalarSync(string sql, params SqliteParameter[] parameters)
    {
        _semaphore.Wait();
        try
        {
            using var connection = CreateConnection();
            connection.Open();
            using var command = connection.CreateCommand();
            command.CommandText = sql;
            foreach (var param in parameters)
            {
                command.Parameters.Add(param);
            }
            return command.ExecuteScalar();
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Error executing sync scalar: {Sql}", sql);
            throw;
        }
        finally
        {
            _semaphore.Release();
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _semaphore.Dispose();
        _disposed = true;
    }
}
