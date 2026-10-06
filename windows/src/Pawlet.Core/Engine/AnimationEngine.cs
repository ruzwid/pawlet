namespace Pawlet.Core.Engine;

public sealed class AnimationEngine
{
    public PetState BaseState { get; private set; } = PetState.Idle;
    public PetState? Action { get; private set; }
    public bool IsGreeting { get; private set; }

    private double _actionUntil;
    private string _key = "";
    private double _started;

    public void Perform(PetState state, double now, double? seconds = null, double speed = 1)
    {
        _key = "";
        IsGreeting = false;
        if (seconds is > 0)
        {
            Action = state;
            _actionUntil = now + Math.Min(seconds.Value, 3600);
        }
        else if (state.IsTransient())
        {
            Action = state;
            var clamped = Math.Min(1.5, Math.Max(0.5, speed));
            _actionUntil = now + state.Count() * state.SecondsPerFrameValue() / clamped;
        }
        else
        {
            BaseState = state;
            Action = null;
        }
    }

    public void Greet(HoverReaction reaction, double now, double speed = 1)
    {
        var state = reaction.State();
        var clamped = Math.Min(
            MotionConstants.MaxSpeedMultiplier,
            Math.Max(MotionConstants.MinSpeedMultiplier, speed));
        var seconds = state.Count() * state.SecondsPerFrameValue() / clamped;
        Perform(state, now, seconds, speed);
        IsGreeting = true;
    }

    public void Reset()
    {
        BaseState = PetState.Idle;
        Action = null;
        IsGreeting = false;
        _key = "";
    }

    public SpriteFrame Frame(
        double now,
        PetState? drag = null,
        SpriteFrame? gaze = null,
        bool paused = false,
        bool reducedMotion = false,
        bool animateIdle = true,
        bool loopActivities = true,
        double speed = 1,
        double animationInterval = MotionConstants.DefaultIntervalSeconds)
    {
        if (Action is not null && now >= _actionUntil)
        {
            Action = null;
            IsGreeting = false;
        }

        var state = drag ?? Action ?? BaseState;
        if (state == PetState.Idle && Action is null && drag is null && gaze is { } g && !paused && !reducedMotion)
        {
            _key = "look";
            return g;
        }

        var raw = state.RawValue();
        if (_key != raw)
        {
            _key = raw;
            _started = now;
        }

        var elapsedSeconds = Math.Max(0, now - _started);
        var speedMultiplier = Math.Min(
            MotionConstants.MaxSpeedMultiplier,
            Math.Max(MotionConstants.MinSpeedMultiplier, speed));
        var elapsed = (int)(elapsedSeconds * speedMultiplier / state.SecondsPerFrameValue());
        var still = paused || reducedMotion || (state == PetState.Idle && !animateIdle);
        var shouldLoop = drag is not null || state == PetState.Idle || loopActivities || state.IsTransient();

        int column;
        if (still)
        {
            column = 0;
        }
        else if (shouldLoop && drag is null && Action is null && !state.IsTransient())
        {
            var duration = state.Count() * state.SecondsPerFrameValue() / speedMultiplier;
            var interval = double.IsFinite(animationInterval)
                ? Math.Min(MotionConstants.MaxIntervalSeconds, Math.Max(0, animationInterval))
                : MotionConstants.DefaultIntervalSeconds;
            var cycleElapsed = elapsedSeconds % (duration + interval);
            column = cycleElapsed >= duration
                ? (state == PetState.Idle ? 0 : state.Count() - 1)
                : Math.Min(state.Count() - 1, (int)(cycleElapsed * speedMultiplier / state.SecondsPerFrameValue()));
        }
        else
        {
            column = shouldLoop
                ? elapsed % state.Count()
                : Math.Min(elapsed, state.Count() - 1);
        }

        return new SpriteFrame(state.Row(), column);
    }
}
