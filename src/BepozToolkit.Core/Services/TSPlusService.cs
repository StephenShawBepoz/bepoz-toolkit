using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography.X509Certificates;
using Serilog;

namespace BepozToolkit.Core.Services;

public class TSPlusService : ITSPlusService
{
    private readonly ILogger _logger;
    private static readonly HttpClient _httpClient = new() { Timeout = TimeSpan.FromMinutes(30) };

    private const string TSPlusBasePath = @"C:\Program Files (x86)\TSplus";
    private const string AdminToolPath = @"C:\Program Files (x86)\TSplus\Clients\WindowsClient\AdminTool.exe";
    private const string UninstallerPath = @"C:\Program Files (x86)\TSplus\unins000.exe";
    private const string BepozUploadsPath = @"C:\Bepoz\Back Office Cloud - Uploads";
    private const string BackupBasePath = @"C:\Bepoz\TSPlus-Backups";

    private static readonly string[] TSPlusServiceNames =
    [
        "TSplus Gateway", "TSplus Seamless", "TSplus HTML5 Service",
        "TermService", "W3SVC", "TSplus Printer"
    ];

    private static readonly (int Port, string Protocol, string Description)[] TSPlusPorts =
    [
        (3389, "TCP", "RDP"),
        (443, "TCP", "HTTPS / HTML5"),
        (80, "TCP", "HTTP Redirect"),
        (22, "TCP", "SSH Tunnel"),
        (3390, "TCP", "TSPlus Gateway"),
        (8080, "TCP", "TSPlus Web Admin")
    ];

    public TSPlusService(ILogger logger)
    {
        _logger = logger;
    }

    // ======================================================================
    // Installation
    // ======================================================================

    public async Task<string> DownloadInstallerAsync(string url, IProgress<float>? progress = null, CancellationToken cancellationToken = default)
    {
        _logger.Information("Downloading TSPlus installer from {Url}", url);

        var downloadDir = Path.Combine(Constants.CachePath, "TSPlus");
        Directory.CreateDirectory(downloadDir);
        var fileName = Path.GetFileName(new Uri(url).LocalPath);
        if (string.IsNullOrWhiteSpace(fileName)) fileName = "TSPlus-Setup.exe";
        var filePath = Path.Combine(downloadDir, fileName);

        using var response = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();

        var totalBytes = response.Content.Headers.ContentLength ?? -1;
        long bytesRead = 0;

        await using var contentStream = await response.Content.ReadAsStreamAsync(cancellationToken);
        await using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write, FileShare.None, 8192, true);

        var buffer = new byte[8192];
        int read;
        while ((read = await contentStream.ReadAsync(buffer, cancellationToken)) > 0)
        {
            await fileStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            bytesRead += read;

            if (totalBytes > 0)
                progress?.Report((float)bytesRead / totalBytes);
        }

        progress?.Report(1.0f);
        _logger.Information("Downloaded installer to {Path} ({Bytes} bytes)", filePath, bytesRead);
        return filePath;
    }

    public Task<bool> ValidateSignatureAsync(string filePath)
    {
        _logger.Information("Validating Authenticode signature for {Path}", filePath);

        try
        {
            var cert = X509Certificate2.CreateFromSignedFile(filePath);
            if (cert != null)
            {
                var chain = new X509Chain();
                chain.ChainPolicy.RevocationMode = X509RevocationMode.Online;
                var valid = chain.Build(new X509Certificate2(cert));
                _logger.Information("Signature validation result: {Valid}, Subject: {Subject}", valid, cert.Subject);
                return Task.FromResult(valid);
            }
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Signature validation failed for {Path}", filePath);
        }

        return Task.FromResult(false);
    }

    public async Task<bool> RunSilentInstallAsync(string installerPath, Action<string>? outputCallback = null, CancellationToken cancellationToken = default)
    {
        _logger.Information("Running silent install: {Path}", installerPath);
        outputCallback?.Invoke("Starting silent installation...");

        var psi = new ProcessStartInfo
        {
            FileName = installerPath,
            Arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        return await RunProcessAsync(psi, outputCallback, cancellationToken);
    }

    public void CreateDirectoryStructure()
    {
        _logger.Information("Creating Bepoz directory structure");
        Directory.CreateDirectory(BepozUploadsPath);
        _logger.Information("Created directory: {Path}", BepozUploadsPath);
    }

    public Task<bool> CreateLocalGroup(string groupName)
    {
        _logger.Information("Creating local group: {GroupName}", groupName);

        try
        {
            // Use net localgroup command to create the group
            var psi = new ProcessStartInfo
            {
                FileName = "net",
                Arguments = $"localgroup \"{groupName}\" /add",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            process?.WaitForExit(30000);

            if (process?.ExitCode == 0)
            {
                _logger.Information("Local group '{GroupName}' created successfully", groupName);
                return Task.FromResult(true);
            }

            // Exit code 2 means group already exists
            if (process?.ExitCode == 2)
            {
                _logger.Information("Local group '{GroupName}' already exists", groupName);
                return Task.FromResult(true);
            }

            _logger.Warning("Failed to create local group '{GroupName}', exit code: {ExitCode}", groupName, process?.ExitCode);
            return Task.FromResult(false);
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Error creating local group '{GroupName}'", groupName);
            return Task.FromResult(false);
        }
    }

    public bool IsInstalled()
    {
        return File.Exists(AdminToolPath);
    }

    public string? GetInstalledVersion()
    {
        if (!File.Exists(AdminToolPath)) return null;

        try
        {
            var versionInfo = FileVersionInfo.GetVersionInfo(AdminToolPath);
            return versionInfo.FileVersion;
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to read TSPlus version");
            return null;
        }
    }

    // ======================================================================
    // Uninstallation
    // ======================================================================

    public async Task<bool> RunSilentUninstallAsync(Action<string>? outputCallback = null, CancellationToken cancellationToken = default)
    {
        if (!File.Exists(UninstallerPath))
        {
            outputCallback?.Invoke("Uninstaller not found. TSPlus may not be installed.");
            return false;
        }

        _logger.Information("Running silent uninstall");
        outputCallback?.Invoke("Starting silent uninstallation...");

        var psi = new ProcessStartInfo
        {
            FileName = UninstallerPath,
            Arguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        return await RunProcessAsync(psi, outputCallback, cancellationToken);
    }

    public async Task<string> BackupConfigAsync()
    {
        _logger.Information("Backing up TSPlus configuration");
        Directory.CreateDirectory(BackupBasePath);

        var timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
        var backupPath = Path.Combine(BackupBasePath, $"TSPlus-Config-{timestamp}.zip");

        var configPath = Path.Combine(TSPlusBasePath, "UserDesktop");
        var clientPath = Path.Combine(TSPlusBasePath, "Clients");

        await Task.Run(() =>
        {
            using var archive = ZipFile.Open(backupPath, ZipArchiveMode.Create);
            AddDirectoryToZip(archive, configPath, "UserDesktop");
            AddDirectoryToZip(archive, clientPath, "Clients");
        });

        _logger.Information("Configuration backed up to {Path}", backupPath);
        return backupPath;
    }

    // ======================================================================
    // License
    // ======================================================================

    public Task<TSPlusLicenseInfo> GetLicenseStatusAsync()
    {
        _logger.Information("Checking TSPlus license status");

        var info = new TSPlusLicenseInfo();

        if (!IsInstalled())
        {
            info.Status = "Not Installed";
            return Task.FromResult(info);
        }

        try
        {
            var licenseFile = Path.Combine(TSPlusBasePath, "UserDesktop", "license.lic");
            if (File.Exists(licenseFile))
            {
                info.Status = "Licensed";
                info.Edition = "TSPlus Remote Access";
            }
            else
            {
                info.Status = "Trial / Unlicensed";
            }

            var version = GetInstalledVersion();
            if (version != null) info.Edition += $" v{version}";
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Error reading license status");
            info.Status = "Error reading license";
        }

        return Task.FromResult(info);
    }

    public async Task<bool> ApplyLicenseKeyAsync(string key)
    {
        _logger.Information("Applying TSPlus license key");

        if (!IsInstalled()) return false;

        try
        {
            // TSPlus license activation via command-line
            var activatorPath = Path.Combine(TSPlusBasePath, "Clients", "WindowsClient", "AdminTool.exe");
            if (!File.Exists(activatorPath)) return false;

            var psi = new ProcessStartInfo
            {
                FileName = activatorPath,
                Arguments = $"/activate \"{key}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            return await RunProcessAsync(psi, null, CancellationToken.None);
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Failed to apply license key");
            return false;
        }
    }

    public void OpenAdminTool()
    {
        if (!File.Exists(AdminToolPath))
        {
            _logger.Warning("AdminTool.exe not found");
            return;
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = AdminToolPath,
            UseShellExecute = true
        });
    }

    // ======================================================================
    // Services
    // ======================================================================

    public async Task<List<TSPlusServiceInfo>> GetTSPlusServicesAsync()
    {
        var services = new List<TSPlusServiceInfo>();

        foreach (var serviceName in TSPlusServiceNames)
        {
            var info = new TSPlusServiceInfo
            {
                Name = serviceName,
                DisplayName = serviceName,
                Status = "Not Found",
                StartType = "N/A"
            };

            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "sc",
                    Arguments = $"query \"{serviceName}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };

                using var process = Process.Start(psi);
                if (process != null)
                {
                    var output = await process.StandardOutput.ReadToEndAsync();
                    await process.WaitForExitAsync();

                    if (process.ExitCode == 0)
                    {
                        // Parse sc query output for STATE line
                        foreach (var line in output.Split('\n'))
                        {
                            var trimmed = line.Trim();
                            if (trimmed.StartsWith("STATE", StringComparison.OrdinalIgnoreCase))
                            {
                                info.Status = trimmed.Contains("RUNNING") ? "Running"
                                    : trimmed.Contains("STOPPED") ? "Stopped"
                                    : trimmed.Contains("PAUSED") ? "Paused"
                                    : "Unknown";
                            }
                            else if (trimmed.StartsWith("DISPLAY_NAME", StringComparison.OrdinalIgnoreCase))
                            {
                                var parts = trimmed.Split(':', 2);
                                if (parts.Length > 1) info.DisplayName = parts[1].Trim();
                            }
                        }

                        info.StartType = "Automatic";
                    }
                }
            }
            catch
            {
                // Service not found or query failed
            }

            services.Add(info);
        }

        return services;
    }

    public async Task<bool> StartServiceAsync(string serviceName)
    {
        return await ManageServiceAsync(serviceName, "start");
    }

    public async Task<bool> StopServiceAsync(string serviceName)
    {
        return await ManageServiceAsync(serviceName, "stop");
    }

    public async Task<bool> RestartServiceAsync(string serviceName)
    {
        var stopped = await StopServiceAsync(serviceName);
        if (!stopped) return false;
        await Task.Delay(2000);
        return await StartServiceAsync(serviceName);
    }

    // ======================================================================
    // Backup & Restore
    // ======================================================================

    public async Task<TSPlusBackupInfo> CreateBackupAsync(string description)
    {
        _logger.Information("Creating TSPlus backup: {Description}", description);
        Directory.CreateDirectory(BackupBasePath);

        var id = Guid.NewGuid().ToString();
        var timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
        var backupPath = Path.Combine(BackupBasePath, $"TSPlus-Backup-{timestamp}.zip");

        await Task.Run(() =>
        {
            using var archive = ZipFile.Open(backupPath, ZipArchiveMode.Create);
            if (Directory.Exists(TSPlusBasePath))
            {
                AddDirectoryToZip(archive, Path.Combine(TSPlusBasePath, "UserDesktop"), "UserDesktop");
                AddDirectoryToZip(archive, Path.Combine(TSPlusBasePath, "Clients"), "Clients");
            }
        });

        var fileInfo = new FileInfo(backupPath);
        var backup = new TSPlusBackupInfo
        {
            Id = id,
            Description = description,
            CreatedAt = DateTime.UtcNow,
            FilePath = backupPath,
            SizeBytes = fileInfo.Exists ? fileInfo.Length : 0
        };

        _logger.Information("Backup created: {Path} ({Size} bytes)", backupPath, backup.SizeBytes);
        return backup;
    }

    public Task<List<TSPlusBackupInfo>> GetBackupsAsync()
    {
        var backups = new List<TSPlusBackupInfo>();

        if (!Directory.Exists(BackupBasePath))
            return Task.FromResult(backups);

        foreach (var file in Directory.GetFiles(BackupBasePath, "*.zip").OrderByDescending(f => f))
        {
            var fi = new FileInfo(file);
            backups.Add(new TSPlusBackupInfo
            {
                Id = fi.Name,
                Description = Path.GetFileNameWithoutExtension(fi.Name),
                CreatedAt = fi.CreationTimeUtc,
                FilePath = file,
                SizeBytes = fi.Length
            });
        }

        return Task.FromResult(backups);
    }

    public async Task<bool> RestoreBackupAsync(TSPlusBackupInfo backup)
    {
        _logger.Information("Restoring TSPlus backup from {Path}", backup.FilePath);

        if (!File.Exists(backup.FilePath))
        {
            _logger.Warning("Backup file not found: {Path}", backup.FilePath);
            return false;
        }

        try
        {
            await Task.Run(() =>
            {
                ZipFile.ExtractToDirectory(backup.FilePath, TSPlusBasePath, overwriteFiles: true);
            });

            _logger.Information("Backup restored successfully from {Path}", backup.FilePath);
            return true;
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Failed to restore backup from {Path}", backup.FilePath);
            return false;
        }
    }

    // ======================================================================
    // Updates
    // ======================================================================

    public Task<string> GetCurrentVersionAsync()
    {
        var version = GetInstalledVersion() ?? "Not installed";
        return Task.FromResult(version);
    }

    public Task<string> DownloadUpdateAsync(string url, IProgress<float>? progress = null, CancellationToken cancellationToken = default)
    {
        return DownloadInstallerAsync(url, progress, cancellationToken);
    }

    // ======================================================================
    // Ports & Firewall
    // ======================================================================

    public async Task<List<TSPlusPortInfo>> GetPortStatusAsync()
    {
        var ports = new List<TSPlusPortInfo>();

        await Task.Run(() =>
        {
            foreach (var (port, protocol, description) in TSPlusPorts)
            {
                var portInfo = new TSPlusPortInfo
                {
                    Port = port,
                    Protocol = protocol,
                    Description = description,
                    IsListening = IsPortListening(port),
                    HasFirewallRule = CheckFirewallRule(port)
                };
                ports.Add(portInfo);
            }
        });

        return ports;
    }

    public async Task<bool> CreateFirewallRulesAsync()
    {
        _logger.Information("Creating TSPlus firewall rules");
        var allSuccess = true;

        foreach (var (port, protocol, description) in TSPlusPorts)
        {
            try
            {
                var ruleName = $"TSPlus - {description} ({port})";
                var psi = new ProcessStartInfo
                {
                    FileName = "netsh",
                    Arguments = $"advfirewall firewall add rule name=\"{ruleName}\" dir=in action=allow protocol={protocol} localport={port}",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };

                var success = await RunProcessAsync(psi, null, CancellationToken.None);
                if (!success) allSuccess = false;
            }
            catch (Exception ex)
            {
                _logger.Error(ex, "Failed to create firewall rule for port {Port}", port);
                allSuccess = false;
            }
        }

        return allSuccess;
    }

    // ======================================================================
    // Connections
    // ======================================================================

    public async Task<List<TSPlusConnectionInfo>> GetActiveConnectionsAsync()
    {
        var connections = new List<TSPlusConnectionInfo>();

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "query",
                Arguments = "session",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            var output = new List<string>();
            using var process = Process.Start(psi);
            if (process == null) return connections;

            while (!process.StandardOutput.EndOfStream)
            {
                var line = await process.StandardOutput.ReadLineAsync();
                if (line != null) output.Add(line);
            }

            await process.WaitForExitAsync();

            // Parse "query session" output (skip header line)
            foreach (var line in output.Skip(1))
            {
                if (string.IsNullOrWhiteSpace(line)) continue;

                var parts = line.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length >= 3)
                {
                    connections.Add(new TSPlusConnectionInfo
                    {
                        Username = parts[0].TrimStart('>'),
                        SessionId = int.TryParse(parts.Length > 2 ? parts[2] : "0", out var sid) ? sid : 0,
                        State = parts.Length > 3 ? parts[3] : "Unknown",
                        ConnectedSince = DateTime.UtcNow
                    });
                }
            }
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to query active connections");
        }

        return connections;
    }

    // ======================================================================
    // Helpers
    // ======================================================================

    private async Task<bool> RunProcessAsync(ProcessStartInfo psi, Action<string>? outputCallback, CancellationToken cancellationToken)
    {
        using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };
        var tcs = new TaskCompletionSource<int>();

        process.OutputDataReceived += (_, e) =>
        {
            if (e.Data != null) outputCallback?.Invoke(e.Data);
        };

        process.ErrorDataReceived += (_, e) =>
        {
            if (e.Data != null) outputCallback?.Invoke($"[ERROR] {e.Data}");
        };

        process.Exited += (_, _) =>
        {
            tcs.TrySetResult(process.ExitCode);
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        using var registration = cancellationToken.Register(() =>
        {
            try { process.Kill(entireProcessTree: true); } catch { /* best effort */ }
            tcs.TrySetCanceled(cancellationToken);
        });

        var exitCode = await tcs.Task;
        _logger.Information("Process {FileName} exited with code {ExitCode}", psi.FileName, exitCode);
        return exitCode == 0;
    }

    private async Task<bool> ManageServiceAsync(string serviceName, string action)
    {
        _logger.Information("{Action} service: {Service}", action, serviceName);

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "net",
                Arguments = $"{action} \"{serviceName}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            return await RunProcessAsync(psi, null, CancellationToken.None);
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Failed to {Action} service {Service}", action, serviceName);
            return false;
        }
    }

    private static bool IsPortListening(int port)
    {
        try
        {
            var listener = System.Net.NetworkInformation.IPGlobalProperties.GetIPGlobalProperties();
            var endpoints = listener.GetActiveTcpListeners();
            return endpoints.Any(e => e.Port == port);
        }
        catch
        {
            return false;
        }
    }

    private static bool CheckFirewallRule(int port)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "netsh",
                Arguments = "advfirewall firewall show rule name=all dir=in",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process == null) return false;

            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit(10000);
            return output.Contains(port.ToString());
        }
        catch
        {
            return false;
        }
    }

    private static void AddDirectoryToZip(ZipArchive archive, string sourceDir, string entryPrefix)
    {
        if (!Directory.Exists(sourceDir)) return;

        foreach (var file in Directory.GetFiles(sourceDir, "*", SearchOption.AllDirectories))
        {
            var relativePath = Path.GetRelativePath(sourceDir, file);
            var entryName = Path.Combine(entryPrefix, relativePath).Replace('\\', '/');
            archive.CreateEntryFromFile(file, entryName, CompressionLevel.Optimal);
        }
    }
}
