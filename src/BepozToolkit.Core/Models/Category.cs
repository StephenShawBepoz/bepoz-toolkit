namespace BepozToolkit.Core.Models;

public class Category
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "";
    public string Color { get; set; } = "#1976D2";
    public int ToolCount { get; set; }
}
