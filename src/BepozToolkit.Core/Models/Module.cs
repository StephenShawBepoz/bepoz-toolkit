namespace BepozToolkit.Core.Models;

public class Module
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public string Version { get; set; } = "";
    public string File { get; set; } = "";
    public string Author { get; set; } = "";
    public DateTime LastUpdated { get; set; }
    public List<string> ExportedFunctions { get; set; } = [];
}
