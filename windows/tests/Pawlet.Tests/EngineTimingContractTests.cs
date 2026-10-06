using System.Text.Json;
using Pawlet.Core.Engine;

namespace Pawlet.Tests;

public class EngineTimingContractTests
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    [Fact]
    public void PetState_frame_counts_match_shared_engine_timings()
    {
        var json = File.ReadAllText(SharedPath("engine-timings.json"));
        var file = JsonSerializer.Deserialize<EngineTimingsFile>(json, JsonOptions)
            ?? throw new InvalidDataException("engine-timings.json");

        Assert.NotEmpty(file.States);

        foreach (var spec in file.States)
        {
            var state = Enum.GetValues<PetState>().Single(s => s.RawValue() == spec.Id);
            Assert.Equal(spec.Row, state.Row());
            Assert.Equal(spec.FrameCount, state.Count());
            Assert.Equal(spec.SecondsPerFrame, state.SecondsPerFrameValue(), 5);
        }

        Assert.Equal(file.States.Count, Enum.GetValues<PetState>().Length);
    }

    [Fact]
    public void Wave_greet_fixture_matches_animation_engine()
    {
        var json = File.ReadAllText(SharedPath(Path.Combine("fixtures", "engine", "wave-greet.json")));
        var cases = JsonSerializer.Deserialize<List<WaveGreetCase>>(json, JsonOptions)
            ?? throw new InvalidDataException("wave-greet.json");

        var engine = new AnimationEngine();
        foreach (var sample in cases)
        {
            var speed = sample.Speed ?? 1;
            if (sample.Action == "greet-wave")
            {
                engine.Greet(HoverReaction.Wave, now: 0, speed: speed);
            }

            var frame = engine.Frame(now: sample.Now, animateIdle: false, speed: speed);
            Assert.Equal(sample.ExpectRow, frame.Row);
            if (sample.ExpectColumn is int column)
            {
                Assert.Equal(column, frame.Column);
            }
        }
    }

    private static string SharedPath(string relativeToShared)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var shared = Path.Combine(dir.FullName, "shared");
            if (Directory.Exists(shared))
            {
                return Path.Combine(shared, relativeToShared);
            }

            dir = dir.Parent;
        }

        throw new DirectoryNotFoundException("Could not find shared/ walking up from " + AppContext.BaseDirectory);
    }

    private sealed class EngineTimingsFile
    {
        public List<StateTiming> States { get; set; } = [];
    }

    private sealed class StateTiming
    {
        public string Id { get; set; } = "";
        public int Row { get; set; }
        public int FrameCount { get; set; }
        public double SecondsPerFrame { get; set; }
    }

    private sealed class WaveGreetCase
    {
        public double Now { get; set; }
        public double? Speed { get; set; }
        public string? Action { get; set; }
        public int ExpectRow { get; set; }
        public int? ExpectColumn { get; set; }
    }
}
