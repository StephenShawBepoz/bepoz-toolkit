namespace BepozToolkit.Core.Services;

/// <summary>
/// Provides operations for TSPlus Remote Access installation, management,
/// and configuration including download, validation, services, backup, and monitoring.
/// </summary>
public interface ITSPlusService
{
    // ======================================================================
    // Installation
    // ======================================================================

    /// <summary>
    /// Downloads the TSPlus installer from the specified URL with progress reporting.
    /// </summary>
    /// <param name="url">The download URL for the TSPlus installer.</param>
    /// <param name="progress">Progress reporter (0.0 to 1.0).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The local file path of the downloaded installer.</returns>
    Task<string> DownloadInstallerAsync(string url, IProgress<float>? progress = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Validates the Authenticode digital signature of the specified file.
    /// </summary>
    /// <param name="filePath">Path to the file to validate.</param>
    /// <returns>True if the signature is valid; false otherwise.</returns>
    Task<bool> ValidateSignatureAsync(string filePath);

    /// <summary>
    /// Runs the TSPlus installer silently with /VERYSILENT /SUPPRESSMSGBOXES /NORESTART flags.
    /// </summary>
    /// <param name="installerPath">Path to the downloaded installer executable.</param>
    /// <param name="outputCallback">Callback for streaming install output lines.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True if the installer exited with code 0.</returns>
    Task<bool> RunSilentInstallAsync(string installerPath, Action<string>? outputCallback = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Creates the standard Bepoz directory structure (C:\Bepoz\Back Office Cloud - Uploads).
    /// </summary>
    void CreateDirectoryStructure();

    /// <summary>
    /// Creates a local Windows group for TSPlus users via ADSI.
    /// </summary>
    /// <param name="groupName">The name of the local group to create.</param>
    /// <returns>True if the group was created or already exists.</returns>
    Task<bool> CreateLocalGroup(string groupName);

    /// <summary>
    /// Checks whether TSPlus is currently installed by looking for AdminTool.exe.
    /// </summary>
    bool IsInstalled();

    /// <summary>
    /// Reads the installed version of TSPlus from AdminTool.exe file version info.
    /// </summary>
    /// <returns>The version string, or null if not installed.</returns>
    string? GetInstalledVersion();

    // ======================================================================
    // Uninstallation
    // ======================================================================

    /// <summary>
    /// Runs the TSPlus silent uninstaller.
    /// </summary>
    /// <param name="outputCallback">Callback for streaming uninstall output lines.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True if uninstall completed successfully.</returns>
    Task<bool> RunSilentUninstallAsync(Action<string>? outputCallback = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Backs up the current TSPlus configuration before uninstall.
    /// </summary>
    /// <returns>The path to the backup archive.</returns>
    Task<string> BackupConfigAsync();

    // ======================================================================
    // License
    // ======================================================================

    /// <summary>
    /// Retrieves the current TSPlus license status.
    /// </summary>
    Task<TSPlusLicenseInfo> GetLicenseStatusAsync();

    /// <summary>
    /// Applies a license key to the TSPlus installation.
    /// </summary>
    /// <param name="key">The license key string.</param>
    /// <returns>True if the key was applied successfully.</returns>
    Task<bool> ApplyLicenseKeyAsync(string key);

    /// <summary>
    /// Opens the TSPlus AdminTool application.
    /// </summary>
    void OpenAdminTool();

    // ======================================================================
    // Services
    // ======================================================================

    /// <summary>
    /// Retrieves the status of all TSPlus-related Windows services.
    /// </summary>
    Task<List<TSPlusServiceInfo>> GetTSPlusServicesAsync();

    /// <summary>
    /// Starts a Windows service by name.
    /// </summary>
    Task<bool> StartServiceAsync(string serviceName);

    /// <summary>
    /// Stops a Windows service by name.
    /// </summary>
    Task<bool> StopServiceAsync(string serviceName);

    /// <summary>
    /// Restarts a Windows service by name (stop then start).
    /// </summary>
    Task<bool> RestartServiceAsync(string serviceName);

    // ======================================================================
    // Backup & Restore
    // ======================================================================

    /// <summary>
    /// Creates a backup of the TSPlus configuration with a description.
    /// </summary>
    /// <param name="description">User-provided description for this backup.</param>
    /// <returns>Information about the created backup.</returns>
    Task<TSPlusBackupInfo> CreateBackupAsync(string description);

    /// <summary>
    /// Retrieves a list of all available TSPlus configuration backups.
    /// </summary>
    Task<List<TSPlusBackupInfo>> GetBackupsAsync();

    /// <summary>
    /// Restores a TSPlus configuration from a previous backup.
    /// </summary>
    /// <param name="backup">The backup to restore.</param>
    /// <returns>True if the restore completed successfully.</returns>
    Task<bool> RestoreBackupAsync(TSPlusBackupInfo backup);

    // ======================================================================
    // Updates
    // ======================================================================

    /// <summary>
    /// Gets the currently installed TSPlus version information.
    /// </summary>
    Task<string> GetCurrentVersionAsync();

    /// <summary>
    /// Downloads a TSPlus update from the specified URL with progress reporting.
    /// </summary>
    /// <param name="url">The download URL for the update.</param>
    /// <param name="progress">Progress reporter (0.0 to 1.0).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The local file path of the downloaded update.</returns>
    Task<string> DownloadUpdateAsync(string url, IProgress<float>? progress = null, CancellationToken cancellationToken = default);

    // ======================================================================
    // Ports & Firewall
    // ======================================================================

    /// <summary>
    /// Retrieves the status of TSPlus-related ports (listening, blocked, etc.).
    /// </summary>
    Task<List<TSPlusPortInfo>> GetPortStatusAsync();

    /// <summary>
    /// Creates Windows Firewall rules for all TSPlus ports.
    /// </summary>
    /// <returns>True if all rules were created successfully.</returns>
    Task<bool> CreateFirewallRulesAsync();

    // ======================================================================
    // Connections
    // ======================================================================

    /// <summary>
    /// Retrieves a list of currently active TSPlus remote connections.
    /// </summary>
    Task<List<TSPlusConnectionInfo>> GetActiveConnectionsAsync();
}

// ======================================================================
// Supporting Models
// ======================================================================

public class TSPlusLicenseInfo
{
    public string Status { get; set; } = "Unknown";
    public string Edition { get; set; } = "";
    public string ExpirationDate { get; set; } = "";
    public int MaxUsers { get; set; }
    public string ProductKey { get; set; } = "";
}

public class TSPlusServiceInfo
{
    public string Name { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Status { get; set; } = "Unknown";
    public string StartType { get; set; } = "";
}

public class TSPlusBackupInfo
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Description { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public string FilePath { get; set; } = "";
    public long SizeBytes { get; set; }
}

public class TSPlusPortInfo
{
    public int Port { get; set; }
    public string Protocol { get; set; } = "TCP";
    public string Description { get; set; } = "";
    public bool IsListening { get; set; }
    public bool HasFirewallRule { get; set; }
}

public class TSPlusConnectionInfo
{
    public string Username { get; set; } = "";
    public string ClientAddress { get; set; } = "";
    public int SessionId { get; set; }
    public string State { get; set; } = "";
    public DateTime ConnectedSince { get; set; }
}
