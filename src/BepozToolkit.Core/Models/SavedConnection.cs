namespace BepozToolkit.Core.Models;

public class SavedConnection
{
    public string Id { get; set; } = Guid.NewGuid().ToString();
    public string Name { get; set; } = "";
    public string Server { get; set; } = "";
    public string DatabaseName { get; set; } = "";
    public string AuthType { get; set; } = "Windows";
    public string Username { get; set; } = "";
    public byte[] EncryptedPassword { get; set; } = [];
    public DateTime LastUsedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
