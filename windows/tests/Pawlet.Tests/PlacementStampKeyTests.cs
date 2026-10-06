using Pawlet.Core.Storage;

namespace Pawlet.Tests;

public class PlacementStampKeyTests
{
    private static readonly string Self = Path.GetFullPath(@"C:\Apps\Pawlet\Pawlet.exe");
    private static readonly string Slack = Path.GetFullPath(@"C:\Apps\Slack\slack.exe");
    private static readonly string Chrome = Path.GetFullPath(@"C:\Program Files\Google\Chrome\Application\chrome.exe");

    [Fact]
    public void Select_prefers_current_when_trackable()
    {
        Assert.Equal(Slack, PlacementStampKey.Select(Slack, Chrome, Self, isDragging: false));
        // Trackable current wins even while dragging.
        Assert.Equal(Chrome, PlacementStampKey.Select(Chrome, Slack, Self, isDragging: true));
    }

    [Fact]
    public void Select_returns_null_when_library_frontmost_and_not_dragging()
    {
        Assert.Null(PlacementStampKey.Select(Self, Slack, Self, isDragging: false));
        Assert.Null(PlacementStampKey.Select(null, Slack, Self, isDragging: false));
    }

    [Fact]
    public void Select_pins_last_trackable_while_dragging_and_current_untrackable()
    {
        Assert.Equal(Slack, PlacementStampKey.Select(Self, Slack, Self, isDragging: true));
        Assert.Equal(Slack, PlacementStampKey.Select(null, Slack, Self, isDragging: true));
        Assert.Null(PlacementStampKey.Select(Self, null, Self, isDragging: true));
    }

    [Fact]
    public void Select_returns_null_when_self_unresolvable()
    {
        Assert.Null(PlacementStampKey.Select(Slack, Slack, self: null, isDragging: false));
        Assert.Null(PlacementStampKey.Select(Slack, Slack, self: "", isDragging: false));
    }
}

public class PlacementGeometryTests
{
    [Fact]
    public void ClampOriginToWorkArea_keeps_window_inside_bounds()
    {
        var (x, y) = PlacementGeometry.ClampOriginToWorkArea(
            x: -50, y: 900, width: 100, height: 100,
            workLeft: 0, workTop: 0, workRight: 800, workBottom: 600);
        Assert.Equal(0, x);
        Assert.Equal(500, y);
    }

    [Fact]
    public void ClampOriginToWorkArea_leaves_in_bounds_unchanged()
    {
        var (x, y) = PlacementGeometry.ClampOriginToWorkArea(
            x: 40, y: 60, width: 100, height: 80,
            workLeft: 0, workTop: 0, workRight: 800, workBottom: 600);
        Assert.Equal(40, x);
        Assert.Equal(60, y);
    }

    [Fact]
    public void FrameFitsSafeArea_allows_sub_point_edge_slop()
    {
        Assert.True(PlacementGeometry.FrameFitsSafeArea(
            x: 0, y: -0.25, width: 100, height: 80,
            workLeft: 0, workTop: 0, workRight: 800, workBottom: 600));
        Assert.False(PlacementGeometry.FrameFitsSafeArea(
            x: 0, y: -8, width: 100, height: 80,
            workLeft: 0, workTop: 0, workRight: 800, workBottom: 600));
    }

    [Fact]
    public void PreferredWorkArea_picks_secondary_when_frame_lives_there()
    {
        var primary = (Left: 0d, Top: 0d, Right: 1920d, Bottom: 1080d);
        var secondary = (Left: 1920d, Top: 0d, Right: 3840d, Bottom: 1080d);
        var preferred = PlacementGeometry.PreferredWorkArea(
            x: 2500, y: 100, width: 192, height: 208,
            workAreas: [primary, secondary]);
        Assert.Equal(secondary, preferred);
    }

    [Fact]
    public void PreferredWorkArea_picks_primary_when_frame_lives_there()
    {
        var primary = (Left: 0d, Top: 0d, Right: 1920d, Bottom: 1080d);
        var secondary = (Left: 1920d, Top: 0d, Right: 3840d, Bottom: 1080d);
        var preferred = PlacementGeometry.PreferredWorkArea(
            x: 40, y: 60, width: 192, height: 208,
            workAreas: [primary, secondary]);
        Assert.Equal(primary, preferred);
    }

    [Fact]
    public void ClampOrigin_on_secondary_stays_on_secondary()
    {
        var primary = (Left: 0d, Top: 0d, Right: 1920d, Bottom: 1080d);
        var secondary = (Left: 1920d, Top: 0d, Right: 3840d, Bottom: 1080d);
        var work = PlacementGeometry.PreferredWorkArea(
            x: 2500, y: 100, width: 192, height: 208,
            workAreas: [primary, secondary])!.Value;
        var (x, y) = PlacementGeometry.ClampOriginToWorkArea(
            2500, 100, 192, 208, work.Left, work.Top, work.Right, work.Bottom);
        Assert.Equal(2500, x);
        Assert.Equal(100, y);
        Assert.True(x >= secondary.Left);
    }

    [Fact]
    public void PreferredWorkArea_when_disconnected_picks_nearest()
    {
        var primary = (Left: 0d, Top: 0d, Right: 1920d, Bottom: 1080d);
        var secondary = (Left: 1920d, Top: 0d, Right: 3840d, Bottom: 1080d);
        // Saved on a monitor that is gone (far right of old layout).
        var preferred = PlacementGeometry.PreferredWorkArea(
            x: 5000, y: 100, width: 192, height: 208,
            workAreas: [primary, secondary]);
        Assert.Equal(secondary, preferred);
    }

    private const string SelfKey = @"C:\Apps\Pawlet\Pawlet.exe";
    private const string CursorKey = @"C:\Apps\Cursor\Cursor.exe";
    private const string ChromeKey = @"C:\Program Files\Google\Chrome\Application\chrome.exe";
    private const string SlackKey = @"C:\Apps\Slack\slack.exe";

    [Fact]
    public void PreferredAppKey_fullscreen_beats_windowed_on_same_monitor()
    {
        var cursorFs = new PlacementWindowCandidate(
            CursorKey, 0, 0, 1920, 1080, ZOrder: 1, IsFullscreen: true);
        var chromeWin = new PlacementWindowCandidate(
            ChromeKey, 100, 100, 900, 700, ZOrder: 0, IsFullscreen: false);
        Assert.Equal(
            CursorKey,
            PlacementGeometry.PreferredAppKey(0, 0, 1920, 1080, [chromeWin, cursorFs], SelfKey));
    }

    [Fact]
    public void PreferredAppKey_ignores_fullscreen_on_other_monitor()
    {
        var cursorFs = new PlacementWindowCandidate(
            CursorKey, 0, 0, 1920, 1080, ZOrder: 1, IsFullscreen: true);
        var chromeOther = new PlacementWindowCandidate(
            ChromeKey, 2000, 100, 2800, 700, ZOrder: 0, IsFullscreen: true);
        Assert.Equal(
            CursorKey,
            PlacementGeometry.PreferredAppKey(0, 0, 1920, 1080, [chromeOther, cursorFs], SelfKey));
    }

    [Fact]
    public void PreferredAppKey_topmost_wins_when_no_fullscreen()
    {
        var slackWin = new PlacementWindowCandidate(
            SlackKey, 50, 50, 950, 750, ZOrder: 0, IsFullscreen: false);
        var cursorWin = new PlacementWindowCandidate(
            CursorKey, 200, 200, 900, 700, ZOrder: 1, IsFullscreen: false);
        Assert.Equal(
            SlackKey,
            PlacementGeometry.PreferredAppKey(0, 0, 1920, 1080, [slackWin, cursorWin], SelfKey));
    }

    [Fact]
    public void PreferredAppKey_returns_null_when_no_intersection()
    {
        var chromeOther = new PlacementWindowCandidate(
            ChromeKey, 2000, 100, 2800, 700, ZOrder: 0, IsFullscreen: true);
        Assert.Null(
            PlacementGeometry.PreferredAppKey(0, 0, 1920, 1080, [chromeOther], SelfKey));
    }

    [Fact]
    public void PreferredAppKey_skips_self()
    {
        var pawlet = new PlacementWindowCandidate(
            SelfKey, 0, 0, 1920, 1080, ZOrder: 0, IsFullscreen: true);
        var slackWin = new PlacementWindowCandidate(
            SlackKey, 50, 50, 950, 750, ZOrder: 1, IsFullscreen: false);
        Assert.Equal(
            SlackKey,
            PlacementGeometry.PreferredAppKey(0, 0, 1920, 1080, [pawlet, slackWin], SelfKey));
    }
}
