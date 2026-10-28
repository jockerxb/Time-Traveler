using System.Text.Json;
using TimeTraveler.Windows.Models;

namespace TimeTraveler.Windows.Services;

public static class IntegrationTestCommand
{
    public static async Task<int> RunAsync(string[] args)
    {
        if (args.Length != 3 || !File.Exists(args[0]) || !File.Exists(args[1])) return 64;
        var probeExecutable = Path.GetFullPath(args[0]);
        var helperExecutable = Path.GetFullPath(args[1]);
        var resultDirectory = Path.GetFullPath(args[2]);
        Directory.CreateDirectory(resultDirectory);
        var probeResultPath = Path.Combine(resultDirectory, "probe-result.json");
        var summaryPath = Path.Combine(resultDirectory, "integration-result.json");

        try
        {
            var original = TimeZoneCommand.GetCurrent();
            var destinationId = string.Equals(original, "China Standard Time", StringComparison.OrdinalIgnoreCase)
                ? "Pacific Standard Time"
                : "China Standard Time";
            var destination = TimeZoneItem.Load().First(item => string.Equals(item.Id, destinationId, StringComparison.OrdinalIgnoreCase));
            var app = new AppDefinition(
                "probe",
                "测试程序",
                "Probe",
                [Path.GetFileName(probeExecutable)],
                [Path.GetFileNameWithoutExtension(probeExecutable)],
                [probeExecutable],
                [],
                [],
                "#256CF4",
                1);

            Log(resultDirectory, "normal-launch:start");
            var launcher = new HybridLauncher(helperExecutable);
            var launchResult = await launcher.LaunchAsync(
                app,
                new LaunchTarget(LaunchTargetKind.Executable, probeExecutable),
                destination,
                probeResultPath,
                useElevation: false,
                warmupSeconds: 1);

            var probe = JsonSerializer.Deserialize<ProbeResult>(File.ReadAllText(probeResultPath))
                        ?? throw new InvalidOperationException("The probe returned invalid JSON.");
            var currentAfterTest = TimeZoneCommand.GetCurrent();

            Assert(string.Equals(probe.WindowsTimeZoneId, destination.Id, StringComparison.OrdinalIgnoreCase),
                $"Probe saw '{probe.WindowsTimeZoneId}', expected '{destination.Id}'.");
            Assert(string.Equals(probe.TzEnvironment, destination.IanaId, StringComparison.OrdinalIgnoreCase),
                $"Probe TZ was '{probe.TzEnvironment}', expected '{destination.IanaId}'.");
            Assert(string.Equals(currentAfterTest, original, StringComparison.OrdinalIgnoreCase),
                $"System time zone was not restored. Current '{currentAfterTest}', expected '{original}'.");
            Assert(launchResult.Restored, "Launcher did not report a successful restore.");
            Log(resultDirectory, "normal-launch:restored");

            var launchFailureRestored = await VerifyLaunchFailureRestoresAsync(app, destination, original, helperExecutable, resultDirectory);
            var parentCrashRestored = await VerifyParentCrashRestoresAsync(destination, original, resultDirectory, helperExecutable);

            WriteSummary(summaryPath, new
            {
                success = true,
                originalTimeZone = original,
                targetTimeZone = destination.Id,
                targetIanaTimeZone = destination.IanaId,
                probe,
                restoredTimeZone = currentAfterTest,
                launchFailureRestored,
                parentCrashRestored
            });
            return 0;
        }
        catch (Exception error)
        {
            Log(resultDirectory, $"failed:{error.GetType().Name}:{error.Message}");
            WriteSummary(summaryPath, new { success = false, error = error.ToString(), currentTimeZone = SafeCurrentTimeZone() });
            return 1;
        }
    }

    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static async Task<bool> VerifyLaunchFailureRestoresAsync(AppDefinition app, TimeZoneItem destination, string original, string helperExecutable, string resultDirectory)
    {
        Log(resultDirectory, "launch-failure:start");
        var launcher = new HybridLauncher(helperExecutable);
        var failedAsExpected = false;
        try
        {
            await launcher.LaunchAsync(
                app,
                new LaunchTarget(LaunchTargetKind.Executable, Path.Combine(Path.GetTempPath(), Guid.NewGuid() + ".exe")),
                destination,
                useElevation: false,
                warmupSeconds: 0);
        }
        catch
        {
            failedAsExpected = true;
        }

        Assert(failedAsExpected, "The missing executable unexpectedly launched.");
        var actual = TimeZoneCommand.GetCurrent();
        Assert(string.Equals(actual, original, StringComparison.OrdinalIgnoreCase),
            $"Launch-failure path did not restore the system time zone. Current '{actual}', expected '{original}'.");
        Log(resultDirectory, "launch-failure:restored");
        return true;
    }

    private static async Task<bool> VerifyParentCrashRestoresAsync(TimeZoneItem destination, string original, string resultDirectory, string helperExecutable)
    {
        Log(resultDirectory, "parent-crash:start");
        var directory = Path.Combine(resultDirectory, "parent-crash-watchdog");
        Directory.CreateDirectory(directory);
        var jobPath = Path.Combine(directory, "job.json");
        var resultPath = Path.Combine(directory, "result.json");
        var job = new TimeZoneLaunchJob
        {
            OriginalTimeZoneId = original,
            TargetTimeZoneId = destination.Id,
            ReadyFile = Path.Combine(directory, "ready"),
            DoneFile = Path.Combine(directory, "done-not-created"),
            ResultFile = resultPath,
            TimeoutSeconds = 30,
            ParentProcessId = int.MaxValue
        };
        File.WriteAllText(jobPath, JsonSerializer.Serialize(job, new JsonSerializerOptions { WriteIndented = true }));

        var startInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName = helperExecutable,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        startInfo.ArgumentList.Add(jobPath);
        using var helper = System.Diagnostics.Process.Start(startInfo) ?? throw new InvalidOperationException("Could not start the watchdog helper.");
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(40));
        await helper.WaitForExitAsync(timeout.Token);

        var result = JsonSerializer.Deserialize<TimeZoneLaunchResult>(File.ReadAllText(resultPath));
        Assert(result?.Switched == true, "Parent-crash watchdog did not switch to the target time zone.");
        Assert(result?.Restored == true, "Parent-crash watchdog did not report restoration.");
        var actual = TimeZoneCommand.GetCurrent();
        Assert(string.Equals(actual, original, StringComparison.OrdinalIgnoreCase),
            $"Parent-crash watchdog did not restore the system time zone. Current '{actual}', expected '{original}'.");
        Log(resultDirectory, "parent-crash:restored");
        return true;
    }

    private static void Log(string resultDirectory, string message) =>
        File.AppendAllText(Path.Combine(resultDirectory, "integration-progress.log"), $"{DateTimeOffset.UtcNow:O} {message}{Environment.NewLine}");

    private static void WriteSummary(string path, object value) =>
        File.WriteAllText(path, JsonSerializer.Serialize(value, new JsonSerializerOptions { WriteIndented = true }));

    private static string SafeCurrentTimeZone()
    {
        try { return TimeZoneCommand.GetCurrent(); }
        catch { return "unavailable"; }
    }

    private sealed class ProbeResult
    {
        public string? TzEnvironment { get; set; }
        public string WindowsTimeZoneId { get; set; } = "";
        public string DotNetLocalTimeZoneId { get; set; } = "";
        public DateTimeOffset Timestamp { get; set; }
    }
}
