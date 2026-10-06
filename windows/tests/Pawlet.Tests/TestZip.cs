using System.IO.Compression;

namespace Pawlet.Tests;

internal static class TestZip
{
    public static string Create(IEnumerable<(string Name, byte[] Data)> entries)
    {
        var path = Path.Combine(Path.GetTempPath(), "pawlet-test-" + Guid.NewGuid().ToString("N") + ".petpack");
        using (var fs = File.Create(path))
        using (var zip = new ZipArchive(fs, ZipArchiveMode.Create))
        {
            foreach (var (name, data) in entries)
            {
                var entry = zip.CreateEntry(name, CompressionLevel.Optimal);
                using var stream = entry.Open();
                stream.Write(data);
            }
        }

        return path;
    }
}
