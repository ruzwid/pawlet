namespace Pawlet.Core.Storage;

/// <summary>
/// Picks which app key stamps/reads per-app placement during pet interaction
/// (drag end, context Size). Trackable current wins; last trackable is used
/// only while a drag/size pin is active; otherwise null (global / pet-level).
/// </summary>
public static class PlacementStampKey
{
    /// <param name="current">Normalized current foreground key (or null).</param>
    /// <param name="lastTrackable">Last non-self trackable key (or null).</param>
    /// <param name="self">Normalized Pawlet exe path (or null if unresolvable).</param>
    /// <param name="isDragging">When true and current is not trackable, pin last trackable.</param>
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

        if (PlacementStore.IsTrackable(current, self!))
        {
            return PlacementStore.NormalizeAppKey(current);
        }

        if (isDragging)
        {
            return lastTrackable;
        }

        return null;
    }
}
