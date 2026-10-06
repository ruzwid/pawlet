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
}
