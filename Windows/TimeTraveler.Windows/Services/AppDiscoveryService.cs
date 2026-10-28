using Microsoft.Win32;
using TimeTraveler.Windows.Models;

namespace TimeTraveler.Windows.Services;

public sealed class AppDiscoveryService
{
    public LaunchTarget? Find(AppDefinition app)
    {
        foreach (var executable in app.ExecutableNames)
        {
            var registryPath = FindAppPath(executable);
            if (registryPath is not null) return new LaunchTarget(LaunchTargetKind.Executable, registryPath);
        }

        foreach (var candidate in app.CandidatePaths)
        {
            var path = Environment.ExpandEnvironmentVariables(candidate);
            if (File.Exists(path)) return new LaunchTarget(LaunchTargetKind.Executable, path);
        }

        var shortcut = FindShortcut(app.ShortcutNames);
        if (shortcut is not null) return new LaunchTarget(LaunchTargetKind.Shortcut, shortcut);

        foreach (var uri in app.UriSchemes)
        {
            if (ProtocolExists(uri.TrimEnd(':'))) return new LaunchTarget(LaunchTargetKind.Uri, uri);
        }

        return null;
    }

    private static string? FindAppPath(string executable)
    {
        const string baseKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\";
        foreach (var hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
        {
            foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
            {
                try
                {
                    using var root = RegistryKey.OpenBaseKey(hive, view);
                    using var key = root.OpenSubKey(baseKey + executable);
                    var value = key?.GetValue(null) as string;
                    if (!string.IsNullOrWhiteSpace(value) && File.Exists(value.Trim('"'))) return value.Trim('"');
                }
                catch
                {
                    // Registry access can be restricted by enterprise policy. Continue with file and protocol discovery.
                }
            }
        }

        return null;
    }

    private static string? FindShortcut(IEnumerable<string> names)
    {
        var roots = new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory)
        };

        foreach (var root in roots.Where(Directory.Exists))
        {
            try
            {
                foreach (var shortcut in Directory.EnumerateFiles(root, "*.lnk", SearchOption.AllDirectories))
                {
                    var fileName = Path.GetFileNameWithoutExtension(shortcut);
                    if (names.Any(name => fileName.Contains(name, StringComparison.CurrentCultureIgnoreCase))) return shortcut;
                }
            }
            catch
            {
                // Ignore inaccessible Start Menu folders and keep looking elsewhere.
            }
        }

        return null;
    }

    private static bool ProtocolExists(string scheme)
    {
        try
        {
            using var key = Registry.ClassesRoot.OpenSubKey(scheme);
            return key is not null && key.GetValue("URL Protocol") is not null;
        }
        catch
        {
            return false;
        }
    }
}
