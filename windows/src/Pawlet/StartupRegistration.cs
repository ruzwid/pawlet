using System.Runtime.InteropServices;

namespace Pawlet;

/// <summary>CurrentUser Run key for Start with Windows (no-op off Windows).</summary>
internal static class StartupRegistration
{
    private const string ValueName = "Pawlet";
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";

    public static void Apply(bool enabled)
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            return;
        }

        ApplyWindows(enabled);
    }

    private static void ApplyWindows(bool enabled)
    {
        using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true)
            ?? throw new InvalidOperationException("Could not open HKCU Run key.");

        if (enabled)
        {
            var exe = Environment.ProcessPath
                ?? throw new InvalidOperationException("Process path is unavailable.");
            key.SetValue(ValueName, "\"" + exe + "\"");
        }
        else if (key.GetValue(ValueName) is not null)
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }
}
