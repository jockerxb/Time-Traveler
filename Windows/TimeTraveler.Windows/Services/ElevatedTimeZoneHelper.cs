using System.Diagnostics;
using System.Text.Json;
using TimeTraveler.Windows.Models;

namespace TimeTraveler.Windows.Services;

public static class ElevatedTimeZoneHelper
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static int Run(string[] args)
    {
        if (args.Length != 1 || !File.Exists(args[0])) return 64;

        TimeZoneLaunchJob? job;
        try
        {
            job = JsonSerializer.Deserialize<TimeZoneLaunchJob>(File.ReadAllText(args[0]), JsonOptions);
        }
        catch
        {
            return 65;
        }

        if (job is null) return 65;
        var result = new TimeZoneLaunchResult
        {
            OriginalTimeZoneId = job.OriginalTimeZoneId,
            TargetTimeZoneId = job.TargetTimeZoneId
        };

        try
        {
            var actualOriginal = TimeZoneCommand.GetCurrent();
            if (!string.Equals(actualOriginal, job.OriginalTimeZoneId, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException($"The system time zone changed before launch. Expected '{job.OriginalTimeZoneId}', found '{actualOriginal}'.");
            }

            var switchResult = TimeZoneCommand.Set(job.TargetTimeZoneId);
            if (!switchResult.Success) throw new InvalidOperationException(string.IsNullOrWhiteSpace(switchResult.Error) ? "Could not change the Windows time zone." : switchResult.Error.Trim());
            result.Switched = true;

            File.WriteAllText(job.ReadyFile, DateTimeOffset.UtcNow.ToString("O"));
            var timer = Stopwatch.StartNew();
            while (!File.Exists(job.DoneFile) && timer.Elapsed < TimeSpan.FromSeconds(job.TimeoutSeconds))
            {
                if (!IsParentAlive(job.ParentProcessId)) break;
                Thread.Sleep(100);
            }
            result.TimedOut = !File.Exists(job.DoneFile);
        }
        catch (Exception error)
        {
            result.Error = error.Message;
        }
        finally
        {
            if (result.Switched)
            {
                var restoreResult = TimeZoneCommand.Set(job.OriginalTimeZoneId);
                result.Restored = restoreResult.Success;
                if (!restoreResult.Success)
                {
                    var restoreError = string.IsNullOrWhiteSpace(restoreResult.Error) ? "Unknown restore error." : restoreResult.Error.Trim();
                    result.Error = string.IsNullOrWhiteSpace(result.Error)
                        ? $"Restore failed: {restoreError}"
                        : $"{result.Error} Restore failed: {restoreError}";
                }
            }
            else
            {
                result.Restored = string.Equals(SafeCurrentTimeZone(), job.OriginalTimeZoneId, StringComparison.OrdinalIgnoreCase);
            }

            WriteResult(job.ResultFile, result);
        }

        return result.Switched && result.Restored && string.IsNullOrWhiteSpace(result.Error) ? 0 : 1;
    }

    private static string SafeCurrentTimeZone()
    {
        try { return TimeZoneCommand.GetCurrent(); }
        catch { return ""; }
    }

    private static bool IsParentAlive(int processId)
    {
        try
        {
            using var process = Process.GetProcessById(processId);
            return !process.HasExited;
        }
        catch
        {
            return false;
        }
    }

    private static void WriteResult(string path, TimeZoneLaunchResult result)
    {
        try
        {
            var temporary = path + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(result, JsonOptions));
            File.Move(temporary, path, true);
        }
        catch
        {
            // The parent also checks the actual system time zone; a missing result is treated as failure.
        }
    }
}
