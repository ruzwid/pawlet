using System.Text.Json;
using Pawlet.Core.Engine;

namespace Pawlet.Core.Storage;

/// <summary>Load/save per-pet global and per-app origins/sizes under ApplicationData/Pawlet.</summary>
public sealed class PlacementStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    private readonly PlacementsDocument _document;

    private PlacementStore(PlacementsDocument document)
    {
        _document = document;
        NormalizeDictionaries(_document);
    }

    public static string DefaultPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Pawlet",
        "placements.json");

    public static PlacementStore Load(string? path = null)
    {
        path ??= DefaultPath;
        if (!File.Exists(path))
        {
            return new PlacementStore(new PlacementsDocument());
        }

        try
        {
            var json = File.ReadAllText(path);
            var document = JsonSerializer.Deserialize<PlacementsDocument>(json, JsonOptions)
                           ?? new PlacementsDocument();
            return new PlacementStore(document);
        }
        catch (JsonException)
        {
            return new PlacementStore(new PlacementsDocument());
        }
        catch (IOException)
        {
            return new PlacementStore(new PlacementsDocument());
        }
        catch (UnauthorizedAccessException)
        {
            return new PlacementStore(new PlacementsDocument());
        }
    }

    public static void Save(PlacementStore store, string? path = null)
    {
        ArgumentNullException.ThrowIfNull(store);
        path ??= DefaultPath;

        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
        }

        var json = JsonSerializer.Serialize(store._document, JsonOptions);
        var tempPath = path + ".tmp";
        try
        {
            File.WriteAllText(tempPath, json);
            File.Move(tempPath, path, overwrite: true);
        }
        catch (IOException)
        {
            TryDelete(tempPath);
        }
        catch (UnauthorizedAccessException)
        {
            TryDelete(tempPath);
        }
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }

    public static string? NormalizeAppKey(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return null;
        }

        try
        {
            return Path.GetFullPath(path);
        }
        catch (ArgumentException)
        {
            return null;
        }
        catch (NotSupportedException)
        {
            return null;
        }
        catch (PathTooLongException)
        {
            return null;
        }
    }

    public static bool IsTrackable(string? appKey, string selfExePath)
    {
        var normalized = NormalizeAppKey(appKey);
        if (normalized is null)
        {
            return false;
        }

        var self = NormalizeAppKey(selfExePath);
        if (self is null)
        {
            // Self unresolvable: fail closed (never treat paths as trackable).
            return false;
        }

        return !string.Equals(normalized, self, StringComparison.OrdinalIgnoreCase);
    }

    public void WriteGlobalOrigin(string petId, double x, double y)
    {
        var pet = GetOrCreatePet(petId);
        pet.X = FiniteOrNull(x);
        pet.Y = FiniteOrNull(y);
    }

    public (double X, double Y)? RememberedGlobalOrigin(string petId)
    {
        if (!_document.Pets.TryGetValue(petId, out var pet))
        {
            return null;
        }

        return CompleteOrigin(pet.X, pet.Y);
    }

    public void WriteAppOrigin(string petId, string appKey, double x, double y)
    {
        var key = NormalizeAppKey(appKey);
        if (key is null)
        {
            return;
        }

        var app = GetOrCreateApp(petId, key);
        app.X = FiniteOrNull(x);
        app.Y = FiniteOrNull(y);
    }

    public (double X, double Y)? RememberedAppOrigin(string petId, string? appKey)
    {
        var key = NormalizeAppKey(appKey);
        if (key is null || !_document.Pets.TryGetValue(petId, out var pet))
        {
            return null;
        }

        if (!pet.Apps.TryGetValue(key, out var app))
        {
            return null;
        }

        return CompleteOrigin(app.X, app.Y);
    }

    public void WritePetSize(string petId, double size)
    {
        if (!double.IsFinite(size))
        {
            return;
        }

        GetOrCreatePet(petId).Size = ClampSize(size);
    }

    public void ClearPetSize(string petId)
    {
        if (_document.Pets.TryGetValue(petId, out var pet))
        {
            pet.Size = null;
        }
    }

    public double? RememberedPetSize(string petId)
    {
        if (!_document.Pets.TryGetValue(petId, out var pet) || pet.Size is not { } size || !double.IsFinite(size))
        {
            return null;
        }

        return ClampSize(size);
    }

    public void WriteAppSize(string petId, string appKey, double size)
    {
        if (!double.IsFinite(size))
        {
            return;
        }

        var key = NormalizeAppKey(appKey);
        if (key is null)
        {
            return;
        }

        GetOrCreateApp(petId, key).Size = ClampSize(size);
    }

    public void ClearAppSize(string petId, string? appKey)
    {
        var key = NormalizeAppKey(appKey);
        if (key is null || !_document.Pets.TryGetValue(petId, out var pet))
        {
            return;
        }

        if (pet.Apps.TryGetValue(key, out var app))
        {
            app.Size = null;
        }
    }

    public double? RememberedAppSize(string petId, string? appKey)
    {
        var key = NormalizeAppKey(appKey);
        if (key is null || !_document.Pets.TryGetValue(petId, out var pet))
        {
            return null;
        }

        if (!pet.Apps.TryGetValue(key, out var app) || app.Size is not { } size || !double.IsFinite(size))
        {
            return null;
        }

        return ClampSize(size);
    }

    public double ResolvedScale(string petId, bool rememberPerApp, string? appKey, double settingsScale)
    {
        if (rememberPerApp)
        {
            var appSize = RememberedAppSize(petId, appKey);
            if (appSize is not null)
            {
                return appSize.Value;
            }
        }

        var petSize = RememberedPetSize(petId);
        if (petSize is not null)
        {
            return petSize.Value;
        }

        return ClampSize(double.IsFinite(settingsScale) ? settingsScale : 1.0);
    }

    private PetPlacement GetOrCreatePet(string petId)
    {
        if (_document.Pets.TryGetValue(petId, out var pet))
        {
            return pet;
        }

        pet = new PetPlacement();
        _document.Pets[petId] = pet;
        return pet;
    }

    private AppPlacementSlot GetOrCreateApp(string petId, string appKey)
    {
        var pet = GetOrCreatePet(petId);
        if (pet.Apps.TryGetValue(appKey, out var app))
        {
            return app;
        }

        app = new AppPlacementSlot();
        pet.Apps[appKey] = app;
        return app;
    }

    private static (double X, double Y)? CompleteOrigin(double? x, double? y)
    {
        if (x is not { } ox || y is not { } oy || !double.IsFinite(ox) || !double.IsFinite(oy))
        {
            return null;
        }

        return (ox, oy);
    }

    private static double? FiniteOrNull(double value) =>
        double.IsFinite(value) ? value : null;

    private static double ClampSize(double size) =>
        Math.Min(MotionConstants.MaxPetScale, Math.Max(MotionConstants.MinPetScale, size));

    private static void NormalizeDictionaries(PlacementsDocument document)
    {
        document.Pets = ToOrdinalIgnoreCase(document.Pets);
        foreach (var pet in document.Pets.Values)
        {
            pet.Apps = ToOrdinalIgnoreCase(pet.Apps);
        }
    }

    private static Dictionary<string, T> ToOrdinalIgnoreCase<T>(Dictionary<string, T>? source)
    {
        var result = new Dictionary<string, T>(StringComparer.OrdinalIgnoreCase);
        if (source is null)
        {
            return result;
        }

        foreach (var (key, value) in source)
        {
            result[key] = value;
        }

        return result;
    }
}
