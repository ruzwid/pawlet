using System.IO;
using System.Text.Json;
using System.Windows;
using Pawlet.Core.Packs;

namespace Pawlet.Pets;

/// <summary>Owns open <see cref="PetWindow"/> instances for library pet directories.</summary>
public sealed class PetRuntime : IDisposable
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
    };

    private readonly Dictionary<string, Entry> _open = new(StringComparer.OrdinalIgnoreCase);
    private bool _disposed;

    public void Show(string libraryPetDir)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(libraryPetDir);

        var full = Path.GetFullPath(libraryPetDir);
        if (_open.ContainsKey(full))
        {
            // Already visible; do not Activate (steals focus from the user's app).
            return;
        }

        var manifestPath = Path.Combine(full, "manifest.json");
        var atlasPath = Path.Combine(full, "spritesheet.png");
        if (!File.Exists(manifestPath) || !File.Exists(atlasPath))
        {
            throw new FileNotFoundException("Library pet is missing manifest.json or spritesheet.png.", full);
        }

        var manifest = JsonSerializer.Deserialize<PetManifest>(File.ReadAllText(manifestPath), JsonOptions)
            ?? throw new InvalidDataException("manifest.json is empty or invalid.");
        manifest.Validate();

        var atlas = AtlasSheet.Load(atlasPath, manifest.SpriteVersion);
        var window = new PetWindow(atlas);
        window.Closed += (_, _) =>
        {
            if (_open.TryGetValue(full, out var entry) && ReferenceEquals(entry.Window, window))
            {
                // TearDown first so timer / hit-test cannot call into a disposed atlas.
                entry.Window.TearDown();
                entry.Atlas.Dispose();
                _open.Remove(full);
            }
        };

        // Stagger default placement so multiple pets do not stack exactly.
        var index = _open.Count;
        window.Left = SystemParameters.WorkArea.Right - AtlasSheet.CellWidth - 24 - index * 200;
        window.Top = SystemParameters.WorkArea.Bottom - AtlasSheet.CellHeight - 18;

        _open[full] = new Entry(window, atlas);
        window.Show();
    }

    public void Hide(string libraryPetDir)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(libraryPetDir);
        var full = Path.GetFullPath(libraryPetDir);
        if (!_open.TryGetValue(full, out var entry))
        {
            return;
        }

        entry.Window.Close();
    }

    public void HideAll()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        foreach (var entry in _open.Values.ToArray())
        {
            entry.Window.Close();
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        foreach (var entry in _open.Values.ToArray())
        {
            entry.Window.Close();
        }

        _disposed = true;
    }

    private sealed record Entry(PetWindow Window, AtlasSheet Atlas);
}
