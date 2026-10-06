namespace Pawlet.Core.Packs;

public static class ZipSafety
{
    public static void ValidateEntryName(string name)
    {
        if (string.IsNullOrEmpty(name))
        {
            throw new InvalidDataException("ZIP entry name is empty.");
        }

        if (name.Contains('\\'))
        {
            throw new InvalidDataException("ZIP entry names must use forward slashes, not backslashes.");
        }

        if (name.StartsWith('/') || (name.Length >= 2 && char.IsAsciiLetter(name[0]) && name[1] == ':'))
        {
            throw new InvalidDataException("ZIP entry names must be relative.");
        }

        foreach (var segment in name.Split('/'))
        {
            if (segment is ".." or ".")
            {
                throw new InvalidDataException("ZIP entry path traversal is not allowed.");
            }
        }
    }

    public static bool IsFinderMetadata(string path)
    {
        var isDirectory = path.EndsWith('/');
        var components = path.Split('/', StringSplitOptions.None);
        var names = isDirectory ? components[..^1] : components;
        if (names.Length == 0 || names.Length > 3)
        {
            return false;
        }

        if (names.Any(static n => string.IsNullOrEmpty(n) || n is "." or ".."))
        {
            return false;
        }

        if (!isDirectory && names.Length <= 2 && names[^1] == ".DS_Store")
        {
            return true;
        }

        if (names[0] != "__MACOSX")
        {
            return false;
        }

        return isDirectory ? names.Length <= 2 : names.Length >= 2 && names[^1].StartsWith("._", StringComparison.Ordinal);
    }
}
