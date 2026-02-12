using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Runs pre-flight validation checks before a tool is executed, verifying prerequisites
/// such as admin rights, database connectivity, and required dependencies.
/// </summary>
public interface IPreFlightService
{
    /// <summary>
    /// Executes all applicable pre-flight checks for a tool and its associated connection.
    /// </summary>
    /// <param name="tool">The <see cref="Tool"/> about to be executed.</param>
    /// <param name="connection">
    /// The <see cref="SavedConnection"/> to validate against, or <c>null</c> if the tool
    /// does not require a database connection.
    /// </param>
    /// <returns>
    /// A list of <see cref="PreFlightCheckResult"/> entries describing each check performed
    /// and whether it passed or failed.
    /// </returns>
    Task<List<PreFlightCheckResult>> RunPreFlightChecksAsync(Tool tool, SavedConnection? connection);
}
