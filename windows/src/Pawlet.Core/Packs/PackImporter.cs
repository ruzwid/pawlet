using System.Buffers.Binary;
using System.IO.Compression;
using System.Text.Json;

namespace Pawlet.Core.Packs;

public sealed class PackImporter
{
    public const long MaxArchiveBytes = 25L * 1024 * 1024;
    public const long MaxImageBytes = 20L * 1024 * 1024;
    public const long MaxMetadataBytes = 65_536;

    private static readonly HashSet<string> AllowedFiles = new(StringComparer.Ordinal)
    {
        "manifest.json",
        "spritesheet.png",
        "preview.png",
    };

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
    };

    public PetManifest ImportPetpack(string zipPath, string libraryRoot)
    {
        ArgumentException.ThrowIfNullOrEmpty(zipPath);
        ArgumentException.ThrowIfNullOrEmpty(libraryRoot);

        var zipInfo = new FileInfo(zipPath);
        if (!zipInfo.Exists)
        {
            throw new FileNotFoundException("Pack file not found.", zipPath);
        }

        if (zipInfo.Length > MaxArchiveBytes)
        {
            throw new InvalidDataException("Mini packs must be ZIP files under 25 MiB.");
        }

        Directory.CreateDirectory(libraryRoot);

        using var archive = ZipFile.OpenRead(zipPath);
        var extracted = new Dictionary<string, byte[]>(StringComparer.Ordinal);

        foreach (var entry in archive.Entries)
        {
            var fullName = entry.FullName.Replace('\\', '/');
            if (string.IsNullOrEmpty(fullName) || fullName.EndsWith('/'))
            {
                continue;
            }

            if (ZipSafety.IsFinderMetadata(fullName))
            {
                continue;
            }

            ZipSafety.ValidateEntryName(fullName);

            var segments = fullName.Split('/', StringSplitOptions.RemoveEmptyEntries);
            if (segments.Length != 1)
            {
                throw new InvalidDataException("ZIPs may contain one flat mini. Nested paths are not supported.");
            }

            var name = segments[0];
            if (!AllowedFiles.Contains(name))
            {
                throw new InvalidDataException("Choose a mini ZIP containing only metadata, a sprite sheet and optional preview.");
            }

            if (extracted.ContainsKey(name))
            {
                throw new InvalidDataException("Duplicate pack files are not accepted.");
            }

            // Unix mode in high 16 bits when present (0 = unset / DOS).
            var mode = (entry.ExternalAttributes >> 16) & 0xF000;
            if (mode != 0 && mode != 0x8000)
            {
                throw new InvalidDataException("Archive links and special files are not supported.");
            }

            var maxBytes = name is "manifest.json" ? MaxMetadataBytes : MaxImageBytes;
            if (entry.Length <= 0 || entry.Length > maxBytes)
            {
                throw new InvalidDataException("A mini-pack file exceeds the size limit.");
            }

            using var entryStream = entry.Open();
            using var limited = new LimitedReadStream(entryStream, maxBytes);
            using var ms = new MemoryStream((int)Math.Min(entry.Length, maxBytes));
            limited.CopyTo(ms);
            if (ms.Length > maxBytes)
            {
                throw new InvalidDataException("A mini-pack file exceeds the size limit.");
            }

            extracted[name] = ms.ToArray();
        }

        if (!extracted.ContainsKey("manifest.json") || !extracted.ContainsKey("spritesheet.png"))
        {
            throw new InvalidDataException("The ZIP must contain manifest.json and spritesheet.png.");
        }

        var manifest = JsonSerializer.Deserialize<PetManifest>(extracted["manifest.json"], JsonOptions)
            ?? throw new InvalidDataException("manifest.json is empty or invalid.");
        manifest.Validate();

        var png = extracted["spritesheet.png"];
        var (width, height) = ReadPngSize(png);
        var expectedHeight = manifest.SpriteVersion == 2 ? 2288 : 1872;
        if (width != 1536 || height != expectedHeight)
        {
            throw new InvalidDataException(
                "Use a PNG sprite sheet measuring 1536 × 2288 (v2), or 1536 × 1872 (v1).");
        }

        var destination = Path.Combine(libraryRoot, manifest.Id);
        if (Directory.Exists(destination) || File.Exists(destination))
        {
            throw new InvalidDataException($"{manifest.Name} is already in your library. Each mini needs a unique ID.");
        }

        var staging = Path.Combine(libraryRoot, ".import-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(staging);
        try
        {
            File.WriteAllBytes(Path.Combine(staging, "manifest.json"), extracted["manifest.json"]);
            File.WriteAllBytes(Path.Combine(staging, "spritesheet.png"), png);
            if (extracted.TryGetValue("preview.png", out var preview))
            {
                File.WriteAllBytes(Path.Combine(staging, "preview.png"), preview);
            }

            Directory.Move(staging, destination);
        }
        catch
        {
            if (Directory.Exists(staging))
            {
                Directory.Delete(staging, recursive: true);
            }

            throw;
        }

        return manifest;
    }

    private static (int Width, int Height) ReadPngSize(ReadOnlySpan<byte> png)
    {
        ReadOnlySpan<byte> signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        if (png.Length < 24 || !png[..8].SequenceEqual(signature))
        {
            throw new InvalidDataException("spritesheet.png is not a PNG.");
        }

        if (!png.Slice(12, 4).SequenceEqual("IHDR"u8))
        {
            throw new InvalidDataException("spritesheet.png is missing IHDR.");
        }

        var width = BinaryPrimitives.ReadInt32BigEndian(png.Slice(16, 4));
        var height = BinaryPrimitives.ReadInt32BigEndian(png.Slice(20, 4));
        if (width <= 0 || height <= 0)
        {
            throw new InvalidDataException("spritesheet.png has invalid dimensions.");
        }

        return (width, height);
    }

    private sealed class LimitedReadStream(Stream inner, long maxBytes) : Stream
    {
        private long _read;

        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            if (_read >= maxBytes)
            {
                throw new InvalidDataException("A mini-pack file exceeds the size limit.");
            }

            var remaining = maxBytes - _read;
            var toRead = (int)Math.Min(count, remaining + 1);
            var n = inner.Read(buffer, offset, toRead);
            _read += n;
            if (_read > maxBytes)
            {
                throw new InvalidDataException("A mini-pack file exceeds the size limit.");
            }

            return n;
        }

        public override void Flush() { }
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }
}
