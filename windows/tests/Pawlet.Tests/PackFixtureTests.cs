using Pawlet.Core.Packs;

namespace Pawlet.Tests;

public class PackFixtureTests
{
    [Fact]
    public void Shared_zip_slip_fixture_is_rejected_by_importer()
    {
        var zip = SharedPath(Path.Combine("fixtures", "packs", "zip-slip-evil.petpack"));
        Assert.True(File.Exists(zip), "missing shared/fixtures/packs/zip-slip-evil.petpack");

        var root = Path.Combine(Path.GetTempPath(), "pawlet-lib-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            Assert.ThrowsAny<Exception>(() => new PackImporter().ImportPetpack(zip, root));
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }

    [Fact]
    public void Shared_zip_slip_fixture_entry_name_fails_ZipSafety()
    {
        var zip = SharedPath(Path.Combine("fixtures", "packs", "zip-slip-evil.petpack"));
        using var archive = System.IO.Compression.ZipFile.OpenRead(zip);
        var names = archive.Entries.Select(e => e.FullName.Replace('\\', '/')).ToList();
        Assert.Contains("../evil.png", names);
        Assert.ThrowsAny<Exception>(() => ZipSafety.ValidateEntryName("../evil.png"));
    }

    private static string SharedPath(string relativeToShared)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var shared = Path.Combine(dir.FullName, "shared");
            if (Directory.Exists(shared))
            {
                return Path.Combine(shared, relativeToShared);
            }

            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException("Could not find shared/ walking up from " + AppContext.BaseDirectory);
    }
}
