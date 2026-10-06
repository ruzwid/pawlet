using System.ComponentModel;
using System.Diagnostics;
using Pawlet.Core.Storage;

namespace Pawlet.Pets;

/// <summary>Shared Win32 process → normalized main-module path.</summary>
internal static class ProcessMainModule
{
    public static string? TryGetPath(int processId)
    {
        if (processId <= 0)
        {
            return null;
        }

        try
        {
            using var process = Process.GetProcessById(processId);
            return PlacementStore.NormalizeAppKey(process.MainModule?.FileName);
        }
        catch (Win32Exception)
        {
            return null;
        }
        catch (InvalidOperationException)
        {
            return null;
        }
        catch (ArgumentException)
        {
            return null;
        }
    }
}
