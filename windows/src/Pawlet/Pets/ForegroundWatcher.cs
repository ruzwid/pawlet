using System.Runtime.InteropServices;
using System.Windows;

namespace Pawlet.Pets;

/// <summary>
/// Watches the system foreground window and raises <see cref="Changed"/> with a
/// normalized main-module path (or null when unreadable). Fail-soft if the hook
/// cannot be registered.
/// </summary>
public sealed class ForegroundWatcher : IDisposable
{
    private const uint EventSystemForeground = 0x0003;
    private const uint WinEventOutOfContext = 0;

    // Rooted so the GC cannot collect the WinEvent callback.
    private readonly WinEventProc _callback;
    private IntPtr _hook;
    private bool _disposed;

    public event Action<string?>? Changed;

    public ForegroundWatcher()
    {
        _callback = OnWinEvent;
        try
        {
            _hook = SetWinEventHook(
                EventSystemForeground,
                EventSystemForeground,
                IntPtr.Zero,
                _callback,
                0,
                0,
                WinEventOutOfContext);
        }
        catch (Exception)
        {
            _hook = IntPtr.Zero;
        }

        // Hook only fires on changes; seed so restore/stamp work before the first Alt-Tab.
        SeedCurrentForeground();
    }

    private void SeedCurrentForeground()
    {
        if (_disposed)
        {
            return;
        }

        // Always queue: App subscribes to Changed after `new ForegroundWatcher()`.
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null)
        {
            return;
        }

        dispatcher.BeginInvoke(new Action(() =>
        {
            if (_disposed)
            {
                return;
            }

            var foreground = GetForegroundWindow();
            RaiseChanged(foreground == IntPtr.Zero ? null : ResolvePath(foreground));
        }));
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        if (_hook != IntPtr.Zero)
        {
            UnhookWinEvent(_hook);
            _hook = IntPtr.Zero;
        }
    }

    private void OnWinEvent(
        IntPtr hWinEventHook,
        uint eventType,
        IntPtr hwnd,
        int idObject,
        int idChild,
        uint dwEventThread,
        uint dwmsEventTime)
    {
        if (_disposed)
        {
            return;
        }

        // Null HWND during activation: ignore / stay (do not raise).
        var foreground = GetForegroundWindow();
        if (foreground == IntPtr.Zero)
        {
            return;
        }

        var path = ResolvePath(foreground);
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null)
        {
            return;
        }

        if (dispatcher.CheckAccess())
        {
            RaiseChanged(path);
        }
        else
        {
            dispatcher.BeginInvoke(new Action(() => RaiseChanged(path)));
        }
    }

    private void RaiseChanged(string? path)
    {
        if (_disposed)
        {
            return;
        }

        Changed?.Invoke(path);
    }

    private static string? ResolvePath(IntPtr hwnd)
    {
        _ = GetWindowThreadProcessId(hwnd, out var processId);
        return ProcessMainModule.TryGetPath((int)processId);
    }

    private delegate void WinEventProc(
        IntPtr hWinEventHook,
        uint eventType,
        IntPtr hwnd,
        int idObject,
        int idChild,
        uint dwEventThread,
        uint dwmsEventTime);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWinEventHook(
        uint eventMin,
        uint eventMax,
        IntPtr hmodWinEventProc,
        WinEventProc lpfnWinEventProc,
        uint idProcess,
        uint idThread,
        uint dwFlags);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWinEvent(IntPtr hWinEventHook);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
