using System.IO;
using System.Text.Json;
using System.Windows;
using Pawlet.Core.Packs;
using Pawlet.Core.Storage;

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
    private SettingsModel _settings = new();
    private bool _disposed;
    private bool _paused;
    private bool? _startWithWindowsApplied;

    public bool Paused
    {
        get => _paused;
        set
        {
            ObjectDisposedException.ThrowIf(_disposed, this);
            _paused = value;
            _settings.Pause = value;
            foreach (var entry in _open.Values)
            {
                entry.Window.Paused = value;
            }
        }
    }

    public void ApplySettings(SettingsModel settings)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentNullException.ThrowIfNull(settings);
        _settings = settings;
        _paused = settings.Pause;
        foreach (var entry in _open.Values)
        {
            ApplyToWindow(entry.Window);
        }

        if (_startWithWindowsApplied != settings.StartWithWindows)
        {
            StartupRegistration.Apply(settings.StartWithWindows);
            _startWithWindowsApplied = settings.StartWithWindows;
        }
    }

    public bool IsOpen(string libraryPetDir)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(libraryPetDir);
        return _open.ContainsKey(Path.GetFullPath(libraryPetDir));
    }

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
        window.Left = SystemParameters.WorkArea.Right - AtlasSheet.CellWidth * _settings.Scale - 24 - index * 200;
        window.Top = SystemParameters.WorkArea.Bottom - AtlasSheet.CellHeight * _settings.Scale - 18;

        ApplyToWindow(window);
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

    private void ApplyToWindow(PetWindow window)
    {
        window.Paused = _paused;
        window.Scale = _settings.Scale;
        window.Opacity = _settings.Opacity;
        window.Speed = _settings.Speed;
        window.AnimateIdle = _settings.AnimateIdle;
        window.HoverReaction = _settings.HoverReaction;
        window.AnimationIntervalSeconds = _settings.AnimationIntervalSeconds;
        window.ClickThrough = _settings.ClickThrough;
    }

    private sealed record Entry(PetWindow Window, AtlasSheet Atlas);
}
