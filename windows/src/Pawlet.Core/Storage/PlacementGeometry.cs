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

    /// <summary>
    /// Picks the work area that best contains the frame (max intersection).
    /// When the frame sits on no monitor (disconnected display), picks the nearest by center.
    /// </summary>
    public static (double Left, double Top, double Right, double Bottom)? PreferredWorkArea(
        double x,
        double y,
        double width,
        double height,
        IReadOnlyList<(double Left, double Top, double Right, double Bottom)> workAreas)
    {
        if (workAreas.Count == 0)
        {
            return null;
        }

        var bestArea = -1.0;
        var bestIndex = 0;
        for (var i = 0; i < workAreas.Count; i++)
        {
            var area = IntersectionArea(x, y, width, height, workAreas[i]);
            if (area > bestArea)
            {
                bestArea = area;
                bestIndex = i;
            }
        }

        if (bestArea > 0)
        {
            return workAreas[bestIndex];
        }

        var frameCx = x + width / 2;
        var frameCy = y + height / 2;
        var bestDist = double.PositiveInfinity;
        var nearest = 0;
        for (var i = 0; i < workAreas.Count; i++)
        {
            var w = workAreas[i];
            var dx = frameCx - (w.Left + w.Right) / 2;
            var dy = frameCy - (w.Top + w.Bottom) / 2;
            var dist = dx * dx + dy * dy;
            if (dist < bestDist)
            {
                bestDist = dist;
                nearest = i;
            }
        }

        return workAreas[nearest];
    }

    private static double IntersectionArea(
        double x,
        double y,
        double width,
        double height,
        (double Left, double Top, double Right, double Bottom) work)
    {
        var left = Math.Max(x, work.Left);
        var top = Math.Max(y, work.Top);
        var right = Math.Min(x + width, work.Right);
        var bottom = Math.Min(y + height, work.Bottom);
        var w = right - left;
        var h = bottom - top;
        return w > 0 && h > 0 ? w * h : 0;
    }
}
