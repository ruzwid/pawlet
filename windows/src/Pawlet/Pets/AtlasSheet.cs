using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Pawlet.Core.Engine;

namespace Pawlet.Pets;

/// <summary>Fixed-grid spritesheet (192×208 cells) with cropped frames and alpha sampling.</summary>
public sealed class AtlasSheet : IDisposable
{
    public const int CellWidth = 192;
    public const int CellHeight = 208;

    private readonly BitmapSource _sheet;
    private readonly byte[] _bgra;
    private readonly int _stride;
    private readonly Dictionary<string, ImageSource> _frames = new(StringComparer.Ordinal);
    private bool _disposed;

    private AtlasSheet(BitmapSource sheet, byte[] bgra, int stride, int spriteVersion)
    {
        _sheet = sheet;
        _bgra = bgra;
        _stride = stride;
        SpriteVersion = spriteVersion;
        RowCount = spriteVersion == 2 ? 11 : 9;
        ColumnCount = sheet.PixelWidth / CellWidth;
    }

    public int SpriteVersion { get; }
    public int RowCount { get; }
    public int ColumnCount { get; }

    public static AtlasSheet Load(string pngPath, int spriteVersion)
    {
        ArgumentException.ThrowIfNullOrEmpty(pngPath);
        if (spriteVersion is not (1 or 2))
        {
            throw new InvalidDataException("Unsupported spriteVersion. Use 1 or 2.");
        }

        if (!File.Exists(pngPath))
        {
            throw new FileNotFoundException("Sprite sheet not found.", pngPath);
        }

        var expectedHeight = spriteVersion == 2 ? 2288 : 1872;
        var source = new BitmapImage();
        source.BeginInit();
        source.UriSource = new Uri(Path.GetFullPath(pngPath), UriKind.Absolute);
        source.CacheOption = BitmapCacheOption.OnLoad;
        source.EndInit();
        source.Freeze();

        if (source.PixelWidth != 1536 || source.PixelHeight != expectedHeight)
        {
            throw new InvalidDataException(
                "Use a PNG sprite sheet measuring 1536 × 2288 (v2), or 1536 × 1872 (v1).");
        }

        var converted = new FormatConvertedBitmap(source, PixelFormats.Bgra32, null, 0);
        converted.Freeze();

        var stride = converted.PixelWidth * 4;
        var bgra = new byte[stride * converted.PixelHeight];
        converted.CopyPixels(bgra, stride, 0);

        return new AtlasSheet(converted, bgra, stride, spriteVersion);
    }

    public ImageSource Frame(SpriteFrame f)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (f.Row < 0 || f.Row >= RowCount || f.Column < 0 || f.Column >= ColumnCount)
        {
            f = new SpriteFrame(0, 0);
        }

        var key = $"{f.Row}:{f.Column}";
        if (_frames.TryGetValue(key, out var cached))
        {
            return cached;
        }

        var cropped = new CroppedBitmap(
            _sheet,
            new Int32Rect(f.Column * CellWidth, f.Row * CellHeight, CellWidth, CellHeight));
        cropped.Freeze();
        _frames[key] = cropped;
        return cropped;
    }

    /// <summary>Alpha (0–255) at cell-local coordinates; out of range returns 0.</summary>
    public byte AlphaAt(SpriteFrame f, int x, int y)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (x < 0 || x >= CellWidth || y < 0 || y >= CellHeight
            || f.Row < 0 || f.Row >= RowCount || f.Column < 0 || f.Column >= ColumnCount)
        {
            return 0;
        }

        var px = f.Column * CellWidth + x;
        var py = f.Row * CellHeight + y;
        return _bgra[py * _stride + px * 4 + 3];
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _frames.Clear();
    }
}
