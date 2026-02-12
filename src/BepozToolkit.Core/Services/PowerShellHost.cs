using System.Diagnostics;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Security.Principal;
using System.Text;
using BepozToolkit.Core.Models;
using Serilog;

namespace BepozToolkit.Core.Services;

/// <summary>
/// PowerShell execution host that uses System.Management.Automation to create runspaces,
/// execute scripts, and capture output/error streams with real-time callbacks.
/// </summary>
public sealed class PowerShellHost : IPowerShellHost, IDisposable
{
    private readonly ILogger _logger;
    private PowerShell? _currentPowerShell;
    private CancellationTokenSource? _cancellationTokenSource;
    private readonly object _lock = new();
    private bool _disposed;

    public PowerShellHost(ILogger logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<ToolExecutionResult> ExecuteScriptAsync(
        string scriptPath,
        Dictionary<string, object>? parameters,
        Action<string>? outputCallback,
        Action<string>? errorCallback,
        Action<int>? progressCallback)
    {
        _logger.Information("Executing script: {ScriptPath}", scriptPath);

        if (!File.Exists(scriptPath))
        {
            _logger.Error("Script file not found: {ScriptPath}", scriptPath);
            return new ToolExecutionResult
            {
                Success = false,
                ExitCode = -1,
                ErrorOutput = $"Script file not found: {scriptPath}",
                ExecutedAt = DateTime.UtcNow
            };
        }

        var stopwatch = Stopwatch.StartNew();
        var outputBuilder = new StringBuilder();
        var errorBuilder = new StringBuilder();

        lock (_lock)
        {
            _cancellationTokenSource?.Dispose();
            _cancellationTokenSource = new CancellationTokenSource();
        }

        try
        {
            var result = await Task.Run(() =>
            {
                // Create a fresh runspace for each execution for isolation
                var initialState = InitialSessionState.CreateDefault();
                using var runspace = RunspaceFactory.CreateRunspace(initialState);
                runspace.Open();

                using var ps = PowerShell.Create();
                ps.Runspace = runspace;

                lock (_lock)
                {
                    _currentPowerShell = ps;
                }

                // Set the execution policy for this runspace to Bypass
                ps.AddCommand("Set-ExecutionPolicy")
                  .AddParameter("ExecutionPolicy", "Bypass")
                  .AddParameter("Scope", "Process")
                  .AddParameter("Force", true);
                ps.Invoke();
                ps.Commands.Clear();

                // Execute the script file using the call operator for proper path handling
                ps.AddScript($"& '{scriptPath.Replace("'", "''")}'");

                // Add parameters if provided
                if (parameters is not null)
                {
                    foreach (var (key, value) in parameters)
                    {
                        ps.AddParameter(key, value);
                    }
                }

                // Subscribe to output streams
                ps.Streams.Information.DataAdded += (sender, args) =>
                {
                    if (sender is PSDataCollection<InformationRecord> records && args.Index < records.Count)
                    {
                        var message = records[args.Index].MessageData?.ToString() ?? "";
                        outputBuilder.AppendLine(message);
                        outputCallback?.Invoke(message);
                    }
                };

                ps.Streams.Warning.DataAdded += (sender, args) =>
                {
                    if (sender is PSDataCollection<WarningRecord> records && args.Index < records.Count)
                    {
                        var message = $"WARNING: {records[args.Index].Message}";
                        outputBuilder.AppendLine(message);
                        outputCallback?.Invoke(message);
                    }
                };

                ps.Streams.Error.DataAdded += (sender, args) =>
                {
                    if (sender is PSDataCollection<ErrorRecord> records && args.Index < records.Count)
                    {
                        var message = records[args.Index].Exception?.Message
                                      ?? records[args.Index].ToString() ?? "Unknown error";
                        errorBuilder.AppendLine(message);
                        errorCallback?.Invoke(message);
                    }
                };

                ps.Streams.Progress.DataAdded += (sender, args) =>
                {
                    if (sender is PSDataCollection<ProgressRecord> records && args.Index < records.Count)
                    {
                        var percent = records[args.Index].PercentComplete;
                        if (percent >= 0 && percent <= 100)
                        {
                            progressCallback?.Invoke(percent);
                        }
                    }
                };

                ps.Streams.Verbose.DataAdded += (sender, args) =>
                {
                    if (sender is PSDataCollection<VerboseRecord> records && args.Index < records.Count)
                    {
                        var message = $"VERBOSE: {records[args.Index].Message}";
                        outputBuilder.AppendLine(message);
                        outputCallback?.Invoke(message);
                    }
                };

                // Invoke the script
                var output = ps.Invoke();

                // Capture pipeline output
                foreach (var item in output)
                {
                    var line = item?.ToString() ?? "";
                    outputBuilder.AppendLine(line);
                    outputCallback?.Invoke(line);
                }

                var hasErrors = ps.HadErrors || ps.Streams.Error.Count > 0;
                var exitCode = hasErrors ? 1 : 0;

                // Check for $LASTEXITCODE
                ps.Commands.Clear();
                ps.AddScript("$LASTEXITCODE");
                var exitCodeResult = ps.Invoke();
                if (exitCodeResult.Count > 0 && exitCodeResult[0]?.BaseObject is int code)
                {
                    exitCode = code;
                }

                lock (_lock)
                {
                    _currentPowerShell = null;
                }

                runspace.Close();

                return new ToolExecutionResult
                {
                    Success = exitCode == 0 && !hasErrors,
                    ExitCode = exitCode,
                    Output = outputBuilder.ToString(),
                    ErrorOutput = errorBuilder.ToString()
                };
            }, _cancellationTokenSource!.Token);

            stopwatch.Stop();
            result.DurationMs = stopwatch.ElapsedMilliseconds;
            result.ExecutedAt = DateTime.UtcNow;

            _logger.Information("Script completed: {ScriptPath} (exit={ExitCode}, duration={Duration}ms)",
                scriptPath, result.ExitCode, result.DurationMs);

            return result;
        }
        catch (OperationCanceledException)
        {
            stopwatch.Stop();
            _logger.Warning("Script execution was cancelled: {ScriptPath}", scriptPath);

            return new ToolExecutionResult
            {
                Success = false,
                ExitCode = -1,
                Output = outputBuilder.ToString(),
                ErrorOutput = "Execution was cancelled by the user.",
                DurationMs = stopwatch.ElapsedMilliseconds,
                ExecutedAt = DateTime.UtcNow
            };
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.Error(ex, "Script execution failed: {ScriptPath}", scriptPath);

            return new ToolExecutionResult
            {
                Success = false,
                ExitCode = -1,
                Output = outputBuilder.ToString(),
                ErrorOutput = $"{errorBuilder}{Environment.NewLine}{ex.Message}".Trim(),
                DurationMs = stopwatch.ElapsedMilliseconds,
                ExecutedAt = DateTime.UtcNow
            };
        }
        finally
        {
            lock (_lock)
            {
                _currentPowerShell = null;
            }
        }
    }

    /// <inheritdoc />
    public void StopExecution()
    {
        _logger.Information("Stopping PowerShell execution");

        lock (_lock)
        {
            try
            {
                _cancellationTokenSource?.Cancel();
                _currentPowerShell?.Stop();
            }
            catch (Exception ex)
            {
                _logger.Warning(ex, "Error while stopping PowerShell execution");
            }
        }
    }

    /// <inheritdoc />
    public bool IsRunningAsAdmin()
    {
        try
        {
            using var identity = WindowsIdentity.GetCurrent();
            var principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to check admin status");
            return false;
        }
    }

    /// <inheritdoc />
    public void RestartAsAdmin()
    {
        _logger.Information("Restarting application as administrator");

        try
        {
            var exePath = Environment.ProcessPath;
            if (string.IsNullOrEmpty(exePath))
            {
                _logger.Error("Cannot determine process path for admin restart");
                return;
            }

            var psi = new ProcessStartInfo
            {
                FileName = exePath,
                UseShellExecute = true,
                Verb = "runas"
            };

            Process.Start(psi);
            Environment.Exit(0);
        }
        catch (Exception ex)
        {
            _logger.Error(ex, "Failed to restart as administrator");
            throw;
        }
    }

    /// <inheritdoc />
    public async Task<bool> TestModuleLoadingAsync(string modulePath)
    {
        _logger.Debug("Testing module loading: {ModulePath}", modulePath);

        if (!File.Exists(modulePath))
        {
            _logger.Warning("Module file not found: {ModulePath}", modulePath);
            return false;
        }

        try
        {
            return await Task.Run(() =>
            {
                var initialState = InitialSessionState.CreateDefault();
                using var runspace = RunspaceFactory.CreateRunspace(initialState);
                runspace.Open();

                using var ps = PowerShell.Create();
                ps.Runspace = runspace;

                // Set execution policy
                ps.AddCommand("Set-ExecutionPolicy")
                  .AddParameter("ExecutionPolicy", "Bypass")
                  .AddParameter("Scope", "Process")
                  .AddParameter("Force", true);
                ps.Invoke();
                ps.Commands.Clear();

                // Try to import the module
                ps.AddCommand("Import-Module")
                  .AddParameter("Name", modulePath)
                  .AddParameter("ErrorAction", "Stop");
                ps.Invoke();

                var success = !ps.HadErrors && ps.Streams.Error.Count == 0;

                runspace.Close();

                _logger.Debug("Module loading test {Result}: {ModulePath}",
                    success ? "passed" : "failed", modulePath);

                return success;
            });
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Module loading test failed for: {ModulePath}", modulePath);
            return false;
        }
    }

    /// <inheritdoc />
    public string GetPowerShellVersion()
    {
        try
        {
            var initialState = InitialSessionState.CreateDefault();
            using var runspace = RunspaceFactory.CreateRunspace(initialState);
            runspace.Open();

            using var ps = PowerShell.Create();
            ps.Runspace = runspace;
            ps.AddScript("$PSVersionTable.PSVersion.ToString()");
            var result = ps.Invoke();

            runspace.Close();

            if (result.Count > 0)
            {
                var version = result[0]?.ToString() ?? "Unknown";
                _logger.Debug("PowerShell version: {Version}", version);
                return version;
            }

            return "Unknown";
        }
        catch (Exception ex)
        {
            _logger.Warning(ex, "Failed to get PowerShell version");

            // Fallback: try process-based approach
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "pwsh",
                    Arguments = "-NoProfile -Command \"$PSVersionTable.PSVersion.ToString()\"",
                    RedirectStandardOutput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = Process.Start(psi);
                if (process is not null)
                {
                    var output = process.StandardOutput.ReadToEnd().Trim();
                    process.WaitForExit(5000);
                    if (!string.IsNullOrEmpty(output))
                        return output;
                }
            }
            catch
            {
                // Ignored; return fallback
            }

            return "Unknown";
        }
    }

    public void Dispose()
    {
        if (_disposed) return;

        lock (_lock)
        {
            _cancellationTokenSource?.Cancel();
            _cancellationTokenSource?.Dispose();
            _currentPowerShell?.Dispose();
            _currentPowerShell = null;
        }

        _disposed = true;
    }
}
