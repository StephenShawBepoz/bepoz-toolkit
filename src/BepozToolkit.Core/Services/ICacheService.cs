namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages the local file cache for downloaded tool scripts and modules,
/// providing offline availability and reducing GitHub API calls.
/// </summary>
public interface ICacheService
{
    /// <summary>
    /// Gets the absolute local path for a cached file, or <c>null</c> if the file is not cached.
    /// </summary>
    /// <param name="relativePath">The repository-relative path to the file.</param>
    /// <returns>The absolute path to the cached file, or <c>null</c> if not present.</returns>
    string? GetCachedFilePath(string relativePath);

    /// <summary>
    /// Writes file content to the local cache directory.
    /// </summary>
    /// <param name="relativePath">The repository-relative path used as the cache key.</param>
    /// <param name="content">The file content to cache.</param>
    Task CacheFileAsync(string relativePath, string content);

    /// <summary>
    /// Determines whether a file exists in the local cache.
    /// </summary>
    /// <param name="relativePath">The repository-relative path to check.</param>
    /// <returns><c>true</c> if the file is cached; otherwise <c>false</c>.</returns>
    bool IsCached(string relativePath);

    /// <summary>
    /// Determines whether a cached file has exceeded its expiration window and should be refreshed.
    /// </summary>
    /// <param name="relativePath">The repository-relative path to check.</param>
    /// <returns><c>true</c> if the cached file is stale or missing; otherwise <c>false</c>.</returns>
    bool IsCacheStale(string relativePath);

    /// <summary>
    /// Removes all files from the local cache directory.
    /// </summary>
    Task ClearCacheAsync();

    /// <summary>
    /// Removes only expired files from the local cache directory.
    /// </summary>
    Task CleanExpiredCacheAsync();

    /// <summary>
    /// Calculates the total size of all files currently stored in the cache.
    /// </summary>
    /// <returns>The total cache size in bytes.</returns>
    long GetCacheSizeBytes();

    /// <summary>
    /// Gets the number of files currently stored in the cache.
    /// </summary>
    /// <returns>The file count.</returns>
    int GetCacheFileCount();

    /// <summary>
    /// Verifies the integrity of a cached file (e.g. by comparing checksums).
    /// </summary>
    /// <param name="relativePath">The repository-relative path of the cached file to verify.</param>
    /// <returns><c>true</c> if the cached file passes integrity checks; otherwise <c>false</c>.</returns>
    Task<bool> VerifyIntegrityAsync(string relativePath);
}
