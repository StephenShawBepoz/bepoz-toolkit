namespace BepozToolkit.Core;

public static class Constants
{
    public const string AppName = "Bepoz Toolkit";
    public const string AppVersion = "2.0.0";
    public const string GitHubOwner = "StephenShawBepoz";
    public const string GitHubRepo = "bepoz-toolkit";
    public const string GitHubBranch = "main";
    public const string DataFolder = "BepozToolkit";
    public const string DatabaseFileName = "BepozToolkit.db";
    public const string CacheFolder = "Cache";
    public const string LogFolder = "Logs";
    public const int DefaultCacheExpirationMinutes = 60;
    public const int MaxExecutionHistoryEntries = 50;
    public const int HistoryRetentionDays = 30;
    public const int ToastAutoCloseMs = 5000;
    public const int HealthCheckIntervalMs = 300000; // 5 minutes

    public static string AppDataPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        DataFolder);
    public static string DatabasePath => Path.Combine(AppDataPath, DatabaseFileName);
    public static string CachePath => Path.Combine(AppDataPath, CacheFolder);
    public static string LogPath => Path.Combine(AppDataPath, LogFolder);
}
