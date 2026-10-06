using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Pawlet.Core.Engine;
using Pawlet.Core.Storage;

namespace Pawlet.Pets;

public partial class PetWindow : Window
{
    private const int GwlExStyle = -20;
    private const int WsExNoActivate = 0x08000000;

    private static readonly double[] SizeSteps =
    [
        0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75,
    ];

    private static readonly TimeSpan PlacementFadeDuration = TimeSpan.FromSeconds(0.15);

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
    private int _placementGeneration;

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

    public bool IsDragging => _dragging;

    /// <summary>True while a placement fade is in flight.</summary>
    public bool PlacementTransitionActive { get; private set; }

    /// <summary>Invoked on drag end when the window actually moved (stamp app origin).</summary>
    public Action? OnDragEnded { get; set; }

    /// <summary>Effective scale for Size menu check marks.</summary>
    public Func<double>? ResolveEffectiveScale { get; set; }

    /// <summary>Size menu: set override, or null to clear (Use default size).</summary>
    public Action<double?>? OnSetSizeOverride { get; set; }

    public double Scale
    {
        get => _scale;
        set => ApplyScale(value);
    }

    /// <summary>
    /// Clamp a screen origin so the pet stays inside the primary work area.
    /// </summary>
    public static Point ClampOriginToWorkArea(double x, double y, double width, double height)
    {
        var work = SystemParameters.WorkArea;
        var (cx, cy) = PlacementGeometry.ClampOriginToWorkArea(
            x, y, width, height, work.Left, work.Top, work.Right, work.Bottom);
        return new Point(cx, cy);
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);

        // ShowActivated=false only covers the first Show; OR WS_EX_NOACTIVATE so
        // click/drag/context menu do not steal foreground from the user's app.
        var hwnd = new WindowInteropHelper(this).Handle;
        var exStyle = GetWindowLongPtr(hwnd, GwlExStyle).ToInt64();
        _ = SetWindowLongPtr(hwnd, GwlExStyle, (IntPtr)(exStyle | WsExNoActivate));
    }

    /// <summary>
    /// Apply remembered origin/scale with a short opacity fade, or snap when client-area animations are off.
    /// </summary>
    public void ApplyRememberedPlacement(Point? origin, double? scale, double settingsOpacity)
    {
        var targetScale = scale is { } s
            ? Math.Min(MotionConstants.MaxPetScale, Math.Max(MotionConstants.MinPetScale, s))
            : _scale;
        var width = AtlasSheet.CellWidth * targetScale;
        var height = AtlasSheet.CellHeight * targetScale;

        double? targetLeft = null;
        double? targetTop = null;
        if (origin is { } point)
        {
            // Keep a flush-edge stamp put when it still fits (same Cmd-Tab drift as Mac).
            var work = SystemParameters.WorkArea;
            if (PlacementGeometry.FrameFitsSafeArea(
                    point.X, point.Y, width, height,
                    work.Left, work.Top, work.Right, work.Bottom))
            {
                targetLeft = point.X;
                targetTop = point.Y;
            }
            else
            {
                var clamped = ClampOriginToWorkArea(point.X, point.Y, width, height);
                targetLeft = clamped.X;
                targetTop = clamped.Y;
            }
        }

        var originChanges = targetLeft is { } left
            && targetTop is { } top
            && (Math.Abs(Left - left) > 0.5 || Math.Abs(Top - top) > 0.5);
        var scaleChanges = scale is not null && Math.Abs(_scale - targetScale) > 0.001;
        if (!originChanges && !scaleChanges)
        {
            // Mid-fade geometry is not applied yet. Cancel so a stale target cannot land
            // after a no-op switch (stay / same coords as pre-fade).
            if (PlacementTransitionActive)
            {
                _placementGeneration++;
                CancelPlacementAnimation();
                Opacity = settingsOpacity;
                PlacementTransitionActive = false;
            }

            return;
        }

        void ApplyGeometry()
        {
            if (targetLeft is { } left && targetTop is { } top)
            {
                Left = left;
                Top = top;
            }

            if (scale is not null)
            {
                ApplyScale(targetScale);
            }
        }

        // Never fade before first Show: window is not loaded/visible yet.
        if (!SystemParameters.ClientAreaAnimation || !IsLoaded || !IsVisible)
        {
            CancelPlacementAnimation();
            ApplyGeometry();
            Opacity = settingsOpacity;
            PlacementTransitionActive = false;
            return;
        }

        var generation = ++_placementGeneration;
        PlacementTransitionActive = true;
        BeginAnimation(OpacityProperty, null);

        var fadeOut = new DoubleAnimation(Opacity, 0, PlacementFadeDuration)
        {
            FillBehavior = FillBehavior.Stop,
        };
        fadeOut.Completed += (_, _) =>
        {
            if (!_alive || generation != _placementGeneration)
            {
                return;
            }

            Opacity = 0;
            ApplyGeometry();

            var fadeIn = new DoubleAnimation(0, settingsOpacity, PlacementFadeDuration)
            {
                FillBehavior = FillBehavior.Stop,
            };
            fadeIn.Completed += (_, _) =>
            {
                if (!_alive || generation != _placementGeneration)
                {
                    return;
                }

                BeginAnimation(OpacityProperty, null);
                Opacity = settingsOpacity;
                PlacementTransitionActive = false;
            };
            BeginAnimation(OpacityProperty, fadeIn);
        };
        BeginAnimation(OpacityProperty, fadeOut);
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
        _placementGeneration++;
        CancelPlacementAnimation();
        PlacementTransitionActive = false;
        _hitTest.Dispose();
        _timer.Stop();
        _timer.Tick -= OnTick;
        SpriteImage.Source = null;
    }

    private void CancelPlacementAnimation()
    {
        BeginAnimation(OpacityProperty, null);
    }

    private void ApplyScale(double scale)
    {
        _scale = Math.Min(
            MotionConstants.MaxPetScale,
            Math.Max(MotionConstants.MinPetScale, scale));
        Width = AtlasSheet.CellWidth * _scale;
        Height = AtlasSheet.CellHeight * _scale;
    }

    private void OnContextMenuOpened(object sender, RoutedEventArgs e)
    {
        SizeMenuItem.Items.Clear();
        var effective = ResolveEffectiveScale?.Invoke() ?? _scale;
        var checkedPercent = (int)Math.Round(effective * 100);

        foreach (var step in SizeSteps)
        {
            var percent = (int)Math.Round(step * 100);
            var item = new MenuItem
            {
                Header = $"{percent}%",
                IsCheckable = true,
                IsChecked = percent == checkedPercent,
                Tag = step,
            };
            item.Click += OnSizeStepClick;
            SizeMenuItem.Items.Add(item);
        }

        SizeMenuItem.Items.Add(new Separator());
        var useDefault = new MenuItem { Header = "Use default size" };
        useDefault.Click += OnUseDefaultSizeClick;
        SizeMenuItem.Items.Add(useDefault);
    }

    private void OnSizeStepClick(object sender, RoutedEventArgs e)
    {
        if (sender is MenuItem { Tag: double step })
        {
            OnSetSizeOverride?.Invoke(step);
        }
    }

    private void OnUseDefaultSizeClick(object sender, RoutedEventArgs e)
    {
        OnSetSizeOverride?.Invoke(null);
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

        try
        {
            // Stamp while still dragging so PlacementStampKey keeps the drag pin.
            if (_moved)
            {
                OnDragEnded?.Invoke();
            }
            else if (!Paused && !ClickThrough)
            {
                var now = Stopwatch.GetTimestamp() / (double)Stopwatch.Frequency;
                _engine.Greet(HoverReaction, now, Speed);
                OnTick(null, EventArgs.Empty);
            }
        }
        finally
        {
            _dragging = false;
            ReleaseMouseCapture();
        }

        e.Handled = true;
    }

    [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr32(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex) =>
        IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, nIndex) : GetWindowLongPtr32(hWnd, nIndex);

    private static IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong) =>
        IntPtr.Size == 8 ? SetWindowLongPtr64(hWnd, nIndex, dwNewLong) : SetWindowLongPtr32(hWnd, nIndex, dwNewLong);
}
