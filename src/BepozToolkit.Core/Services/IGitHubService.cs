using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Provides access to the GitHub repository for fetching manifests, tool scripts, and launcher updates.
/// </summary>
public interface IGitHubService
{
    /// <summary>
    /// Retrieves the tool manifest from the GitHub repository.
    /// </summary>
    /// <param name="forceRefresh">When <c>true</c>, bypasses any cached manifest and fetches directly from GitHub.</param>
    /// <returns>The parsed <see cref="Manifest"/> containing tools, modules, and categories.</returns>
    Task<Manifest> GetManifestAsync(bool forceRefresh = false);

    /// <summary>
    /// Retrieves the raw text content of a file from the GitHub repository.
    /// </summary>
    /// <param name="filePath">The repository-relative path to the file (e.g. <c>tools/SomeTool.ps1</c>).</param>
    /// <returns>The file content as a string.</returns>
    Task<string> GetFileContentAsync(string filePath);

    /// <summary>
    /// Downloads a file from the GitHub repository and writes it to the local cache directory.
    /// </summary>
    /// <param name="filePath">The repository-relative path to the file.</param>
    /// <returns>The absolute local path where the file was cached.</returns>
    Task<string> DownloadAndCacheFileAsync(string filePath);

    /// <summary>
    /// Checks whether a newer version of the Bepoz Toolkit launcher is available on GitHub.
    /// </summary>
    /// <returns>
    /// A tuple indicating whether an update is available, the new version string, and the download URL.
    /// </returns>
    Task<(bool Available, string Version, string DownloadUrl)> CheckForLauncherUpdateAsync();

    /// <summary>
    /// Gets the last-modified date for a file in the GitHub repository.
    /// </summary>
    /// <param name="filePath">The repository-relative path to the file.</param>
    /// <returns>The UTC <see cref="DateTime"/> when the file was last updated.</returns>
    Task<DateTime> GetFileLastUpdatedAsync(string filePath);

    /// <summary>
    /// Tests whether the application can reach the GitHub API.
    /// </summary>
    /// <returns><c>true</c> if the GitHub API is reachable; otherwise <c>false</c>.</returns>
    Task<bool> IsConnectedAsync();
}
