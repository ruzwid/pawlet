namespace Pawlet.Core.Storage;

public static class LibraryPaths
{
    public static string DefaultRoot => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "Pawlet",
        "Library");
}
