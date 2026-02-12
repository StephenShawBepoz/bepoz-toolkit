using System.Text.Json;
using BepozToolkit.Core.Database;
using BepozToolkit.Core.Models;
using Microsoft.Data.Sqlite;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages persistent application settings stored as key-value pairs in the SQLite Settings table.
/// Each property of the <see cref="Settings"/> model is stored as a separate row for granular access.
/// </summary>
public sealed class SettingsService : ISettingsService
{
    private readonly BepozToolkitDb _db;
    private readonly ILogger _logger;
    private Settings? _cachedSettings;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public SettingsService(BepozToolkitDb db, ILogger logger)
    {
        _db = db;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<Settings> LoadSettingsAsync()
    {
        _logger.Debug("Loading settings from database");

        try
        {
            var rows = await _db.ExecuteReaderAsync(
                "SELECT Key, Value FROM Settings;",
                reader => new KeyValuePair<string, string>(
                    reader.GetString(0),
                    reader.GetString(1)));

            var dict = rows.ToDictionary(kv => kv.Key, kv => kv.Value, StringComparer.OrdinalIgnoreCase);
            var settings = new Settings();

            if (dict.TryGetValue(nameof(Settings.Theme), out var theme))
                settings.Theme = theme;

            if (dict.TryGetValue(nameof(Settings.MinimizeToSystemTray), out var minimize))
                settings.MinimizeToSystemTray = bool.TryParse(minimize, out var m) && m;

            if (dict.TryGetValue(nameof(Settings.EnableAnimations), out var animations))
                settings.EnableAnimations = bool.TryParse(animations, out var a) && a;

            if (dict.TryGetValue(nameof(Settings.EnableToastNotifications), out var toast))
                settings.EnableToastNotifications = bool.TryParse(toast, out var t) && t;

            if (dict.TryGetValue(nameof(Settings.WindowLeft), out var left))
                settings.WindowLeft = double.TryParse(left, out var l) ? l : 100;

            if (dict.TryGetValue(nameof(Settings.WindowTop), out var top))
                settings.WindowTop = double.TryParse(top, out var tp) ? tp : 100;

            if (dict.TryGetValue(nameof(Settings.WindowWidth), out var width))
                settings.WindowWidth = double.TryParse(width, out var w) ? w : 1280;

            if (dict.TryGetValue(nameof(Settings.WindowHeight), out var height))
                settings.WindowHeight = double.TryParse(height, out var h) ? h : 800;

            if (dict.TryGetValue(nameof(Settings.FavoriteToolIds), out var favs))
            {
                var list = JsonSerializer.Deserialize<List<string>>(favs, JsonOptions);
                if (list is not null) settings.FavoriteToolIds = list;
            }

            if (dict.TryGetValue(nameof(Settings.PinnedToolIds), out var pinned))
            {
                var list = JsonSerializer.Deserialize<List<string>>(pinned, JsonOptions);
                if (list is not null) settings.PinnedToolIds = list;
            }

            if (dict.TryGetValue(nameof(Settings.LastUsedConnectionId), out var connId))
                settings.LastUsedConnectionId = string.IsNullOrEmpty(connId) ? null : connId;

            _cachedSettings = settings;
            _logger.Information("Settings loaded successfully (Theme={Theme})", settings.Theme);
            return settings;
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Failed to load settings, returning defaults");
            var defaults = new Settings();
            _cachedSettings = defaults;
            return defaults;
        }
    }

    /// <inheritdoc />
    public async Task SaveSettingsAsync(Settings settings)
    {
        _logger.Debug("Saving all settings to database");

        var pairs = new Dictionary<string, string>
        {
            [nameof(Settings.Theme)] = settings.Theme,
            [nameof(Settings.MinimizeToSystemTray)] = settings.MinimizeToSystemTray.ToString(),
            [nameof(Settings.EnableAnimations)] = settings.EnableAnimations.ToString(),
            [nameof(Settings.EnableToastNotifications)] = settings.EnableToastNotifications.ToString(),
            [nameof(Settings.WindowLeft)] = settings.WindowLeft.ToString("F1"),
            [nameof(Settings.WindowTop)] = settings.WindowTop.ToString("F1"),
            [nameof(Settings.WindowWidth)] = settings.WindowWidth.ToString("F1"),
            [nameof(Settings.WindowHeight)] = settings.WindowHeight.ToString("F1"),
            [nameof(Settings.FavoriteToolIds)] = JsonSerializer.Serialize(settings.FavoriteToolIds, JsonOptions),
            [nameof(Settings.PinnedToolIds)] = JsonSerializer.Serialize(settings.PinnedToolIds, JsonOptions),
            [nameof(Settings.LastUsedConnectionId)] = settings.LastUsedConnectionId ?? ""
        };

        await _db.ExecuteInTransactionAsync(async (connection, transaction) =>
        {
            foreach (var (key, value) in pairs)
            {
                await using var cmd = connection.CreateCommand();
                cmd.Transaction = transaction;
                cmd.CommandText = """
                    INSERT INTO Settings (Key, Value, UpdatedAt)
                    VALUES (@Key, @Value, @UpdatedAt)
                    ON CONFLICT(Key) DO UPDATE SET
                        Value = @Value,
                        UpdatedAt = @UpdatedAt;
                    """;
                cmd.Parameters.Add(new SqliteParameter("@Key", key));
                cmd.Parameters.Add(new SqliteParameter("@Value", value));
                cmd.Parameters.Add(new SqliteParameter("@UpdatedAt", DateTime.UtcNow.ToString("o")));
                await cmd.ExecuteNonQueryAsync();
            }
        });

        _cachedSettings = settings;
        _logger.Information("All settings saved successfully");
    }

    /// <inheritdoc />
    public async Task ResetToDefaultsAsync()
    {
        _logger.Information("Resetting all settings to defaults");
        var defaults = new Settings();
        await SaveSettingsAsync(defaults);
    }

    /// <inheritdoc />
    public async Task<T> GetSettingAsync<T>(string key, T defaultValue)
    {
        _logger.Debug("Getting setting: {Key}", key);

        try
        {
            var result = await _db.ExecuteScalarAsync(
                "SELECT Value FROM Settings WHERE Key = @Key;",
                new SqliteParameter("@Key", key));

            if (result is null or DBNull)
                return defaultValue;

            var stringValue = result.ToString()!;

            // Handle primitive types directly
            var targetType = typeof(T);
            if (targetType == typeof(string))
                return (T)(object)stringValue;

            if (targetType == typeof(bool))
                return (T)(object)(bool.TryParse(stringValue, out var b) && b);

            if (targetType == typeof(int))
                return (T)(object)(int.TryParse(stringValue, out var i) ? i : (int)(object)defaultValue!);

            if (targetType == typeof(double))
                return (T)(object)(double.TryParse(stringValue, out var d) ? d : (double)(object)defaultValue!);

            if (targetType == typeof(long))
                return (T)(object)(long.TryParse(stringValue, out var l) ? l : (long)(object)defaultValue!);

            // For complex types, use JSON deserialization
            var deserialized = JsonSerializer.Deserialize<T>(stringValue, JsonOptions);
            return deserialized ?? defaultValue;
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to get setting {Key}, returning default", key);
            return defaultValue;
        }
    }

    /// <inheritdoc />
    public async Task SetSettingAsync<T>(string key, T value)
    {
        _logger.Debug("Setting {Key} to {Value}", key, value);

        string stringValue;
        var targetType = typeof(T);

        if (targetType == typeof(string))
            stringValue = (string)(object)value!;
        else if (targetType == typeof(bool) || targetType == typeof(int)
                 || targetType == typeof(double) || targetType == typeof(long))
            stringValue = value?.ToString() ?? "";
        else
            stringValue = JsonSerializer.Serialize(value, JsonOptions);

        const string sql = """
            INSERT INTO Settings (Key, Value, UpdatedAt)
            VALUES (@Key, @Value, @UpdatedAt)
            ON CONFLICT(Key) DO UPDATE SET
                Value = @Value,
                UpdatedAt = @UpdatedAt;
            """;

        await _db.ExecuteNonQueryAsync(sql,
            new SqliteParameter("@Key", key),
            new SqliteParameter("@Value", stringValue),
            new SqliteParameter("@UpdatedAt", DateTime.UtcNow.ToString("o")));

        // Invalidate the cached settings so next LoadSettingsAsync re-reads from DB
        _cachedSettings = null;
    }
}
