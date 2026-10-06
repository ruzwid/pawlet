namespace Pawlet.Core.Storage;

/// <summary>
/// Picks which app key stamps/reads per-app placement during pet interaction
/// (drag end, context Size), falling back to the last trackable app when the
/// current foreground is self or unreadable.
/// </summary>
public static class PlacementStampKey
{
    /// <param name="current">Normalized current foreground key (or null).</param>
    /// <param name="lastTrackable">Last non-self trackable key (or null).</param>
    /// <param name="self">Normalized Pawlet exe path (or null if unresolvable).</param>
    /// <param name="isDragging">When true, ignore current and keep the pinned last trackable.</param>
    public static string? Select(
        string? current,
        string? lastTrackable,
        string? self,
        bool isDragging)
    {
        if (PlacementStore.NormalizeAppKey(self) is null)
        {
            return null;
        }

        if (isDragging)
        {
            return lastTrackable;
        }

        if (PlacementStore.IsTrackable(current, self!))
        {
            return PlacementStore.NormalizeAppKey(current);
        }

        return lastTrackable;
    }
}
