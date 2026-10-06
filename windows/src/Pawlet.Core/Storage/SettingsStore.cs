using System.Text.Json;
using System.Text.Json.Serialization;

namespace Pawlet.Core.Storage;

/// <summary>Load/save <see cref="SettingsModel"/> as JSON under ApplicationData/Pawlet.</summary>
public static class SettingsStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public static string DefaultPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Pawlet",
        "settings.json");

    public static SettingsModel Load(string? path = null)
    {
        path ??= DefaultPath;
        if (!File.Exists(path))
        {
            return new SettingsModel();
        }

        try
        {
            var json = File.ReadAllText(path);
            var model = JsonSerializer.Deserialize<SettingsModel>(json, JsonOptions) ?? new SettingsModel();
            model.Normalize();
            return model;
        }
        catch (JsonException)
        {
            return new SettingsModel();
        }
        catch (IOException)
        {
            return new SettingsModel();
        }
    }

    public static void Save(SettingsModel settings, string? path = null)
    {
        ArgumentNullException.ThrowIfNull(settings);
        path ??= DefaultPath;
        settings.Normalize();

        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
        }

        var json = JsonSerializer.Serialize(settings, JsonOptions);
        File.WriteAllText(path, json);
    }
}
