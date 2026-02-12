namespace BepozToolkit.Core.Models;

public class ToolParameter
{
    public string Name { get; set; } = "";
    public string Type { get; set; } = "string";
    public bool Required { get; set; }
    public string Description { get; set; } = "";
    public string DefaultValue { get; set; } = "";
    public string SavedValue { get; set; } = "";
}
