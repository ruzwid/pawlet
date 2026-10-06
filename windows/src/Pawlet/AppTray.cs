using System.Drawing;
using System.Windows.Forms;
using WpfApp = System.Windows.Application;
using WpfMessageBox = System.Windows.MessageBox;
using WpfMessageBoxButton = System.Windows.MessageBoxButton;
using WpfMessageBoxImage = System.Windows.MessageBoxImage;

namespace Pawlet;

/// <summary>WinForms tray icon so the process can outlive pet windows.</summary>
public sealed class AppTray : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly Icon _ownedIcon;
    private readonly ToolStripMenuItem _pauseItem;
    private readonly Func<bool> _isPaused;
    private readonly Action<bool> _setPaused;
    private bool _disposed;

    public AppTray(
        Action showAll,
        Action hideAll,
        Func<bool> isPaused,
        Action<bool> setPaused,
        Action quit)
    {
        ArgumentNullException.ThrowIfNull(showAll);
        ArgumentNullException.ThrowIfNull(hideAll);
        ArgumentNullException.ThrowIfNull(isPaused);
        ArgumentNullException.ThrowIfNull(setPaused);
        ArgumentNullException.ThrowIfNull(quit);

        _isPaused = isPaused;
        _setPaused = setPaused;
        _ownedIcon = (Icon)SystemIcons.Application.Clone();

        _pauseItem = new ToolStripMenuItem("Pause")
        {
            CheckOnClick = true,
            Checked = isPaused(),
        };
        _pauseItem.Click += (_, _) => Dispatch(() => _setPaused(_pauseItem.Checked));

        var menu = new ContextMenuStrip();
        menu.Items.Add("Show library", null, (_, _) => Dispatch(ShowLibraryStub));
        menu.Items.Add("Show all", null, (_, _) => Dispatch(showAll));
        menu.Items.Add("Hide all", null, (_, _) => Dispatch(hideAll));
        menu.Items.Add(_pauseItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => Dispatch(quit));
        menu.Opening += (_, _) => _pauseItem.Checked = _isPaused();

        _icon = new NotifyIcon
        {
            Icon = _ownedIcon,
            Text = "Pawlet",
            Visible = true,
            ContextMenuStrip = menu,
        };
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _icon.Visible = false;
        _icon.Dispose();
        _ownedIcon.Dispose();
    }

    private static void ShowLibraryStub()
    {
        WpfMessageBox.Show(
            "Library UI is not in this build yet.",
            "Pawlet",
            WpfMessageBoxButton.OK,
            WpfMessageBoxImage.Information);
    }

    private static void Dispatch(Action action)
    {
        var dispatcher = WpfApp.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
        {
            action();
            return;
        }

        dispatcher.Invoke(action);
    }
}
