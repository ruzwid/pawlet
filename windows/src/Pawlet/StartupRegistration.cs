using System.IO;
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
            var exe = ResolveExecutablePath();
            key.SetValue(ValueName, "\"" + exe + "\"");
        }
        else if (key.GetValue(ValueName) is not null)
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }

    /// <summary>
    /// Prefer <c>Pawlet.exe</c> beside the app base directory (published apphost).
    /// Reject <c>dotnet</c> host paths from <c>dotnet run</c>.
    /// </summary>
    internal static string ResolveExecutablePath()
    {
        var besideBase = Path.Combine(AppContext.BaseDirectory, "Pawlet.exe");
        if (File.Exists(besideBase))
        {
            return Path.GetFullPath(besideBase);
        }

        var process = Environment.ProcessPath
            ?? throw new InvalidOperationException("Process path is unavailable.");
        var name = Path.GetFileName(process);
        if (name.Equals("dotnet.exe", StringComparison.OrdinalIgnoreCase)
            || name.Equals("dotnet", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Start with Windows needs a published Pawlet.exe. `dotnet run` cannot register a stable login path.");
        }

        return Path.GetFullPath(process);
    }
}
