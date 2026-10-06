using System.ComponentModel;
using System.IO;
using System.Text.Json;
using System.Windows;
using Microsoft.Win32;
using Pawlet.Core.Packs;
using Pawlet.Core.Storage;
using Pawlet.Library;
using Pawlet.Pets;

namespace Pawlet;

public partial class App : Application
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
    };

    private PetRuntime? _runtime;
    private ForegroundWatcher? _foregroundWatcher;
    private AppTray? _tray;
    private SettingsModel _settings = new();
    private LibraryWindow? _library;
    private bool _applyingSettings;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _runtime = new PetRuntime();
        _foregroundWatcher = new ForegroundWatcher();
        _foregroundWatcher.Changed += path => _runtime?.OnForegroundAppChanged(path);
        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
        Exit += (_, _) =>
        {
            SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
            _tray?.Dispose();
            _tray = null;
            _library = null;
            _foregroundWatcher?.Dispose();
            _foregroundWatcher = null;
            _runtime?.Dispose();
            _runtime = null;
        };

        try
        {
            HandleCli(e.Args);
            EnsureSampleSeeded();

            _settings = SettingsStore.Load();
            _applyingSettings = true;
            _runtime.ApplySettings(_settings);
            _applyingSettings = false;
            _settings.PropertyChanged += OnSettingsChanged;

            var pets = EnumeratePets(LibraryPaths.DefaultRoot).ToList();
            if (pets.Count > 0)
            {
                _runtime.Show(pets[0]);
            }
            else
            {
                ShowLibrary();
            }

            _tray = new AppTray(
                showLibrary: ShowLibrary,
                showAll: ShowAllLibraryPets,
                hideAll: () =>
                {
                    _runtime!.HideAll();
                    _library?.RefreshPets();
                },
                isPaused: () => _runtime!.Paused,
                setPaused: paused => _runtime!.Paused = paused,
                quit: OnQuit);
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Pawlet", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (_applyingSettings || _runtime is null)
        {
            return;
        }

        // Pause may already be applied via PetRuntime.Paused; still push full settings.
        _applyingSettings = true;
        try
        {
            _runtime.ApplySettings(_settings);
            PersistSettings();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Pawlet", MessageBoxButton.OK, MessageBoxImage.Warning);
        }
        finally
        {
            _applyingSettings = false;
        }
    }

    private void OnDisplaySettingsChanged(object? sender, EventArgs e)
    {
        // SystemEvents may raise off the UI thread.
        Dispatcher.BeginInvoke(() => _runtime?.OnDisplaySettingsChanged());
    }

    private void PersistSettings()
    {
        SettingsStore.Save(_settings);
    }

    private void ShowLibrary()
    {
        if (_runtime is null)
        {
            return;
        }

        if (_library is null)
        {
            _library = new LibraryWindow(_runtime, _settings);
            _library.Closed += (_, _) => _library = null;
        }

        _library.RefreshPets();
        _library.Show();
        _library.Activate();
    }

    private void HandleCli(string[] args)
    {
        for (var i = 0; i < args.Length; i++)
        {
            if (!string.Equals(args[i], "--import", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (i + 1 >= args.Length)
            {
                throw new InvalidOperationException("Usage: Pawlet --import <path.petpack>");
            }

            var path = args[i + 1];
            var importer = new PackImporter();
            importer.ImportPetpack(path, LibraryPaths.DefaultRoot);
            i++;
        }
    }

    /// <summary>
    /// If the library is empty, copy the bundled Mochi sample folder (dev/CI output or repo Resources).
    /// </summary>
    private static void EnsureSampleSeeded()
    {
        var root = LibraryPaths.DefaultRoot;
        Directory.CreateDirectory(root);
        if (EnumeratePets(root).Any())
        {
            return;
        }

        var sample = FindBundledSample();
        if (sample is null)
        {
            return;
        }

        var manifestPath = Path.Combine(sample, "manifest.json");
        var manifest = JsonSerializer.Deserialize<PetManifest>(File.ReadAllText(manifestPath), JsonOptions);
        if (manifest is null || string.IsNullOrEmpty(manifest.Id))
        {
            return;
        }

        var dest = Path.Combine(root, manifest.Id);
        if (Directory.Exists(dest))
        {
            return;
        }

        CopyDirectory(sample, dest);
    }

    private void ShowAllLibraryPets()
    {
        foreach (var dir in EnumeratePets(LibraryPaths.DefaultRoot))
        {
            _runtime!.Show(dir);
        }

        _library?.RefreshPets();
    }

    private void OnQuit()
    {
        _settings.PropertyChanged -= OnSettingsChanged;
        PersistSettings();
        _library?.Close();
        _runtime?.HideAll();
        Shutdown();
    }

    private static IEnumerable<string> EnumeratePets(string libraryRoot)
    {
        if (!Directory.Exists(libraryRoot))
        {
            yield break;
        }

        foreach (var dir in Directory.EnumerateDirectories(libraryRoot).OrderBy(Path.GetFileName, StringComparer.OrdinalIgnoreCase))
        {
            var name = Path.GetFileName(dir);
            if (name.StartsWith('.'))
            {
                continue;
            }

            if (File.Exists(Path.Combine(dir, "manifest.json"))
                && File.Exists(Path.Combine(dir, "spritesheet.png")))
            {
                yield return dir;
            }
        }
    }

    private static string? FindBundledSample()
    {
        foreach (var candidate in CandidateSampleRoots())
        {
            var mochi = Path.Combine(candidate, "Mochi");
            if (File.Exists(Path.Combine(mochi, "manifest.json"))
                && File.Exists(Path.Combine(mochi, "spritesheet.png")))
            {
                return mochi;
            }
        }

        return null;
    }

    private static IEnumerable<string> CandidateSampleRoots()
    {
        var baseDir = AppContext.BaseDirectory;
        yield return Path.Combine(baseDir, "Resources", "Pets");

        var dir = new DirectoryInfo(baseDir);
        for (var i = 0; i < 8 && dir is not null; i++, dir = dir.Parent)
        {
            yield return Path.Combine(dir.FullName, "Resources", "Pets");
        }
    }

    private static void CopyDirectory(string source, string destination)
    {
        Directory.CreateDirectory(destination);
        foreach (var file in Directory.EnumerateFiles(source))
        {
            File.Copy(file, Path.Combine(destination, Path.GetFileName(file)), overwrite: false);
        }
    }
}
