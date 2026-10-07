using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Pawlet.Core.Packs;

public sealed record PetManifest(
    int SchemaVersion,
    string Id,
    string Name,
    string Description,
    int SpriteVersion,
    string Atlas,
    string? Author,
    [property: JsonPropertyName("artworkSHA256")] string? ArtworkSha256)
{
    private static readonly Regex IdPattern = new("^[A-Za-z0-9_-]{1,64}$", RegexOptions.Compiled);

    public void Validate()
    {
        if (SchemaVersion != 1 || (SpriteVersion is not (1 or 2)) || Atlas != "spritesheet.png")
        {
            throw new InvalidDataException("Unsupported pack format. Use schemaVersion 1 and spriteVersion 1 or 2.");
        }

        if (string.IsNullOrEmpty(Id) || !IdPattern.IsMatch(Id))
        {
            throw new InvalidDataException("The mini ID must be 1–64 letters, numbers, hyphens or underscores.");
        }

        if (string.IsNullOrWhiteSpace(Name) || Name.Length > 60 || Name.Any(char.IsControl)
            || string.IsNullOrEmpty(Description) || Description.Length > 600
            || (Author?.Length ?? 0) > 100)
        {
            throw new InvalidDataException("The mini name or description is too long or invalid.");
        }

        if (ArtworkSha256 is not null
            && (ArtworkSha256.Length != 64 || !ArtworkSha256.All(char.IsAsciiHexDigit)))
        {
            throw new InvalidDataException("Invalid artwork hash.");
        }
    }
}
