using BepozToolkit.Core.Models;

namespace BepozToolkit.Core.Services;

/// <summary>
/// Manages persistent application settings including theme, window state, favorites, and user preferences.
/// </summary>
public interface ISettingsService
{
    /// <summary>
    /// Loads the full settings object from persistent storage.
    /// </summary>
    /// <returns>The current <see cref="Settings"/> instance.</returns>
    Task<Settings> LoadSettingsAsync();

    /// <summary>
    /// Persists the entire settings object to storage, overwriting previous values.
    /// </summary>
    /// <param name="settings">The <see cref="Settings"/> instance to save.</param>
    Task SaveSettingsAsync(Settings settings);

    /// <summary>
    /// Resets all settings to their default values and persists the result.
    /// </summary>
    Task ResetToDefaultsAsync();

    /// <summary>
    /// Retrieves a single typed setting value by key, returning a default if the key does not exist.
    /// </summary>
    /// <typeparam name="T">The expected type of the setting value.</typeparam>
    /// <param name="key">The unique key identifying the setting.</param>
    /// <param name="defaultValue">The value to return when the key is not found.</param>
    /// <returns>The stored value cast to <typeparamref name="T"/>, or <paramref name="defaultValue"/>.</returns>
    Task<T> GetSettingAsync<T>(string key, T defaultValue);

    /// <summary>
    /// Stores a single typed setting value by key.
    /// </summary>
    /// <typeparam name="T">The type of the setting value.</typeparam>
    /// <param name="key">The unique key identifying the setting.</param>
    /// <param name="value">The value to store.</param>
    Task SetSettingAsync<T>(string key, T value);
}
