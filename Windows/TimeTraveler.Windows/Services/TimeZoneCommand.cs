using System.Diagnostics;

namespace TimeTraveler.Windows.Services;

public sealed record CommandResult(bool Success, string Output, string Error, int ExitCode);

public static class TimeZoneCommand
{
    public static string GetCurrent()
    {
        var result = Run("/g");
        if (!result.Success) throw new InvalidOperationException($"tzutil /g failed: {result.Error}");
        return result.Output.Trim();
    }

    public static CommandResult Set(string windowsTimeZoneId)
    {
        var result = Run("/s", windowsTimeZoneId);
        if (!result.Success) return result;

        try
        {
            var current = GetCurrent();
            return string.Equals(current, windowsTimeZoneId, StringComparison.OrdinalIgnoreCase)
                ? result
                : new CommandResult(false, result.Output, $"Expected '{windowsTimeZoneId}', but Windows reports '{current}'.", result.ExitCode);
        }
        catch (Exception error)
        {
            return new CommandResult(false, result.Output, error.Message, result.ExitCode);
        }
    }

    private static CommandResult Run(params string[] arguments)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "tzutil.exe",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        foreach (var argument in arguments) startInfo.ArgumentList.Add(argument);

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Could not start tzutil.exe.");
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();
        return new CommandResult(process.ExitCode == 0, output, error, process.ExitCode);
    }
}
