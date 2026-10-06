using Pawlet.Core.Engine;
using Pawlet.Core.Storage;

namespace Pawlet.Tests;

public class SettingsStoreTests
{
    [Fact]
    public void Round_trips_all_fields_through_json()
    {
        var path = Path.Combine(Path.GetTempPath(), "pawlet-settings-" + Guid.NewGuid().ToString("N") + ".json");
        try
        {
            var original = new SettingsModel
            {
                Scale = 1.25,
                Opacity = 0.8,
                Speed = 1.5,
                Pause = true,
                AnimateIdle = true,
                HoverReaction = HoverReaction.Hop,
                AnimationIntervalSeconds = 20,
                ClickThrough = true,
                StartWithWindows = true,
            };

            SettingsStore.Save(original, path);
            var loaded = SettingsStore.Load(path);

            Assert.Equal(1.25, loaded.Scale);
            Assert.Equal(0.8, loaded.Opacity);
            Assert.Equal(1.5, loaded.Speed);
            Assert.True(loaded.Pause);
            Assert.True(loaded.AnimateIdle);
            Assert.Equal(HoverReaction.Hop, loaded.HoverReaction);
            Assert.Equal(20, loaded.AnimationIntervalSeconds);
            Assert.True(loaded.ClickThrough);
            Assert.True(loaded.StartWithWindows);
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
    public void Load_missing_file_returns_defaults()
    {
        var path = Path.Combine(Path.GetTempPath(), "pawlet-missing-" + Guid.NewGuid().ToString("N") + ".json");
        var loaded = SettingsStore.Load(path);
        Assert.Equal(1.0, loaded.Scale);
        Assert.Equal(HoverReaction.Wave, loaded.HoverReaction);
        Assert.False(loaded.Pause);
        Assert.False(loaded.AnimateIdle);
        Assert.False(loaded.StartWithWindows);
    }

    [Fact]
    public void Load_clamps_out_of_range_scale()
    {
        var path = Path.Combine(Path.GetTempPath(), "pawlet-clamp-" + Guid.NewGuid().ToString("N") + ".json");
        try
        {
            File.WriteAllText(path, """{"scale":0.1,"opacity":0.05,"speed":9,"animationIntervalSeconds":999}""");
            var loaded = SettingsStore.Load(path);
            Assert.Equal(MotionConstants.MinPetScale, loaded.Scale);
            Assert.Equal(0.3, loaded.Opacity);
            Assert.Equal(MotionConstants.MaxSpeedMultiplier, loaded.Speed);
            Assert.Equal(MotionConstants.MaxIntervalSeconds, loaded.AnimationIntervalSeconds);
        }
        finally
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
    }
}
