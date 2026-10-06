namespace Pawlet.Core.Engine;

/// <summary>Mac raw values: idle, running-right, running-left, waving, jumping, failed, waiting, running (working), review.</summary>
public enum PetState
{
    Idle,
    RunningRight,
    RunningLeft,
    Waving,
    Jumping,
    Failed,
    Waiting,
    Working,
    Review,
}

public static class PetStateExtensions
{
    private static readonly int[] Counts = [6, 8, 8, 4, 5, 8, 6, 6, 6];
    private static readonly double[] SecondsPerFrame = [0.28, 0.12, 0.12, 0.14, 0.14, 0.14, 0.15, 0.14, 0.15];

    public static int Row(this PetState state) => (int)state;

    public static int Count(this PetState state) => Counts[state.Row()];

    public static double SecondsPerFrameValue(this PetState state) => SecondsPerFrame[state.Row()];

    public static bool IsTransient(this PetState state) =>
        state is PetState.Waving or PetState.Jumping;

    public static string RawValue(this PetState state) => state switch
    {
        PetState.Idle => "idle",
        PetState.RunningRight => "running-right",
        PetState.RunningLeft => "running-left",
        PetState.Waving => "waving",
        PetState.Jumping => "jumping",
        PetState.Failed => "failed",
        PetState.Waiting => "waiting",
        PetState.Working => "running",
        PetState.Review => "review",
        _ => throw new ArgumentOutOfRangeException(nameof(state), state, null),
    };
}

public readonly record struct SpriteFrame(int Row, int Column);

/// <summary>Greet reactions aligned with Mac; each maps to a <see cref="PetState"/> row.</summary>
public enum HoverReaction
{
    Wave,
    Hop,
    Waiting,
    Working,
    Reviewing,
    Oops,
}

public static class HoverReactionExtensions
{
    public static PetState State(this HoverReaction reaction) => reaction switch
    {
        HoverReaction.Wave => PetState.Waving,
        HoverReaction.Hop => PetState.Jumping,
        HoverReaction.Waiting => PetState.Waiting,
        HoverReaction.Working => PetState.Working,
        HoverReaction.Reviewing => PetState.Review,
        HoverReaction.Oops => PetState.Failed,
        _ => throw new ArgumentOutOfRangeException(nameof(reaction), reaction, null),
    };

    public static string Title(this HoverReaction reaction) => reaction switch
    {
        HoverReaction.Wave => "Wave",
        HoverReaction.Hop => "Hop toward you",
        HoverReaction.Waiting => "Waiting",
        HoverReaction.Working => "Working",
        HoverReaction.Reviewing => "Reviewing",
        HoverReaction.Oops => "Oops",
        _ => reaction.ToString(),
    };
}
