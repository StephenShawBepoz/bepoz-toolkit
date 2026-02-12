using System.Security.Cryptography;
using System.Text;
using BepozToolkit.Core.Database;
using Microsoft.Data.Sqlite;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages the local file cache for downloaded tool scripts and modules.
/// Stores files in <see cref="Constants.CachePath"/> and tracks metadata in the SQLite CacheMetadata table.
/// Provides SHA256 integrity verification and expiration-based cache management.
/// </summary>
public sealed class CacheService : ICacheService
{
    private readonly BepozToolkitDb _db;
    private readonly ILogger _logger;
    private int _cacheExpirationMinutes = Constants.DefaultCacheExpirationMinutes;

    public CacheService(BepozToolkitDb db, ILogger logger)
    {
        _db = db;
        _logger = logger;

        // Ensure the cache directory exists
        Directory.CreateDirectory(Constants.CachePath);
    }

    /// <summary>
    /// Sets the cache expiration period. Called by SettingsService when settings are loaded.
    /// </summary>
    public void SetCacheExpiration(int minutes)
    {
        _cacheExpirationMinutes = minutes > 0 ? minutes : Constants.DefaultCacheExpirationMinutes;
    }

    /// <inheritdoc />
    public string? GetCachedFilePath(string relativePath)
    {
        var localPath = BuildLocalPath(relativePath);
        return File.Exists(localPath) ? localPath : null;
    }

    /// <inheritdoc />
    public async Task CacheFileAsync(string relativePath, string content)
    {
        _logger.Debug("Caching file: {RelativePath}", relativePath);

        var localPath = BuildLocalPath(relativePath);
        var directory = Path.GetDirectoryName(localPath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        // Write file to disk
        await File.WriteAllTextAsync(localPath, content, Encoding.UTF8);

        // Compute SHA256 hash
        var hash = ComputeSha256(content);
        var fileSize = new FileInfo(localPath).Length;
        var cachedAt = DateTime.UtcNow;
        var expiresAt = cachedAt.AddMinutes(_cacheExpirationMinutes);

        // Upsert metadata in SQLite
        const string sql = """
            INSERT INTO CacheMetadata (RelativePath, LocalPath, Sha256Hash, CachedAt, FileSizeBytes, ExpiresAt)
            VALUES (@RelativePath, @LocalPath, @Sha256Hash, @CachedAt, @FileSizeBytes, @ExpiresAt)
            ON CONFLICT(RelativePath) DO UPDATE SET
                LocalPath = @LocalPath,
                Sha256Hash = @Sha256Hash,
                CachedAt = @CachedAt,
                FileSizeBytes = @FileSizeBytes,
                ExpiresAt = @ExpiresAt;
            """;

        await _db.ExecuteNonQueryAsync(sql,
            new SqliteParameter("@RelativePath", relativePath),
            new SqliteParameter("@LocalPath", localPath),
            new SqliteParameter("@Sha256Hash", hash),
            new SqliteParameter("@CachedAt", cachedAt.ToString("o")),
            new SqliteParameter("@FileSizeBytes", fileSize),
            new SqliteParameter("@ExpiresAt", expiresAt.ToString("o")));

        _logger.Debug("File cached: {RelativePath} ({Size} bytes, hash: {Hash})",
            relativePath, fileSize, hash[..12]);
    }

    /// <inheritdoc />
    public bool IsCached(string relativePath)
    {
        var localPath = BuildLocalPath(relativePath);
        return File.Exists(localPath);
    }

    /// <inheritdoc />
    public bool IsCacheStale(string relativePath)
    {
        if (!IsCached(relativePath))
            return true;

        try
        {
            // Check expiration from metadata synchronously via a blocking call
            var expiresAt = GetExpirationSync(relativePath);
            if (expiresAt is null)
                return true;

            return DateTime.UtcNow > expiresAt.Value;
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Error checking cache staleness for {RelativePath}, treating as stale", relativePath);
            return true;
        }
    }

    /// <inheritdoc />
    public async Task ClearCacheAsync()
    {
        _logger.Information("Clearing entire cache directory");

        // Delete all files from cache directory
        if (Directory.Exists(Constants.CachePath))
        {
            foreach (var file in Directory.GetFiles(Constants.CachePath, "*", SearchOption.AllDirectories))
            {
                try
                {
                    File.Delete(file);
                }
                catch (Exception ex)
                {
                    _logger.Warning(ex, "Failed to delete cached file: {File}", file);
                }
            }

            // Clean up empty subdirectories
            foreach (var dir in Directory.GetDirectories(Constants.CachePath, "*", SearchOption.AllDirectories)
                         .OrderByDescending(d => d.Length))
            {
                try
                {
                    if (Directory.GetFileSystemEntries(dir).Length == 0)
                        Directory.Delete(dir);
                }
                catch (Exception ex)
                {
                    _logger.Warning(ex, "Failed to delete empty cache directory: {Dir}", dir);
                }
            }
        }

        // Clear all metadata from the database
        await _db.ExecuteNonQueryAsync("DELETE FROM CacheMetadata;");

        _logger.Information("Cache cleared successfully");
    }

    /// <inheritdoc />
    public async Task CleanExpiredCacheAsync()
    {
        _logger.Information("Cleaning expired cache entries");

        var now = DateTime.UtcNow.ToString("o");

        // Get expired entries
        var expired = await _db.ExecuteReaderAsync(
            "SELECT RelativePath, LocalPath FROM CacheMetadata WHERE ExpiresAt < @Now;",
            reader => new
            {
                RelativePath = reader.GetString(0),
                LocalPath = reader.GetString(1)
            },
            new SqliteParameter("@Now", now));

        foreach (var entry in expired)
        {
            try
            {
                if (File.Exists(entry.LocalPath))
                    File.Delete(entry.LocalPath);
            }
            catch (Exception ex)
            {
                _logger.Warning(ex, "Failed to delete expired cache file: {Path}", entry.LocalPath);
            }
        }

        // Remove expired metadata
        await _db.ExecuteNonQueryAsync(
            "DELETE FROM CacheMetadata WHERE ExpiresAt < @Now;",
            new SqliteParameter("@Now", now));

        _logger.Information("Cleaned {Count} expired cache entries", expired.Count);
    }

    /// <inheritdoc />
    public long GetCacheSizeBytes()
    {
        if (!Directory.Exists(Constants.CachePath))
            return 0;

        try
        {
            return Directory.GetFiles(Constants.CachePath, "*", SearchOption.AllDirectories)
                .Sum(f => new FileInfo(f).Length);
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Error calculating cache size");
            return 0;
        }
    }

    /// <inheritdoc />
    public int GetCacheFileCount()
    {
        if (!Directory.Exists(Constants.CachePath))
            return 0;

        try
        {
            return Directory.GetFiles(Constants.CachePath, "*", SearchOption.AllDirectories).Length;
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Error counting cache files");
            return 0;
        }
    }

    /// <inheritdoc />
    public async Task<bool> VerifyIntegrityAsync(string relativePath)
    {
        _logger.Debug("Verifying integrity of cached file: {RelativePath}", relativePath);

        var localPath = BuildLocalPath(relativePath);
        if (!File.Exists(localPath))
        {
            _logger.Warning("Cached file not found for integrity check: {RelativePath}", relativePath);
            return false;
        }

        // Get stored hash from metadata
        var storedHash = await _db.ExecuteScalarAsync(
            "SELECT Sha256Hash FROM CacheMetadata WHERE RelativePath = @RelativePath;",
            new SqliteParameter("@RelativePath", relativePath));

        if (storedHash is null or DBNull)
        {
            _logger.Warning("No metadata found for cached file: {RelativePath}", relativePath);
            return false;
        }

        // Compute current hash of the file on disk
        var content = await File.ReadAllTextAsync(localPath, Encoding.UTF8);
        var currentHash = ComputeSha256(content);

        var isValid = string.Equals(currentHash, storedHash.ToString(), StringComparison.OrdinalIgnoreCase);

        if (!isValid)
        {
            _logger.Warning("Integrity check failed for {RelativePath}: stored={StoredHash}, computed={CurrentHash}",
                relativePath, storedHash, currentHash);
        }
        else
        {
            _logger.Debug("Integrity check passed for {RelativePath}", relativePath);
        }

        return isValid;
    }

    private static string BuildLocalPath(string relativePath)
    {
        // Normalize path separators and combine with cache root
        var normalized = relativePath.Replace('/', Path.DirectorySeparatorChar)
                                      .Replace('\\', Path.DirectorySeparatorChar);
        return Path.Combine(Constants.CachePath, normalized);
    }

    private static string ComputeSha256(string content)
    {
        var bytes = Encoding.UTF8.GetBytes(content);
        var hashBytes = SHA256.HashData(bytes);
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }

    private DateTime? GetExpirationSync(string relativePath)
    {
        // Use semaphore-protected synchronous query for thread safety
        var result = _db.ExecuteScalarSync(
            "SELECT ExpiresAt FROM CacheMetadata WHERE RelativePath = @RelativePath;",
            new SqliteParameter("@RelativePath", relativePath));

        if (result is null or DBNull)
            return null;

        return DateTime.TryParse(result.ToString(), out var dt) ? dt : null;
    }
}
