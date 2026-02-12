namespace BepozToolkit.Core.Models;

public class Manifest
{
    public string Version { get; set; } = "";
    public List<Tool> Tools { get; set; } = [];
    public List<Module> Modules { get; set; } = [];
    public List<Category> Categories { get; set; } = [];
}
