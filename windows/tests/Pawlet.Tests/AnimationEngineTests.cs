using Pawlet.Core.Engine;

namespace Pawlet.Tests;

public class AnimationEngineTests
{
    [Fact]
    public void Wave_greet_returns_to_idle_after_clip()
    {
        var e = new AnimationEngine();
        e.Greet(HoverReaction.Wave, now: 0, speed: 1);
        var mid = e.Frame(now: 0.2, animateIdle: false);
        Assert.Equal(3, mid.Row); // waving row
        var after = e.Frame(now: 10, animateIdle: false);
        Assert.Equal(0, after.Row);
        Assert.Equal(0, after.Column);
    }

    [Fact]
    public void Still_idle_uses_column_zero()
    {
        var e = new AnimationEngine();
        var frame = e.Frame(now: 1.0, animateIdle: false);
        Assert.Equal(0, frame.Row);
        Assert.Equal(0, frame.Column);
    }

    [Fact]
    public void Still_idle_stays_column_zero_across_time()
    {
        var e = new AnimationEngine();
        var early = e.Frame(now: 0.5, animateIdle: false);
        var late = e.Frame(now: 5.0, animateIdle: false);
        Assert.Equal(0, early.Column);
        Assert.Equal(0, late.Column);
        Assert.Equal(0, early.Row);
        Assert.Equal(0, late.Row);
    }
}
