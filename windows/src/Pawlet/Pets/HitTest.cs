using System.Windows;
using System.Windows.Interop;

namespace Pawlet.Pets;

/// <summary>Selective click-through via <c>WM_NCHITTEST</c> and per-pixel alpha.</summary>
public static class HitTest
{
    public const int AlphaThreshold = 16;

    private const int WmNcHitTest = 0x0084;
    private const int HtTransparent = -1;
    private const int HtClient = 1;

    /// <summary>
    /// Hooks the window so transparent padding (alpha below <see cref="AlphaThreshold"/>)
    /// returns <c>HTTRANSPARENT</c>; opaque pixels return <c>HTCLIENT</c>.
    /// </summary>
    /// <param name="window">Borderless transparent pet window.</param>
    /// <param name="alphaAtClient">Alpha (0–255) at client DIP coordinates.</param>
    public static void Attach(Window window, Func<Point, byte> alphaAtClient)
    {
        ArgumentNullException.ThrowIfNull(window);
        ArgumentNullException.ThrowIfNull(alphaAtClient);

        if (window.IsLoaded)
        {
            Hook(window, alphaAtClient);
        }
        else
        {
            window.SourceInitialized += (_, _) => Hook(window, alphaAtClient);
        }
    }

    private static void Hook(Window window, Func<Point, byte> alphaAtClient)
    {
        var helper = new WindowInteropHelper(window);
        if (helper.Handle == IntPtr.Zero)
        {
            return;
        }

        var source = HwndSource.FromHwnd(helper.Handle);
        source?.AddHook((IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled) =>
        {
            if (msg != WmNcHitTest)
            {
                return IntPtr.Zero;
            }

            var packed = lParam.ToInt64();
            var screenX = (short)(packed & 0xFFFF);
            var screenY = (short)((packed >> 16) & 0xFFFF);
            var screen = new Point(screenX, screenY);
            var client = window.PointFromScreen(screen);
            var alpha = alphaAtClient(client);
            handled = true;
            return new IntPtr(alpha < AlphaThreshold ? HtTransparent : HtClient);
        });
    }
}
