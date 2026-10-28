namespace TimeTraveler.Windows.Models;

public enum LaunchTargetKind
{
    Executable,
    Shortcut,
    Uri
}

public sealed record LaunchTarget(LaunchTargetKind Kind, string Value);
