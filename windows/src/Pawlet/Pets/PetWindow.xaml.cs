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
    private readonly HitTestAttachment _hitTest;
    private SpriteFrame _currentFrame = new(0, 0);
    private Point _dragOffset;
    private Point _dragStart;
    private bool _dragging;
    private bool _moved;
    private bool _alive = true;
    private double _scale = 1.0;

    public PetWindow(AtlasSheet atlas)
    {
        ArgumentNullException.ThrowIfNull(atlas);
        _atlas = atlas;
        InitializeComponent();

        ShowActivated = false;
        ApplyScale(_scale);
        SpriteImage.Source = _atlas.Frame(_currentFrame);

        _hitTest = HitTestAttachment.Attach(this, SampleAlpha);

        _timer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromMilliseconds(1000.0 / 30.0),
        };
        _timer.Tick += OnTick;
        _timer.Start();

        MouseLeftButtonDown += OnMouseLeftButtonDown;
        MouseMove += OnMouseMove;
        MouseLeftButtonUp += OnMouseLeftButtonUp;
        MouseEnter += OnMouseEnter;
        Closed += (_, _) => TearDown();
    }

    public AnimationEngine Engine => _engine;

    public bool Paused { get; set; }

    public double Speed { get; set; } = 1.0;

    public double AnimationIntervalSeconds { get; set; } = MotionConstants.DefaultIntervalSeconds;

    public bool AnimateIdle { get; set; }

    public HoverReaction HoverReaction { get; set; } = HoverReaction.Wave;

    public bool ClickThrough { get; set; }

    public double Scale
    {
        get => _scale;
        set => ApplyScale(value);
    }

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
        _hitTest.Dispose();
        _timer.Stop();
        _timer.Tick -= OnTick;
        SpriteImage.Source = null;
    }

    private void ApplyScale(double scale)
    {
        _scale = Math.Min(
            MotionConstants.MaxPetScale,
            Math.Max(MotionConstants.MinPetScale, scale));
        Width = AtlasSheet.CellWidth * _scale;
        Height = AtlasSheet.CellHeight * _scale;
    }

    private void OnTick(object? sender, EventArgs e)
    {
        if (!_alive)
        {
            return;
        }

        var now = Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;
        var frame = _engine.Frame(
            now,
            paused: Paused,
            animateIdle: AnimateIdle,
            speed: Speed,
            animationInterval: AnimationIntervalSeconds);
        if (frame == _currentFrame)
        {
            return;
        }

        _currentFrame = frame;
        SpriteImage.Source = _atlas.Frame(frame);
    }

    private byte SampleAlpha(Point client)
    {
        if (!_alive || ClickThrough)
        {
            return 0;
        }

        var x = (int)Math.Floor(client.X / _scale);
        var y = (int)Math.Floor(client.Y / _scale);
        return _atlas.AlphaAt(_currentFrame, x, y);
    }

    private void OnMouseEnter(object sender, MouseEventArgs e)
    {
        if (!_alive || Paused || ClickThrough || _dragging)
        {
            return;
        }

        var now = Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;
        _engine.Greet(HoverReaction, now, Speed);
        OnTick(null, EventArgs.Empty);
    }

    private void OnMouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (ClickThrough)
        {
            return;
        }

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

        if (!_moved && !Paused && !ClickThrough)
        {
            var now = Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;
            _engine.Greet(HoverReaction, now, Speed);
            OnTick(null, EventArgs.Empty);
        }

        e.Handled = true;
    }
}
