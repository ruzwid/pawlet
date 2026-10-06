using Pawlet.Core.Engine;
using Pawlet.Core.Storage;

namespace Pawlet.Tests;

public class PlacementStoreTests
{
    [Fact]
    public void IsTrackable_rejects_null_empty_and_self()
    {
        var self = Path.GetFullPath(@"C:\Apps\Pawlet\Pawlet.exe");
        Assert.False(PlacementStore.IsTrackable(null, self));
        Assert.False(PlacementStore.IsTrackable("", self));
        Assert.False(PlacementStore.IsTrackable(self, self));
        Assert.True(PlacementStore.IsTrackable(
            Path.GetFullPath(@"C:\Program Files\Google\Chrome\Application\chrome.exe"), self));
    }

    [Fact]
    public void IsTrackable_fails_closed_when_self_unresolvable()
    {
        var chrome = Path.GetFullPath(@"C:\Program Files\Google\Chrome\Application\chrome.exe");
        Assert.False(PlacementStore.IsTrackable(chrome, ""));
        Assert.False(PlacementStore.IsTrackable(chrome, "   "));
    }

    [Fact]
    public void Incomplete_origin_does_not_restore()
    {
        var path = TempPlacementsPath();
        try
        {
            var store = PlacementStore.Load(path);
            store.WriteGlobalOrigin("mochi", 10, double.NaN);
            PlacementStore.Save(store, path);
            var reloaded = PlacementStore.Load(path);
            Assert.Null(reloaded.RememberedGlobalOrigin("mochi"));
        }
        finally
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
    }

    [Fact]
    public void App_origin_and_size_round_trip_and_resolved_scale()
    {
        var path = TempPlacementsPath();
        var chrome = Path.GetFullPath(@"C:\Program Files\Google\Chrome\Application\chrome.exe");
        try
        {
            var store = PlacementStore.Load(path);
            store.WriteGlobalOrigin("mochi", 100, 200);
            store.WriteAppOrigin("mochi", chrome, 10, 20);
            store.WritePetSize("mochi", 1.25);
            store.WriteAppSize("mochi", chrome, 0.5);
            PlacementStore.Save(store, path);

            var reloaded = PlacementStore.Load(path);
            var global = reloaded.RememberedGlobalOrigin("mochi");
            Assert.NotNull(global);
            Assert.Equal(100, global.Value.X);
            Assert.Equal(200, global.Value.Y);

            var appOrigin = reloaded.RememberedAppOrigin("mochi", chrome);
            Assert.NotNull(appOrigin);
            Assert.Equal(10, appOrigin.Value.X);
            Assert.Equal(20, appOrigin.Value.Y);

            Assert.Equal(0.5, reloaded.RememberedAppSize("mochi", chrome));
            Assert.Equal(1.25, reloaded.RememberedPetSize("mochi"));

            Assert.Equal(
                0.5,
                reloaded.ResolvedScale("mochi", rememberPerApp: true, chrome, settingsScale: 1.0));
            Assert.Equal(
                1.25,
                reloaded.ResolvedScale("mochi", rememberPerApp: false, chrome, settingsScale: 1.0));
            Assert.Equal(
                1.0,
                PlacementStore.Load(path).ResolvedScale("missing", rememberPerApp: false, null, settingsScale: 1.0));

            reloaded.ClearAppSize("mochi", chrome);
            PlacementStore.Save(reloaded, path);
            var afterClear = PlacementStore.Load(path);
            Assert.Null(afterClear.RememberedAppSize("mochi", chrome));
            Assert.Equal(1.25, afterClear.RememberedPetSize("mochi"));
            Assert.Equal(
                1.25,
                afterClear.ResolvedScale("mochi", rememberPerApp: true, chrome, settingsScale: 1.0));
        }
        finally
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
    }

    [Fact]
    public void Load_missing_or_corrupt_returns_empty_store()
    {
        var missing = TempPlacementsPath();
        var empty = PlacementStore.Load(missing);
        Assert.Null(empty.RememberedGlobalOrigin("mochi"));
        Assert.Equal(
            MotionConstants.MinPetScale,
            empty.ResolvedScale("mochi", rememberPerApp: false, null, settingsScale: 0.1));

        var corrupt = TempPlacementsPath();
        try
        {
            File.WriteAllText(corrupt, "{not json");
            var loaded = PlacementStore.Load(corrupt);
            Assert.Null(loaded.RememberedGlobalOrigin("mochi"));
        }
        finally
        {
            if (File.Exists(corrupt))
            {
                File.Delete(corrupt);
            }
        }
    }

    [Fact]
    public void Write_size_clamps_and_ignores_non_finite()
    {
        var path = TempPlacementsPath();
        try
        {
            var store = PlacementStore.Load(path);
            store.WritePetSize("mochi", 9);
            store.WriteAppSize("mochi", @"C:\Apps\Slack\slack.exe", 0.05);
            Assert.Equal(MotionConstants.MaxPetScale, store.RememberedPetSize("mochi"));
            Assert.Equal(MotionConstants.MinPetScale, store.RememberedAppSize("mochi", @"C:\Apps\Slack\slack.exe"));

            store.WritePetSize("mochi", double.NaN);
            Assert.Equal(MotionConstants.MaxPetScale, store.RememberedPetSize("mochi"));
        }
        finally
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
    }

    private static string TempPlacementsPath() =>
        Path.Combine(Path.GetTempPath(), "pawlet-placements-" + Guid.NewGuid().ToString("N") + ".json");
}
