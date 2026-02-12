using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Abstracts the PowerShell execution environment, allowing tool scripts to be run,
/// monitored, and cancelled from the UI layer.
/// </summary>
public interface IPowerShellHost
{
    /// <summary>
    /// Executes a PowerShell script file with optional parameters and real-time output streaming.
    /// </summary>
    /// <param name="scriptPath">The absolute path to the <c>.ps1</c> script file.</param>
    /// <param name="parameters">Optional dictionary of parameter names and values to pass to the script.</param>
    /// <param name="outputCallback">Optional callback invoked for each line of standard output.</param>
    /// <param name="errorCallback">Optional callback invoked for each line of error output.</param>
    /// <param name="progressCallback">Optional callback invoked with progress percentage (0-100).</param>
    /// <returns>A <see cref="ToolExecutionResult"/> containing the outcome, output, and timing information.</returns>
    Task<ToolExecutionResult> ExecuteScriptAsync(
        string scriptPath,
        Dictionary<string, object>? parameters,
        Action<string>? outputCallback,
        Action<string>? errorCallback,
        Action<int>? progressCallback);

    /// <summary>
    /// Requests cancellation of the currently running PowerShell script, if any.
    /// </summary>
    void StopExecution();

    /// <summary>
    /// Determines whether the current process is running with elevated (Administrator) privileges.
    /// </summary>
    /// <returns><c>true</c> if the process has administrator rights; otherwise <c>false</c>.</returns>
    bool IsRunningAsAdmin();

    /// <summary>
    /// Restarts the application with elevated (Administrator) privileges via a UAC prompt.
    /// </summary>
    void RestartAsAdmin();

    /// <summary>
    /// Verifies that a PowerShell module can be loaded without errors.
    /// </summary>
    /// <param name="modulePath">The absolute path to the <c>.psm1</c> module file.</param>
    /// <returns><c>true</c> if the module loaded successfully; otherwise <c>false</c>.</returns>
    Task<bool> TestModuleLoadingAsync(string modulePath);

    /// <summary>
    /// Returns the version of the PowerShell runtime being used.
    /// </summary>
    /// <returns>A version string (e.g. <c>7.4.1</c>).</returns>
    string GetPowerShellVersion();
}
