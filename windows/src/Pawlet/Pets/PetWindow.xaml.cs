using System.Diagnostics;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using Pawlet.Core.Engine;

namespace Pawlet.Pets;

public partial class PetWindow : Window
{
    private readonly AtlasSheet _atlas;
    private readonly AnimationEngine _engine = new();
    private readonly DispatcherTimer _timer;
    private SpriteFrame _currentFrame = new(0, 0);
    private Point _dragOffset;
    private Point _dragStart;
    private bool _dragging;
    private bool _moved;
    private bool _alive = true;

    public PetWindow(AtlasSheet atlas)
    {
        ArgumentNullException.ThrowIfNull(atlas);
        _atlas = atlas;
        InitializeComponent();

        ShowActivated = false;
        Width = AtlasSheet.CellWidth;
        Height = AtlasSheet.CellHeight;
        SpriteImage.Source = _atlas.Frame(_currentFrame);

        HitTest.Attach(this, SampleAlpha);

        _timer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromMilliseconds(1000.0 / 30.0),
        };
        _timer.Tick += OnTick;
        _timer.Start();

        MouseLeftButtonDown += OnMouseLeftButtonDown;
        MouseMove += OnMouseMove;
        MouseLeftButtonUp += OnMouseLeftButtonUp;
        Closed += (_, _) => TearDown();
    }

    public AnimationEngine Engine => _engine;

    public bool Paused { get; set; }

    /// <summary>
    /// Stops the render timer and gates atlas callers so dispose cannot race
    /// a queued tick or <c>WM_NCHITTEST</c> sample.
    /// </summary>
    public void TearDown()
    {
        if (!_alive)
        {
            return;
        }

        _alive = false;
        _timer.Stop();
        _timer.Tick -= OnTick;
        SpriteImage.Source = null;
    }

    private void OnTick(object? sender, EventArgs e)
    {
        if (!_alive)
        {
            return;
        }

        var now = Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;
        var frame = _engine.Frame(now, paused: Paused);
        if (frame == _currentFrame)
        {
            return;
        }

        _currentFrame = frame;
        SpriteImage.Source = _atlas.Frame(frame);
    }

    private byte SampleAlpha(Point client)
    {
        if (!_alive)
        {
            return 0;
        }

        var x = (int)Math.Floor(client.X);
        var y = (int)Math.Floor(client.Y);
        return _atlas.AlphaAt(_currentFrame, x, y);
    }

    private void OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _dragging = true;
        _moved = false;
        _dragStart = PointToScreen(e.GetPosition(this));
        _dragOffset = e.GetPosition(this);
        CaptureMouse();
        e.Handled = true;
    }

    private void OnMouseMove(object sender, MouseEventArgs e)
    {
        if (!_dragging || e.LeftButton != MouseButtonState.Pressed)
        {
            return;
        }

        var screen = PointToScreen(e.GetPosition(this));
        if (!_moved)
        {
            var dx = screen.X - _dragStart.X;
            var dy = screen.Y - _dragStart.Y;
            if (dx * dx + dy * dy < 9)
            {
                return;
            }

            _moved = true;
        }

        Left = screen.X - _dragOffset.X;
        Top = screen.Y - _dragOffset.Y;
        e.Handled = true;
    }

    private void OnMouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (!_dragging)
        {
            return;
        }

        _dragging = false;
        ReleaseMouseCapture();

        if (!_moved && !Paused)
        {
            var now = Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;
            _engine.Perform(PetState.Waving, now);
            OnTick(null, EventArgs.Empty);
        }

        e.Handled = true;
    }
}
