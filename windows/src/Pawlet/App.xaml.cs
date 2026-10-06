using System.IO;
using System.Text.Json;
using System.Windows;
using Pawlet.Core.Packs;
using Pawlet.Core.Storage;
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
    private AppTray? _tray;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        _runtime = new PetRuntime();
        Exit += (_, _) =>
        {
            _tray?.Dispose();
            _tray = null;
            _runtime?.Dispose();
            _runtime = null;
        };

        try
        {
            HandleCli(e.Args);
            EnsureSampleSeeded();
            if (!ShowFirstLibraryPet())
            {
                Shutdown(0);
                return;
            }

            _tray = new AppTray(
                showAll: ShowAllLibraryPets,
                hideAll: () => _runtime!.HideAll(),
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

    private bool ShowFirstLibraryPet()
    {
        var first = EnumeratePets(LibraryPaths.DefaultRoot).FirstOrDefault();
        if (first is null)
        {
            MessageBox.Show(
                "No minis in the library yet. Run with --import path.petpack, or place a mini under %AppData%\\Pawlet\\Library.",
                "Pawlet",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            return false;
        }

        _runtime!.Show(first);
        return true;
    }

    private void ShowAllLibraryPets()
    {
        foreach (var dir in EnumeratePets(LibraryPaths.DefaultRoot))
        {
            _runtime!.Show(dir);
        }
    }

    private void OnQuit()
    {
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
