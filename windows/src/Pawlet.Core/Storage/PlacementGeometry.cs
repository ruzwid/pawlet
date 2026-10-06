namespace Pawlet.Core.Storage;

/// <summary>Pure geometry helpers for pet window placement.</summary>
public static class PlacementGeometry
{
    /// <summary>
    /// Clamps an origin so a window of <paramref name="width"/>×<paramref name="height"/>
    /// stays inside the given work-area rectangle.
    /// </summary>
    public static (double X, double Y) ClampOriginToWorkArea(
        double x,
        double y,
        double width,
        double height,
        double workLeft,
        double workTop,
        double workRight,
        double workBottom)
    {
        var maxX = Math.Max(workLeft, workRight - width);
        var maxY = Math.Max(workTop, workBottom - height);
        return (
            Math.Min(maxX, Math.Max(workLeft, x)),
            Math.Min(maxY, Math.Max(workTop, y)));
    }

    /// <summary>
    /// True when the window fits in the work area, allowing <paramref name="slop"/> of edge noise.
    /// </summary>
    public static bool FrameFitsSafeArea(
        double x,
        double y,
        double width,
        double height,
        double workLeft,
        double workTop,
        double workRight,
        double workBottom,
        double slop = 0.5)
    {
        return x >= workLeft - slop
            && y >= workTop - slop
            && x + width <= workRight + slop
            && y + height <= workBottom + slop;
    }
}
