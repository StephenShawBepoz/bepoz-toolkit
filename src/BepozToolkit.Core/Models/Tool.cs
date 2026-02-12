namespace BepozToolkit.Core.Models;

public class Tool
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Category { get; set; } = "";
    public string Description { get; set; } = "";
    public string Version { get; set; } = "";
    public string File { get; set; } = "";
    public bool RequiresAdmin { get; set; }
    public bool RequiresDatabase { get; set; }
    public string Author { get; set; } = "";
    public string Documentation { get; set; } = "";
    public DateTime LastUpdated { get; set; }
    public List<string> Dependencies { get; set; } = [];
    public List<ToolParameter> Parameters { get; set; } = [];
    public ToolStatus Status { get; set; } = ToolStatus.Available;
    public bool IsFavorite { get; set; }
    public bool IsPinned { get; set; }
    public string CacheAge { get; set; } = "";
}

public enum ToolStatus
{
    Available,
    Cached,
    Stale,
    Running,
    Completed,
    Failed,
    UnavailableOffline
}
