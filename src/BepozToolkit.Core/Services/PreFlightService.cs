using System.Diagnostics;
using System.Net.Sockets;
using System.Security.Principal;
using BepozToolkit.Core.Models;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Runs pre-flight validation checks before a tool is executed, verifying prerequisites
/// such as admin rights, database connectivity, PowerShell runtime, and required dependencies.
/// </summary>
public sealed class PreFlightService : IPreFlightService
{
    private readonly ICacheService _cacheService;
    private readonly ILogger _logger;

    public PreFlightService(ICacheService cacheService, ILogger logger)
    {
        _cacheService = cacheService;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<List<PreFlightCheckResult>> RunPreFlightChecksAsync(Tool tool, SavedConnection? connection)
    {
        _logger.Information("Running pre-flight checks for tool: {ToolId} ({ToolName})", tool.Id, tool.Name);

        var results = new List<PreFlightCheckResult>();

        // 1. Check admin status if the tool requires it
        if (tool.RequiresAdmin)
        {
            results.Add(CheckAdminStatus());
        }

        // 2. Check database connectivity if the tool requires it
        if (tool.RequiresDatabase)
        {
            results.Add(await CheckDatabaseConnectivityAsync(connection));
        }

        // 3. Check PowerShell runtime availability
        results.Add(CheckPowerShellRuntime());

        // 4. Check that all dependencies are available in the cache
        if (tool.Dependencies.Count > 0)
        {
            results.Add(CheckDependencies(tool));
        }

        // 5. Check that the tool script itself is cached
        results.Add(CheckToolCached(tool));

        var passed = results.Count(r => r.Passed);
        var failed = results.Count(r => !r.Passed);
        _logger.Information("Pre-flight checks complete: {Passed} passed, {Failed} failed", passed, failed);

        return results;
    }

    private PreFlightCheckResult CheckAdminStatus()
    {
        _logger.Debug("Checking administrator status");

        try
        {
            using var identity = WindowsIdentity.GetCurrent();
            var principal = new WindowsPrincipal(identity);
            var isAdmin = principal.IsInRole(WindowsBuiltInRole.Administrator);

            if (isAdmin)
            {
                return new PreFlightCheckResult
                {
                    CheckName = "Administrator Privileges",
                    Passed = true,
                    Message = "Running with administrator privileges."
                };
            }

            return new PreFlightCheckResult
            {
                CheckName = "Administrator Privileges",
                Passed = false,
                Message = "This tool requires administrator privileges. Please restart as administrator.",
                ActionLabel = "Restart as Admin",
                ActionType = PreFlightActionType.RestartAsAdmin
            };
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to check admin status");
            return new PreFlightCheckResult
            {
                CheckName = "Administrator Privileges",
                Passed = false,
                Message = $"Unable to determine admin status: {ex.Message}",
                ActionLabel = "Restart as Admin",
                ActionType = PreFlightActionType.RestartAsAdmin
            };
        }
    }

    private async Task<PreFlightCheckResult> CheckDatabaseConnectivityAsync(SavedConnection? connection)
    {
        _logger.Debug("Checking database connectivity");

        if (connection is null)
        {
            return new PreFlightCheckResult
            {
                CheckName = "Database Connection",
                Passed = false,
                Message = "No database connection selected. Please select or create a connection.",
                ActionLabel = "Configure Connection",
                ActionType = PreFlightActionType.RetryConnection
            };
        }

        try
        {
            var server = connection.Server;
            var port = 1433;

            // Parse server:port or server,port formats
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

            // Strip instance name for TCP check
            if (server.Contains('\\'))
            {
                server = server.Split('\\')[0];
            }

            using var tcpClient = new TcpClient();
            var connectTask = tcpClient.ConnectAsync(server, port);
            var timeoutTask = Task.Delay(TimeSpan.FromSeconds(5));

            var completed = await Task.WhenAny(connectTask, timeoutTask);

            if (completed == timeoutTask || connectTask.IsFaulted)
            {
                var msg = connectTask.IsFaulted
                    ? connectTask.Exception?.InnerException?.Message ?? "Connection failed"
                    : "Connection timed out";

                return new PreFlightCheckResult
                {
                    CheckName = "Database Connection",
                    Passed = false,
                    Message = $"Cannot reach {connection.Server} on port {port}: {msg}",
                    ActionLabel = "Retry",
                    ActionType = PreFlightActionType.RetryConnection
                };
            }

            return new PreFlightCheckResult
            {
                CheckName = "Database Connection",
                Passed = true,
                Message = $"Successfully connected to {connection.Server} ({connection.DatabaseName})."
            };
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Database connectivity check failed for {Server}", connection.Server);
            return new PreFlightCheckResult
            {
                CheckName = "Database Connection",
                Passed = false,
                Message = $"Connection error: {ex.Message}",
                ActionLabel = "Retry",
                ActionType = PreFlightActionType.RetryConnection
            };
        }
    }

    private PreFlightCheckResult CheckPowerShellRuntime()
    {
        _logger.Debug("Checking PowerShell runtime");

        try
        {
            // Check if pwsh (PowerShell 7+) is available
            var psi = new ProcessStartInfo
            {
                FileName = "pwsh",
                Arguments = "-NoProfile -Command \"$PSVersionTable.PSVersion.ToString()\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process is not null)
            {
                var output = process.StandardOutput.ReadToEnd().Trim();
                process.WaitForExit(5000);

                if (process.ExitCode == 0 && !string.IsNullOrEmpty(output))
                {
                    return new PreFlightCheckResult
                    {
                        CheckName = "PowerShell Runtime",
                        Passed = true,
                        Message = $"PowerShell {output} is available."
                    };
                }
            }
        }
        catch
        {
            // pwsh not found; try Windows PowerShell
        }

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = "-NoProfile -Command \"$PSVersionTable.PSVersion.ToString()\"",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process is not null)
            {
                var output = process.StandardOutput.ReadToEnd().Trim();
                process.WaitForExit(5000);

                if (process.ExitCode == 0 && !string.IsNullOrEmpty(output))
                {
                    return new PreFlightCheckResult
                    {
                        CheckName = "PowerShell Runtime",
                        Passed = true,
                        Message = $"Windows PowerShell {output} is available."
                    };
                }
            }
        }
        catch
        {
            // Windows PowerShell also not found
        }

        return new PreFlightCheckResult
        {
            CheckName = "PowerShell Runtime",
            Passed = false,
            Message = "PowerShell is not available. Please install PowerShell 7 or later."
        };
    }

    private PreFlightCheckResult CheckDependencies(Tool tool)
    {
        _logger.Debug("Checking {Count} dependencies for tool: {ToolId}", tool.Dependencies.Count, tool.Id);

        var missing = new List<string>();
        foreach (var dependency in tool.Dependencies)
        {
            if (!_cacheService.IsCached(dependency))
            {
                missing.Add(dependency);
            }
        }

        if (missing.Count == 0)
        {
            return new PreFlightCheckResult
            {
                CheckName = "Dependencies",
                Passed = true,
                Message = $"All {tool.Dependencies.Count} dependencies are available."
            };
        }

        return new PreFlightCheckResult
        {
            CheckName = "Dependencies",
            Passed = false,
            Message = $"Missing {missing.Count} dependencies: {string.Join(", ", missing)}",
            ActionLabel = "Download Missing",
            ActionType = PreFlightActionType.DownloadDependency
        };
    }

    private PreFlightCheckResult CheckToolCached(Tool tool)
    {
        _logger.Debug("Checking if tool script is cached: {File}", tool.File);

        if (string.IsNullOrEmpty(tool.File))
        {
            return new PreFlightCheckResult
            {
                CheckName = "Tool Script",
                Passed = false,
                Message = "Tool has no script file defined.",
                ActionLabel = "Download",
                ActionType = PreFlightActionType.DownloadDependency
            };
        }

        if (_cacheService.IsCached(tool.File))
        {
            if (_cacheService.IsCacheStale(tool.File))
            {
                return new PreFlightCheckResult
                {
                    CheckName = "Tool Script",
                    Passed = true,
                    Message = "Tool script is cached but may be outdated. Consider refreshing."
                };
            }

            return new PreFlightCheckResult
            {
                CheckName = "Tool Script",
                Passed = true,
                Message = "Tool script is cached and up to date."
            };
        }

        return new PreFlightCheckResult
        {
            CheckName = "Tool Script",
            Passed = false,
            Message = "Tool script is not cached. It needs to be downloaded before execution.",
            ActionLabel = "Download",
            ActionType = PreFlightActionType.DownloadDependency
        };
    }
}
