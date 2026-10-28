namespace TimeTraveler.Windows.Models;

public sealed class TimeZoneLaunchJob
{
    public required string TargetTimeZoneId { get; init; }
    public required string OriginalTimeZoneId { get; init; }
    public required string ReadyFile { get; init; }
    public required string DoneFile { get; init; }
    public required string ResultFile { get; init; }
    public int TimeoutSeconds { get; init; } = 90;
    public int ParentProcessId { get; init; }
}

public sealed class TimeZoneLaunchResult
{
    public bool Switched { get; set; }
    public bool Restored { get; set; }
    public bool TimedOut { get; set; }
    public string OriginalTimeZoneId { get; set; } = "";
    public string TargetTimeZoneId { get; set; } = "";
    public string? Error { get; set; }
}

public sealed record AppLaunchResult(string OriginalTimeZoneId, string TargetTimeZoneId, bool SystemTimeZoneChanged, bool Restored);
