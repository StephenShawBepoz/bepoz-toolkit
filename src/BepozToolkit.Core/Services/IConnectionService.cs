using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages saved database connections including CRUD operations, connectivity testing,
/// and tracking the most recently used connection per tool.
/// </summary>
public interface IConnectionService
{
    /// <summary>
    /// Retrieves all saved database connections.
    /// </summary>
    /// <returns>A list of all <see cref="SavedConnection"/> entries.</returns>
    Task<List<SavedConnection>> GetAllConnectionsAsync();

    /// <summary>
    /// Retrieves a single saved connection by its unique identifier.
    /// </summary>
    /// <param name="id">The unique identifier of the connection.</param>
    /// <returns>The matching <see cref="SavedConnection"/>, or <c>null</c> if not found.</returns>
    Task<SavedConnection?> GetConnectionAsync(string id);

    /// <summary>
    /// Creates or updates a saved connection in persistent storage.
    /// </summary>
    /// <param name="connection">The <see cref="SavedConnection"/> to save.</param>
    Task SaveConnectionAsync(SavedConnection connection);

    /// <summary>
    /// Permanently deletes a saved connection by its unique identifier.
    /// </summary>
    /// <param name="id">The unique identifier of the connection to delete.</param>
    Task DeleteConnectionAsync(string id);

    /// <summary>
    /// Tests connectivity to a database server using the provided connection details.
    /// </summary>
    /// <param name="connection">The <see cref="SavedConnection"/> to test.</param>
    /// <returns>A tuple indicating whether the connection succeeded and a descriptive message.</returns>
    Task<(bool Success, string Message)> TestConnectionAsync(SavedConnection connection);

    /// <summary>
    /// Retrieves the most recently used connection, optionally filtered by tool.
    /// </summary>
    /// <param name="toolId">
    /// When specified, returns the last connection used by that particular tool.
    /// When <c>null</c>, returns the globally most recent connection.
    /// </param>
    /// <returns>The last-used <see cref="SavedConnection"/>, or <c>null</c> if none exists.</returns>
    Task<SavedConnection?> GetLastUsedConnectionAsync(string? toolId = null);
}
