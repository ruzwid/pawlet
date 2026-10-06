using System.Diagnostics;
using System.Runtime.InteropServices;
using Pawlet.Core.Storage;

namespace Pawlet.Pets;

/// <summary>
/// Enumerates top-level windows and picks the preferred app key for a pet frame's monitor
/// (topmost fullscreen, else topmost intersecting). No UI Automation / titles.
/// </summary>
internal static class MonitorTopApp
{
    private const int GwlExStyle = -20;
    private const int GwOwner = 4;
    private const int WsExToolWindow = 0x00000080;
    private const double FullscreenSlop = 2.0;

    /// <summary>
    /// Resolve a normalized main-module path for the topmost fullscreen (else topmost)
    /// app intersecting the monitor that best contains the pet frame. Null when none.
    /// </summary>
    public static string? PreferredAppKey(
        double left,
        double top,
        double width,
        double height,
        string? selfExe)
    {
        var bounds = PetWindow.AllMonitorBounds();
        var monitor = PlacementGeometry.PreferredWorkArea(left, top, width, height, bounds);
        if (monitor is null)
        {
            return null;
        }

        var candidates = EnumerateCandidates(bounds);
        return PlacementGeometry.PreferredAppKey(
            monitor.Value.Left,
            monitor.Value.Top,
            monitor.Value.Right,
            monitor.Value.Bottom,
            candidates,
            selfExe);
    }

    private static List<PlacementWindowCandidate> EnumerateCandidates(
        IReadOnlyList<(double Left, double Top, double Right, double Bottom)> monitorBounds)
    {
        var (scaleX, scaleY) = PetWindow.DipScaleFromPrimary();
        var selfPid = (uint)Process.GetCurrentProcess().Id;
        var list = new List<PlacementWindowCandidate>();
        var z = 0;

        EnumWindows((hwnd, _) =>
        {
            if (!IsWindowVisible(hwnd))
            {
                return true;
            }

            if (GetWindow(hwnd, GwOwner) != IntPtr.Zero)
            {
                return true;
            }

            var exStyle = GetWindowLongPtr(hwnd, GwlExStyle).ToInt64();
            if ((exStyle & WsExToolWindow) != 0)
            {
                return true;
            }

            GetWindowThreadProcessIdNative(hwnd, out var processId);
            if (processId == 0 || processId == selfPid)
            {
                return true;
            }

            var path = ProcessMainModule.TryGetPath((int)processId);
            if (string.IsNullOrEmpty(path))
            {
                return true;
            }

            if (!GetWindowRect(hwnd, out var rect))
            {
                return true;
            }

            var l = rect.Left * scaleX;
            var t = rect.Top * scaleY;
            var r = rect.Right * scaleX;
            var b = rect.Bottom * scaleY;
            var fs = IsFullscreen(l, t, r, b, monitorBounds);
            list.Add(new PlacementWindowCandidate(path, l, t, r, b, z, fs));
            z++;
            return true;
        }, IntPtr.Zero);

        return list;
    }

    private static bool IsFullscreen(
        double left,
        double top,
        double right,
        double bottom,
        IReadOnlyList<(double Left, double Top, double Right, double Bottom)> monitors)
    {
        for (var i = 0; i < monitors.Count; i++)
        {
            var m = monitors[i];
            if (Math.Abs(left - m.Left) <= FullscreenSlop
                && Math.Abs(top - m.Top) <= FullscreenSlop
                && Math.Abs(right - m.Right) <= FullscreenSlop
                && Math.Abs(bottom - m.Bottom) <= FullscreenSlop)
            {
                return true;
            }
        }

        return false;
    }

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern IntPtr GetWindow(IntPtr hWnd, int uCmd);

    [DllImport("user32.dll", EntryPoint = "GetWindowThreadProcessId")]
    private static extern uint GetWindowThreadProcessIdNative(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowRect(IntPtr hWnd, out RectL lpRect);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex) =>
        IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, nIndex) : GetWindowLongPtr32(hWnd, nIndex);

    [StructLayout(LayoutKind.Sequential)]
    private struct RectL
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
