using System.Text.Json.Serialization;

namespace Pawlet.Core.Storage;

/// <summary>Root document for %AppData%/Pawlet/placements.json.</summary>
public sealed class PlacementsDocument
{
    [JsonPropertyName("pets")]
    public Dictionary<string, PetPlacement> Pets { get; set; } =
        new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>Per-pet global origin/size plus per-app slots.</summary>
public sealed class PetPlacement
{
    [JsonPropertyName("x")]
    public double? X { get; set; }

    [JsonPropertyName("y")]
    public double? Y { get; set; }

    [JsonPropertyName("size")]
    public double? Size { get; set; }

    [JsonPropertyName("apps")]
    public Dictionary<string, AppPlacementSlot> Apps { get; set; } =
        new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>Origin and optional size for one frontmost app path.</summary>
public sealed class AppPlacementSlot
{
    [JsonPropertyName("x")]
    public double? X { get; set; }

    [JsonPropertyName("y")]
    public double? Y { get; set; }

    [JsonPropertyName("size")]
    public double? Size { get; set; }
}
