using System.Text;
using Pawlet.Core.Packs;

namespace Pawlet.Tests;

public class PackImporterTests
{
    [Fact]
    public void Rejects_zip_entry_with_parent_segment()
    {
        var zip = TestZip.Create([("../evil.png", new byte[] { 1 })]);
        try
        {
            var importer = new PackImporter();
            Assert.ThrowsAny<Exception>(() => importer.ImportPetpack(zip, NewTempLibrary()));
        }
        finally
        {
            File.Delete(zip);
        }
    }

    [Fact]
    public void Rejects_manifest_omitting_description()
    {
        var png = TestPng.Solid(1536, 1872);
        var manifest = """{"schemaVersion":1,"id":"mochi-test","name":"Mochi","spriteVersion":1,"atlas":"spritesheet.png"}""";
        var zip = TestZip.Create(
        [
            ("manifest.json", Encoding.UTF8.GetBytes(manifest)),
            ("spritesheet.png", png),
        ]);
        var root = NewTempLibrary();
        try
        {
            Assert.Throws<InvalidDataException>(() => new PackImporter().ImportPetpack(zip, root));
        }
        finally
        {
            File.Delete(zip);
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public void Imports_flat_petpack_with_valid_manifest()
    {
        var png = TestPng.Solid(1536, 1872);
        var manifest = """{"schemaVersion":1,"id":"mochi-test","name":"Mochi","description":"t","spriteVersion":1,"atlas":"spritesheet.png"}""";
        var zip = TestZip.Create(
        [
            ("manifest.json", Encoding.UTF8.GetBytes(manifest)),
            ("spritesheet.png", png),
        ]);
        var root = NewTempLibrary();
        try
        {
            var m = new PackImporter().ImportPetpack(zip, root);
            Assert.Equal("mochi-test", m.Id);
            Assert.True(File.Exists(Path.Combine(root, "mochi-test", "spritesheet.png")));
            Assert.True(File.Exists(Path.Combine(root, "mochi-test", "manifest.json")));
        }
        finally
        {
            File.Delete(zip);
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public void ZipSafety_rejects_parent_and_absolute_paths()
    {
        Assert.ThrowsAny<Exception>(() => ZipSafety.ValidateEntryName("../evil.png"));
        Assert.ThrowsAny<Exception>(() => ZipSafety.ValidateEntryName("/abs.png"));
        Assert.ThrowsAny<Exception>(() => ZipSafety.ValidateEntryName(@"C:\evil.png"));
        Assert.ThrowsAny<Exception>(() => ZipSafety.ValidateEntryName(@"foo\bar.png"));
        ZipSafety.ValidateEntryName("manifest.json");
        ZipSafety.ValidateEntryName("spritesheet.png");
    }

    [Fact]
    public void LibraryPaths_DefaultRoot_is_under_AppData_Pawlet_Library()
    {
        var expected = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Pawlet",
            "Library");
        Assert.Equal(expected, Pawlet.Core.Storage.LibraryPaths.DefaultRoot);
    }

    private static string NewTempLibrary()
    {
        var root = Path.Combine(Path.GetTempPath(), "pawlet-lib-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        return root;
    }
}
