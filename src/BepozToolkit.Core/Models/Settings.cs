namespace BepozToolkit.Core.Models;

public class Settings
{
    public string Theme { get; set; } = "BepozLight";
    public bool MinimizeToSystemTray { get; set; } = true;
    public bool EnableAnimations { get; set; } = true;
    public bool EnableToastNotifications { get; set; } = true;
    public double WindowLeft { get; set; } = 100;
    public double WindowTop { get; set; } = 100;
    public double WindowWidth { get; set; } = 1280;
    public double WindowHeight { get; set; } = 800;
    public List<string> FavoriteToolIds { get; set; } = [];
    public List<string> PinnedToolIds { get; set; } = [];
    public string? LastUsedConnectionId { get; set; }
}
