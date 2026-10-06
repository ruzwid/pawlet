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
    private string? _lastTrackableAppKey;
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
        var wasRemembering = _settings.RememberPlacePerApp;
        _settings = settings;
        _paused = settings.Pause;

        // Placement before ApplyToWindow so Scale is not assigned before the fade starts.
        if (!wasRemembering && _settings.RememberPlacePerApp)
        {
            ApplyAppPlacementToOpenWindows();
        }

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
        var petId = manifest.Id;
        window.OnDragEnded = () =>
        {
            // Stamp while PetWindow still reports IsDragging (drag pin).
            SaveOrigin(petId, window.Left, window.Top, stampAppSlot: true);
            // Reconcile after mouse-up clears _dragging (BeginInvoke runs next).
            window.Dispatcher.BeginInvoke(ApplyAppPlacementToOpenWindows);
        };
        window.ResolveEffectiveScale = () => ResolvedScaleForStamp(petId);
        window.OnSetSizeOverride = size => SetSizeOverride(petId, size);
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

        var index = _open.Count;
        var global = _placements.RememberedGlobalOrigin(petId);
        var showScale = ResolvedScale(petId);
        var showWidth = AtlasSheet.CellWidth * showScale;
        var showHeight = AtlasSheet.CellHeight * showScale;
        if (global is { } origin)
        {
            var clamped = PetWindow.ClampOriginToWorkArea(origin.X, origin.Y, showWidth, showHeight);
            window.Left = clamped.X;
            window.Top = clamped.Y;
        }
        else
        {
            // Stagger default placement so multiple pets do not stack exactly.
            var work = SystemParameters.WorkArea;
            var staggered = PetWindow.ClampOriginToWorkArea(
                work.Right - showWidth - 24 - index * 200,
                work.Bottom - showHeight - 18,
                showWidth,
                showHeight);
            window.Left = staggered.X;
            window.Top = staggered.Y;
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
        if (_selfExePath is not null
            && PlacementStore.IsTrackable(_foregroundAppKey, _selfExePath))
        {
            _lastTrackableAppKey = _foregroundAppKey;
        }

        // Skip apply while dragging; stamp pin uses lastTrackable. Reconcile on drag end.
        if (AnyWindowDragging)
        {
            return;
        }

        ApplyAppPlacementToOpenWindows();
    }

    private void ApplyAppPlacementToOpenWindows()
    {
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
        var stampKey = StampAppKey;
        if (stampAppSlot && UsesStampPlacement && stampKey is not null)
        {
            _placements.WriteAppOrigin(petId, stampKey, left, top);
        }

        PlacementStore.Save(_placements);
    }

    public void SetSizeOverride(string petId, double? size)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(petId);

        var stampKey = StampAppKey;
        if (UsesStampPlacement && stampKey is not null)
        {
            if (size is { } appSize)
            {
                _placements.WriteAppSize(petId, stampKey, appSize);
            }
            else
            {
                _placements.ClearAppSize(petId, stampKey);
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
                entry.Window.Scale = ResolvedScaleForStamp(petId);
            }
        }
    }

    /// <summary>
    /// Scale for Settings / apply when the true foreground app drives placement
    /// (Library Settings uses Settings.Scale when Pawlet is frontmost).
    /// </summary>
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

    /// <summary>
    /// Scale for pet context Size: trackable current → app size; drag pin → last
    /// trackable; Library/self frontmost → pet-level size.
    /// </summary>
    public double ResolvedScaleForStamp(string petId)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        ArgumentException.ThrowIfNullOrEmpty(petId);
        return _placements.ResolvedScale(
            petId,
            UsesStampPlacement,
            StampAppKey,
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

    /// <summary>True when the live foreground app is trackable (not self).</summary>
    private bool UsesAppPlacement =>
        _settings.RememberPlacePerApp
        && _selfExePath is not null
        && PlacementStore.IsTrackable(_foregroundAppKey, _selfExePath);

    /// <summary>True when pet interaction can stamp/read a per-app slot (trackable or drag-pinned).</summary>
    private bool UsesStampPlacement =>
        _settings.RememberPlacePerApp && StampAppKey is not null;

    private string? StampAppKey =>
        PlacementStampKey.Select(
            _foregroundAppKey,
            _lastTrackableAppKey,
            _selfExePath,
            AnyWindowDragging);

    private bool AnyWindowDragging =>
        _open.Values.Any(entry => entry.Window.IsDragging);

    private void PersistGlobalOrigin(Entry entry)
    {
        _placements.WriteGlobalOrigin(entry.PetId, entry.Window.Left, entry.Window.Top);
        PlacementStore.Save(_placements);
    }

    private void ApplyToWindow(Entry entry)
    {
        var window = entry.Window;
        window.Paused = _paused;
        if (!window.PlacementTransitionActive)
        {
            // Settings path: when Library is frontmost, UsesAppPlacement is false → Settings.Scale.
            window.Scale = ResolvedScale(entry.PetId);
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
