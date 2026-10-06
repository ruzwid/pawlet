using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json.Serialization;
using Pawlet.Core.Engine;

namespace Pawlet.Core.Storage;

/// <summary>Persisted desktop preferences (%AppData%/Pawlet/settings.json).</summary>
public sealed class SettingsModel : INotifyPropertyChanged
{
    private double _scale = 1.0;
    private double _opacity = 1.0;
    private double _speed = 1.0;
    private bool _pause;
    private bool _animateIdle;
    private HoverReaction _hoverReaction = HoverReaction.Wave;
    private double _animationIntervalSeconds = MotionConstants.DefaultIntervalSeconds;
    private bool _clickThrough;
    private bool _startWithWindows;
    private bool _rememberPlacePerApp;

    public event PropertyChangedEventHandler? PropertyChanged;

    [JsonPropertyName("scale")]
    public double Scale
    {
        get => _scale;
        set => SetField(ref _scale, Clamp(value, MotionConstants.MinPetScale, MotionConstants.MaxPetScale));
    }

    [JsonPropertyName("opacity")]
    public double Opacity
    {
        get => _opacity;
        set => SetField(ref _opacity, Clamp(value, 0.3, 1.0));
    }

    [JsonPropertyName("speed")]
    public double Speed
    {
        get => _speed;
        set => SetField(ref _speed, Clamp(value, MotionConstants.MinSpeedMultiplier, MotionConstants.MaxSpeedMultiplier));
    }

    [JsonPropertyName("pause")]
    public bool Pause
    {
        get => _pause;
        set => SetField(ref _pause, value);
    }

    [JsonPropertyName("animateIdle")]
    public bool AnimateIdle
    {
        get => _animateIdle;
        set => SetField(ref _animateIdle, value);
    }

    [JsonPropertyName("hoverReaction")]
    public HoverReaction HoverReaction
    {
        get => _hoverReaction;
        set => SetField(ref _hoverReaction, Enum.IsDefined(value) ? value : HoverReaction.Wave);
    }

    [JsonPropertyName("animationIntervalSeconds")]
    public double AnimationIntervalSeconds
    {
        get => _animationIntervalSeconds;
        set => SetField(ref _animationIntervalSeconds, Clamp(value, 0, MotionConstants.MaxIntervalSeconds));
    }

    [JsonPropertyName("clickThrough")]
    public bool ClickThrough
    {
        get => _clickThrough;
        set => SetField(ref _clickThrough, value);
    }

    [JsonPropertyName("startWithWindows")]
    public bool StartWithWindows
    {
        get => _startWithWindows;
        set => SetField(ref _startWithWindows, value);
    }

    [JsonPropertyName("rememberPlacePerApp")]
    public bool RememberPlacePerApp
    {
        get => _rememberPlacePerApp;
        set => SetField(ref _rememberPlacePerApp, value);
    }

    /// <summary>Clamp numeric fields after deserialize (partial JSON / out-of-range).</summary>
    public void Normalize()
    {
        Scale = Scale;
        Opacity = Opacity;
        Speed = Speed;
        AnimationIntervalSeconds = AnimationIntervalSeconds;
        if (!Enum.IsDefined(HoverReaction))
        {
            HoverReaction = HoverReaction.Wave;
        }
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    private static double Clamp(double value, double min, double max) =>
        Math.Min(max, Math.Max(min, value));
}
