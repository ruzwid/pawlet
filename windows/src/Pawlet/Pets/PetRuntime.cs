using System.Diagnostics;
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
    private readonly string? _selfExePath = ResolveSelfExePath();
    private PlacementStore _placements = PlacementStore.Load();
    private SettingsModel _settings = new();
    private string? _foregroundAppKey;
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
            ApplyToWindow(entry);
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

        var petId = manifest.Id;
        var index = _open.Count;
        var global = _placements.RememberedGlobalOrigin(petId);
        if (global is { } origin)
        {
            window.Left = origin.X;
            window.Top = origin.Y;
        }
        else
        {
            // Stagger default placement so multiple pets do not stack exactly.
            window.Left = SystemParameters.WorkArea.Right - AtlasSheet.CellWidth * _settings.Scale - 24 - index * 200;
            window.Top = SystemParameters.WorkArea.Bottom - AtlasSheet.CellHeight * _settings.Scale - 18;
        }

        var entry = new Entry(window, atlas, petId);
        _open[full] = entry;
        ApplyToWindow(entry);

        if (UsesAppPlacement)
        {
            var appOrigin = _placements.RememberedAppOrigin(petId, _foregroundAppKey);
            Point? point = appOrigin is { } o ? new Point(o.X, o.Y) : null;
            window.ApplyRememberedPlacement(point, ResolvedScale(petId), _settings.Opacity);
        }

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

        PersistGlobalOrigin(entry);
        entry.Window.Close();
    }

    public void HideAll()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        foreach (var entry in _open.Values.ToArray())
        {
            PersistGlobalOrigin(entry);
            entry.Window.Close();
        }
    }

    /// <summary>Foreground app changed (normalized path or null).</summary>
    public void OnForegroundAppChanged(string? appKey)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        _foregroundAppKey = PlacementStore.NormalizeAppKey(appKey);

        if (!UsesAppPlacement)
        {
            return;
        }

        foreach (var entry in _open.Values)
        {
            if (entry.Window.IsDragging)
            {
                continue;
            }

            var appOrigin = _placements.RememberedAppOrigin(entry.PetId, _foregroundAppKey);
            Point? origin = appOrigin is { } o ? new Point(o.X, o.Y) : null;
            entry.Window.ApplyRememberedPlacement(origin, ResolvedScale(entry.PetId), _settings.Opacity);
        }
    }

    public void SaveOrigin(string petId, double left, double top, bool stampAppSlot)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(petId);

        _placements.WriteGlobalOrigin(petId, left, top);
        if (stampAppSlot && UsesAppPlacement && _foregroundAppKey is not null)
        {
            _placements.WriteAppOrigin(petId, _foregroundAppKey, left, top);
        }

        PlacementStore.Save(_placements);
    }

    public void SetSizeOverride(string petId, double? size)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(petId);

        if (UsesAppPlacement && _foregroundAppKey is not null)
        {
            if (size is { } appSize)
            {
                _placements.WriteAppSize(petId, _foregroundAppKey, appSize);
            }
            else
            {
                _placements.ClearAppSize(petId, _foregroundAppKey);
            }
        }
        else if (size is { } petSize)
        {
            _placements.WritePetSize(petId, petSize);
        }
        else
        {
            _placements.ClearPetSize(petId);
        }

        PlacementStore.Save(_placements);

        foreach (var entry in _open.Values)
        {
            if (string.Equals(entry.PetId, petId, StringComparison.OrdinalIgnoreCase))
            {
                entry.Window.Scale = ResolvedScale(petId);
            }
        }
    }

    public double ResolvedScale(string petId)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(petId);
        return _placements.ResolvedScale(
            petId,
            UsesAppPlacement,
            _foregroundAppKey,
            _settings.Scale);
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        foreach (var entry in _open.Values.ToArray())
        {
            PersistGlobalOrigin(entry);
            entry.Window.Close();
        }

        _disposed = true;
    }

    private bool UsesAppPlacement =>
        _settings.RememberPlacePerApp
        && PlacementStore.IsTrackable(_foregroundAppKey, _selfExePath ?? string.Empty);

    private void PersistGlobalOrigin(Entry entry)
    {
        _placements.WriteGlobalOrigin(entry.PetId, entry.Window.Left, entry.Window.Top);
        PlacementStore.Save(_placements);
    }

    private void ApplyToWindow(Entry entry)
    {
        var window = entry.Window;
        window.Paused = _paused;
        window.Scale = ResolvedScale(entry.PetId);
        if (!window.PlacementTransitionActive)
        {
            window.Opacity = _settings.Opacity;
        }

        window.Speed = _settings.Speed;
        window.AnimateIdle = _settings.AnimateIdle;
        window.HoverReaction = _settings.HoverReaction;
        window.AnimationIntervalSeconds = _settings.AnimationIntervalSeconds;
        window.ClickThrough = _settings.ClickThrough;
    }

    private static string? ResolveSelfExePath()
    {
        try
        {
            return PlacementStore.NormalizeAppKey(
                Environment.ProcessPath ?? Process.GetCurrentProcess().MainModule?.FileName);
        }
        catch (Exception ex) when (ex is InvalidOperationException or System.ComponentModel.Win32Exception
                                       or UnauthorizedAccessException)
        {
            return PlacementStore.NormalizeAppKey(Environment.ProcessPath);
        }
    }

    private sealed record Entry(PetWindow Window, AtlasSheet Atlas, string PetId);
}
