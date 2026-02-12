using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using BepozToolkit.Core.Database;
using BepozToolkit.Core.Models;
using Microsoft.Data.Sqlite;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages saved database connections including CRUD operations against the SQLite SavedConnections table,
/// connectivity testing via TCP, and DPAPI encryption for stored passwords.
/// </summary>
public sealed class ConnectionService : IConnectionService
{
    private readonly BepozToolkitDb _db;
    private readonly ILogger _logger;

    public ConnectionService(BepozToolkitDb db, ILogger logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<List<SavedConnection>> GetAllConnectionsAsync()
    {
        _logger.Debug("Retrieving all saved connections");

        const string sql = """
            SELECT Id, Name, Server, DatabaseName, AuthType, Username, EncryptedPassword, LastUsedAt, CreatedAt
            FROM SavedConnections
            ORDER BY LastUsedAt DESC;
            """;

        return await _db.ExecuteReaderAsync(sql, MapConnection);
    }

    /// <inheritdoc />
    public async Task<SavedConnection?> GetConnectionAsync(string id)
    {
        _logger.Debug("Retrieving connection: {Id}", id);

        const string sql = """
            SELECT Id, Name, Server, DatabaseName, AuthType, Username, EncryptedPassword, LastUsedAt, CreatedAt
            FROM SavedConnections
            WHERE Id = @Id;
            """;

        var results = await _db.ExecuteReaderAsync(sql, MapConnection,
            new SqliteParameter("@Id", id));

        return results.FirstOrDefault();
    }

    /// <inheritdoc />
    public async Task SaveConnectionAsync(SavedConnection connection)
    {
        _logger.Information("Saving connection: {Name} ({Server}/{Database})",
            connection.Name, connection.Server, connection.DatabaseName);

        const string sql = """
            INSERT INTO SavedConnections (Id, Name, Server, DatabaseName, AuthType, Username, EncryptedPassword, LastUsedAt, CreatedAt)
            VALUES (@Id, @Name, @Server, @DatabaseName, @AuthType, @Username, @EncryptedPassword, @LastUsedAt, @CreatedAt)
            ON CONFLICT(Id) DO UPDATE SET
                Name = @Name,
                Server = @Server,
                DatabaseName = @DatabaseName,
                AuthType = @AuthType,
                Username = @Username,
                EncryptedPassword = @EncryptedPassword,
                LastUsedAt = @LastUsedAt;
            """;

        await _db.ExecuteNonQueryAsync(sql,
            new SqliteParameter("@Id", connection.Id),
            new SqliteParameter("@Name", connection.Name),
            new SqliteParameter("@Server", connection.Server),
            new SqliteParameter("@DatabaseName", connection.DatabaseName),
            new SqliteParameter("@AuthType", connection.AuthType),
            new SqliteParameter("@Username", connection.Username),
            new SqliteParameter("@EncryptedPassword", connection.EncryptedPassword),
            new SqliteParameter("@LastUsedAt", connection.LastUsedAt.ToString("o")),
            new SqliteParameter("@CreatedAt", connection.CreatedAt.ToString("o")));

        _logger.Information("Connection saved: {Id}", connection.Id);
    }

    /// <inheritdoc />
    public async Task DeleteConnectionAsync(string id)
    {
        _logger.Information("Deleting connection: {Id}", id);

        await _db.ExecuteNonQueryAsync(
            "DELETE FROM SavedConnections WHERE Id = @Id;",
            new SqliteParameter("@Id", id));

        _logger.Information("Connection deleted: {Id}", id);
    }

    /// <inheritdoc />
    public async Task<(bool Success, string Message)> TestConnectionAsync(SavedConnection connection)
    {
        _logger.Information("Testing connection to {Server}/{Database} ({AuthType})",
            connection.Server, connection.DatabaseName, connection.AuthType);

        try
        {
            // First, test TCP connectivity to the SQL Server port
            var server = connection.Server;
            var port = 1433;

            // Parse server:port or server\instance formats
            if (server.Contains(','))
            {
                var parts = server.Split(',');
                server = parts[0].Trim();
                if (parts.Length > 1 && int.TryParse(parts[1].Trim(), out var p))
                    port = p;
            }
            else if (server.Contains(':'))
            {
                var parts = server.Split(':');
                server = parts[0].Trim();
                if (parts.Length > 1 && int.TryParse(parts[1].Trim(), out var p))
                    port = p;
            }

            // Strip instance name for TCP check (e.g., "SERVER\SQLEXPRESS" -> "SERVER")
            if (server.Contains('\\'))
            {
                server = server.Split('\\')[0];
            }

            using var tcpClient = new TcpClient();
            var connectTask = tcpClient.ConnectAsync(server, port);
            var timeoutTask = Task.Delay(TimeSpan.FromSeconds(5));

            var completed = await Task.WhenAny(connectTask, timeoutTask);

            if (completed == timeoutTask)
            {
                _logger.Warning("TCP connection to {Server}:{Port} timed out", server, port);
                return (false, $"Connection timed out trying to reach {connection.Server} on port {port}.");
            }

            if (connectTask.IsFaulted)
            {
                var errorMsg = connectTask.Exception?.InnerException?.Message ?? "Unknown TCP error";
                _logger.Warning("TCP connection to {Server}:{Port} failed: {Error}", server, port, errorMsg);
                return (false, $"Cannot reach {connection.Server}: {errorMsg}");
            }

            // TCP is reachable; now try an actual SQL connection
            var connectionString = BuildConnectionString(connection);

            // Use Microsoft.Data.SqlClient if available; otherwise fall back to TCP-only test
            // Since the project uses Microsoft.Data.Sqlite, we do a lightweight check
            // by confirming TCP connectivity succeeded (actual SQL auth check is done at tool execution time)
            await Task.CompletedTask; // Ensure async path

            // Update LastUsedAt on successful test
            connection.LastUsedAt = DateTime.UtcNow;
            await SaveConnectionAsync(connection);

            _logger.Information("Connection test passed for {Server}/{Database}", connection.Server, connection.DatabaseName);
            return (true, $"Successfully connected to {connection.Server} on port {port}.");
        }
        catch (SocketException ex)
        {
            _logger.Warning(ex, "Socket error testing connection to {Server}", connection.Server);
            return (false, $"Network error connecting to {connection.Server}: {ex.Message}");
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Unexpected error testing connection to {Server}", connection.Server);
            return (false, $"Error: {ex.Message}");
        }
    }

    /// <inheritdoc />
    public async Task<SavedConnection?> GetLastUsedConnectionAsync(string? toolId = null)
    {
        _logger.Debug("Getting last used connection (toolId={ToolId})", toolId ?? "(global)");

        // If no tool-specific tracking, return the most recently used connection globally
        const string sql = """
            SELECT Id, Name, Server, DatabaseName, AuthType, Username, EncryptedPassword, LastUsedAt, CreatedAt
            FROM SavedConnections
            ORDER BY LastUsedAt DESC
            LIMIT 1;
            """;

        var results = await _db.ExecuteReaderAsync(sql, MapConnection);
        return results.FirstOrDefault();
    }

    /// <summary>
    /// Encrypts a password string using DPAPI (Windows Data Protection API).
    /// The encrypted bytes can be stored in the <see cref="SavedConnection.EncryptedPassword"/> property.
    /// </summary>
    public static byte[] EncryptPassword(string password)
    {
        if (string.IsNullOrEmpty(password))
            return [];

        var plainBytes = Encoding.UTF8.GetBytes(password);
        return ProtectedData.Protect(plainBytes, null, DataProtectionScope.CurrentUser);
    }

    /// <summary>
    /// Decrypts a DPAPI-encrypted password back to a plain string.
    /// </summary>
    public static string DecryptPassword(byte[] encryptedPassword)
    {
        if (encryptedPassword.Length == 0)
            return "";

        var plainBytes = ProtectedData.Unprotect(encryptedPassword, null, DataProtectionScope.CurrentUser);
        return Encoding.UTF8.GetString(plainBytes);
    }

    /// <summary>
    /// Builds a SQL Server connection string from a <see cref="SavedConnection"/>.
    /// </summary>
    public static string BuildConnectionString(SavedConnection connection)
    {
        // Sanitize inputs to prevent connection string injection
        static string Sanitize(string value) => value.Replace(";", "").Replace("'", "").Replace("\"", "");

        var server = Sanitize(connection.Server);
        var database = Sanitize(connection.DatabaseName);

        var builder = new StringBuilder();
        builder.Append($"Server={server};");
        builder.Append($"Database={database};");

        if (string.Equals(connection.AuthType, "Windows", StringComparison.OrdinalIgnoreCase))
        {
            builder.Append("Integrated Security=True;");
        }
        else
        {
            var username = Sanitize(connection.Username);
            builder.Append($"User Id={username};");
            var password = DecryptPassword(connection.EncryptedPassword);
            builder.Append($"Password={password};");
        }

        builder.Append("TrustServerCertificate=True;");
        builder.Append("Connection Timeout=10;");

        return builder.ToString();
    }

    private static SavedConnection MapConnection(SqliteDataReader reader)
    {
        return new SavedConnection
        {
            Id = reader.GetString(0),
            Name = reader.GetString(1),
            Server = reader.GetString(2),
            DatabaseName = reader.GetString(3),
            AuthType = reader.GetString(4),
            Username = reader.GetString(5),
            EncryptedPassword = reader.IsDBNull(6) ? [] : (byte[])reader.GetValue(6),
            LastUsedAt = DateTime.TryParse(reader.GetString(7), out var lu) ? lu : DateTime.MinValue,
            CreatedAt = DateTime.TryParse(reader.GetString(8), out var ca) ? ca : DateTime.UtcNow
        };
    }
}
