using System.Text.Json;
using BepozToolkit.Core.Models;
using Octokit;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Provides access to the GitHub repository for fetching manifests, tool scripts, and launcher updates.
/// Uses Octokit.GitHubClient for all GitHub API interactions.
/// </summary>
public sealed class GitHubService : IGitHubService
{
    private readonly GitHubClient _client;
    private readonly ICacheService _cacheService;
    private readonly ILogger _logger;
    private Manifest? _cachedManifest;
    private DateTime _manifestCachedAt = DateTime.MinValue;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public GitHubService(ICacheService cacheService, ILogger logger)
    {
        _cacheService = cacheService;
        _logger = logger;
        _client = new GitHubClient(new ProductHeaderValue(Constants.AppName.Replace(" ", "")))
        {
            // Anonymous access; rate-limited to 60 requests/hour
        };
    }

    /// <inheritdoc />
    public async Task<Manifest> GetManifestAsync(bool forceRefresh = false)
    {
        const string manifestPath = "manifest.json";

        // Return in-memory cached manifest if still fresh (5 minutes)
        if (!forceRefresh
            && _cachedManifest is not null
            && (DateTime.UtcNow - _manifestCachedAt).TotalMinutes < 5)
        {
            _logger.Debug("Returning in-memory cached manifest");
            return _cachedManifest;
        }

        try
        {
            _logger.Information("Fetching manifest from GitHub ({Owner}/{Repo}@{Branch})",
                Constants.GitHubOwner, Constants.GitHubRepo, Constants.GitHubBranch);

            var content = await GetFileContentAsync(manifestPath);
            var manifest = JsonSerializer.Deserialize<Manifest>(content, JsonOptions)
                           ?? throw new InvalidOperationException("Failed to deserialize manifest.json");

            _cachedManifest = manifest;
            _manifestCachedAt = DateTime.UtcNow;

            // Also cache the raw manifest file locally for offline use
            await _cacheService.CacheFileAsync(manifestPath, content);

            _logger.Information("Manifest loaded: {Version} with {ToolCount} tools, {ModuleCount} modules",
                manifest.Version, manifest.Tools.Count, manifest.Modules.Count);

            return manifest;
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to fetch manifest from GitHub, attempting local cache fallback");

            // Try to load from local cache for offline mode
            var cachedPath = _cacheService.GetCachedFilePath(manifestPath);
            if (cachedPath is not null && File.Exists(cachedPath))
            {
                var cachedContent = await File.ReadAllTextAsync(cachedPath);
                var manifest = JsonSerializer.Deserialize<Manifest>(cachedContent, JsonOptions);
                if (manifest is not null)
                {
                    _cachedManifest = manifest;
                    _manifestCachedAt = DateTime.UtcNow;
                    _logger.Information("Loaded manifest from local cache (offline mode)");
                    return manifest;
                }
            }

            // Return empty manifest as last resort
            _logger.Error("No cached manifest available; returning empty manifest");
            return new Manifest();
        }
    }

    /// <inheritdoc />
    public async Task<string> GetFileContentAsync(string filePath)
    {
        _logger.Debug("Fetching file content from GitHub: {FilePath}", filePath);

        try
        {
            var fileContents = await _client.Repository.Content.GetAllContentsByRef(
                Constants.GitHubOwner,
                Constants.GitHubRepo,
                filePath,
                Constants.GitHubBranch);

            if (fileContents.Count == 0)
            {
                throw new FileNotFoundException($"File not found in repository: {filePath}");
            }

            var file = fileContents[0];

            // Content is base64-encoded for files; use the decoded content property
            if (!string.IsNullOrEmpty(file.Content))
            {
                return file.Content;
            }

            // For larger files, download via the download URL
            if (!string.IsNullOrEmpty(file.DownloadUrl))
            {
                using var httpClient = new HttpClient();
                return await httpClient.GetStringAsync(file.DownloadUrl);
            }

            throw new InvalidOperationException($"No content available for file: {filePath}");
        }
        catch (NotFoundException)
        {
            _logger.Error("File not found in GitHub repository: {FilePath}", filePath);
            throw new FileNotFoundException($"File not found in repository: {filePath}");
        }
    }

    /// <inheritdoc />
    public async Task<string> DownloadAndCacheFileAsync(string filePath)
    {
        _logger.Information("Downloading and caching file: {FilePath}", filePath);

        var content = await GetFileContentAsync(filePath);
        await _cacheService.CacheFileAsync(filePath, content);

        var cachedPath = _cacheService.GetCachedFilePath(filePath);
        if (cachedPath is null)
        {
            throw new InvalidOperationException($"File was cached but path could not be resolved: {filePath}");
        }

        _logger.Information("File cached at: {CachedPath}", cachedPath);
        return cachedPath;
    }

    /// <inheritdoc />
    public async Task<(bool Available, string Version, string DownloadUrl)> CheckForLauncherUpdateAsync()
    {
        _logger.Information("Checking for launcher updates on GitHub Releases");

        try
        {
            var releases = await _client.Repository.Release.GetAll(
                Constants.GitHubOwner,
                Constants.GitHubRepo);

            if (releases.Count == 0)
            {
                _logger.Information("No releases found");
                return (false, Constants.AppVersion, "");
            }

            var latest = releases[0]; // Releases are returned newest first
            var latestVersion = latest.TagName.TrimStart('v', 'V');
            var currentVersion = Constants.AppVersion;

            if (Version.TryParse(latestVersion, out var latestVer)
                && Version.TryParse(currentVersion, out var currentVer)
                && latestVer > currentVer)
            {
                // Find the installer asset
                var downloadUrl = latest.HtmlUrl;
                foreach (var asset in latest.Assets)
                {
                    if (asset.Name.EndsWith(".msi", StringComparison.OrdinalIgnoreCase)
                        || asset.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
                        || asset.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
                    {
                        downloadUrl = asset.BrowserDownloadUrl;
                        break;
                    }
                }

                _logger.Information("Update available: {CurrentVersion} -> {LatestVersion}",
                    currentVersion, latestVersion);
                return (true, latestVersion, downloadUrl);
            }

            _logger.Information("Application is up to date ({CurrentVersion})", currentVersion);
            return (false, currentVersion, "");
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to check for launcher updates");
            return (false, Constants.AppVersion, "");
        }
    }

    /// <inheritdoc />
    public async Task<DateTime> GetFileLastUpdatedAsync(string filePath)
    {
        _logger.Debug("Getting last updated date for: {FilePath}", filePath);

        try
        {
            var commits = await _client.Repository.Commit.GetAll(
                Constants.GitHubOwner,
                Constants.GitHubRepo,
                new CommitRequest
                {
                    Path = filePath,
                    Sha = Constants.GitHubBranch
                },
                new ApiOptions { PageCount = 1, PageSize = 1 });

            if (commits.Count > 0)
            {
                var lastCommitDate = commits[0].Commit.Committer.Date.UtcDateTime;
                _logger.Debug("File {FilePath} last updated at {Date}", filePath, lastCommitDate);
                return lastCommitDate;
            }

            _logger.Warning("No commits found for file: {FilePath}", filePath);
            return DateTime.MinValue;
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to get last updated date for: {FilePath}", filePath);
            return DateTime.MinValue;
        }
    }

    /// <inheritdoc />
    public async Task<bool> IsConnectedAsync()
    {
        try
        {
            // Attempt a lightweight API call to check connectivity
            await _client.Repository.Get(Constants.GitHubOwner, Constants.GitHubRepo);
            return true;
        }
        catch (Exception ex)
        {
            _logger.Debug(ex, "GitHub connectivity check failed");
            return false;
        }
    }
}
