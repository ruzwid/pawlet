using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Text.Json;
using System.Windows;
using Microsoft.Win32;
using Pawlet.Core.Engine;
using Pawlet.Core.Packs;
using Pawlet.Core.Storage;
using Pawlet.Pets;

namespace Pawlet.Library;

public partial class LibraryWindow : Window
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
    };

    private readonly PetRuntime _runtime;
    private readonly SettingsModel _settings;
    private readonly ObservableCollection<PetRow> _rows = new();
    private bool _suppressHoverSync;

    public LibraryWindow(PetRuntime runtime, SettingsModel settings)
    {
        ArgumentNullException.ThrowIfNull(runtime);
        ArgumentNullException.ThrowIfNull(settings);

        _runtime = runtime;
        _settings = settings;

        InitializeComponent();
        DataContext = _settings;

        foreach (HoverReaction reaction in Enum.GetValues<HoverReaction>())
        {
            HoverReactionBox.Items.Add(new ReactionChoice(reaction, reaction.Title()));
        }

        HoverReactionBox.DisplayMemberPath = nameof(ReactionChoice.Title);
        HoverReactionBox.SelectedValuePath = nameof(ReactionChoice.Value);
        _suppressHoverSync = true;
        HoverReactionBox.SelectedValue = _settings.HoverReaction;
        _suppressHoverSync = false;
        HoverReactionBox.SelectionChanged += (_, _) =>
        {
            if (_suppressHoverSync || HoverReactionBox.SelectedValue is not HoverReaction reaction)
            {
                return;
            }

            _settings.HoverReaction = reaction;
        };

        PetList.ItemsSource = _rows;
        _settings.PropertyChanged += OnSettingsChanged;
        Closed += (_, _) => _settings.PropertyChanged -= OnSettingsChanged;
        RefreshPets();
    }

    public void RefreshPets()
    {
        _rows.Clear();
        foreach (var dir in EnumeratePets(LibraryPaths.DefaultRoot))
        {
            _rows.Add(CreateRow(dir));
        }
    }

    private void OnSettingsChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName != nameof(SettingsModel.HoverReaction) || _suppressHoverSync)
        {
            return;
        }

        _suppressHoverSync = true;
        HoverReactionBox.SelectedValue = _settings.HoverReaction;
        _suppressHoverSync = false;
    }

    private void OnImportClick(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "Pawlet pack (*.petpack)|*.petpack|ZIP (*.zip)|*.zip|All files (*.*)|*.*",
            Title = "Import mini pack",
        };

        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        try
        {
            var manifest = new PackImporter().ImportPetpack(dialog.FileName, LibraryPaths.DefaultRoot);
            RefreshPets();
            var dest = Path.Combine(LibraryPaths.DefaultRoot, manifest.Id);
            if (MessageBox.Show(
                    this,
                    "Show \"" + manifest.Name + "\" on the desktop?",
                    "Pawlet",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question) == MessageBoxResult.Yes)
            {
                _runtime.Show(dest);
                RefreshPets();
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Pawlet", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void OnShowHideClick(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { Tag: string dir })
        {
            return;
        }

        try
        {
            if (_runtime.IsOpen(dir))
            {
                _runtime.Hide(dir);
            }
            else
            {
                _runtime.Show(dir);
            }

            RefreshPets();
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "Pawlet", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private PetRow CreateRow(string dir)
    {
        var id = Path.GetFileName(dir);
        var name = id;
        var manifestPath = Path.Combine(dir, "manifest.json");
        try
        {
            var manifest = JsonSerializer.Deserialize<PetManifest>(File.ReadAllText(manifestPath), JsonOptions);
            if (manifest is not null)
            {
                if (!string.IsNullOrWhiteSpace(manifest.Name))
                {
                    name = manifest.Name;
                }

                if (!string.IsNullOrWhiteSpace(manifest.Id))
                {
                    id = manifest.Id;
                }
            }
        }
        catch (JsonException)
        {
            // Keep folder name.
        }
        catch (IOException)
        {
            // Keep folder name.
        }

        var open = _runtime.IsOpen(dir);
        return new PetRow(dir, name, id, open ? "Hide" : "Show");
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

    private sealed record PetRow(string Directory, string Name, string Id, string ActionLabel);

    private sealed record ReactionChoice(HoverReaction Value, string Title);
}
