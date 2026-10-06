using System.Windows;
using System.Windows.Interop;

namespace Pawlet.Pets;

/// <summary>Selective click-through via <c>WM_NCHITTEST</c> and per-pixel alpha.</summary>
public sealed class HitTestAttachment : IDisposable
{
    public const int AlphaThreshold = 16;

    private const int WmNcHitTest = 0x0084;
    private const int HtTransparent = -1;
    private const int HtClient = 1;

    private readonly Window _window;
    private readonly Func<Point, byte> _alphaAtClient;
    private HwndSource? _source;
    private HwndSourceHook? _hook;
    private bool _disposed;

    private HitTestAttachment(Window window, Func<Point, byte> alphaAtClient)
    {
        _window = window;
        _alphaAtClient = alphaAtClient;
    }

    /// <summary>
    /// Hooks the window so transparent padding (alpha below <see cref="AlphaThreshold"/>)
    /// returns <c>HTTRANSPARENT</c>; opaque pixels return <c>HTCLIENT</c>.
    /// Dispose from pet teardown before the HWND goes away.
    /// </summary>
    public static HitTestAttachment Attach(Window window, Func<Point, byte> alphaAtClient)
    {
        ArgumentNullException.ThrowIfNull(window);
        ArgumentNullException.ThrowIfNull(alphaAtClient);

        var attachment = new HitTestAttachment(window, alphaAtClient);
        if (window.IsLoaded)
        {
            attachment.TryHook();
        }
        else
        {
            window.SourceInitialized += attachment.OnSourceInitialized;
        }

        return attachment;
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        _window.SourceInitialized -= OnSourceInitialized;
        if (!_disposed)
        {
            TryHook();
        }
    }

    private void TryHook()
    {
        if (_hook is not null)
        {
            return;
        }

        var helper = new WindowInteropHelper(_window);
        if (helper.Handle == IntPtr.Zero)
        {
            return;
        }

        var source = HwndSource.FromHwnd(helper.Handle);
        if (source is null)
        {
            return;
        }

        _hook = OnHook;
        _source = source;
        _source.AddHook(_hook);
    }

    private IntPtr OnHook(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg != WmNcHitTest || _disposed)
        {
            return IntPtr.Zero;
        }

        try
        {
            var packed = lParam.ToInt64();
            var screenX = (short)(packed & 0xFFFF);
            var screenY = (short)((packed >> 16) & 0xFFFF);
            var client = _window.PointFromScreen(new Point(screenX, screenY));
            var alpha = _alphaAtClient(client);
            handled = true;
            return new IntPtr(alpha < AlphaThreshold ? HtTransparent : HtClient);
        }
        catch (InvalidOperationException)
        {
            handled = false;
            return IntPtr.Zero;
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _window.SourceInitialized -= OnSourceInitialized;
        if (_source is not null && _hook is not null)
        {
            _source.RemoveHook(_hook);
        }

        _source = null;
        _hook = null;
    }
}
