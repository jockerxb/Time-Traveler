using System.ComponentModel;
using System.Diagnostics;
using System.Text.Json;
using TimeTraveler.Windows.Models;

namespace TimeTraveler.Windows.Services;

public sealed class HybridLauncher
{
    private readonly JsonSerializerOptions _jsonOptions = new() { WriteIndented = true };
    private readonly string? _helperExecutable;

    public HybridLauncher(string? helperExecutable = null) => _helperExecutable = helperExecutable;

    public bool IsRunning(AppDefinition app) =>
        app.ProcessNames.Any(name => Process.GetProcessesByName(name).Any(process => !process.HasExited));

    public async Task<bool> RequestQuitAsync(AppDefinition app, TimeSpan timeout)
    {
        var processes = app.ProcessNames
            .SelectMany(Process.GetProcessesByName)
            .Where(process => !process.HasExited)
            .DistinctBy(process => process.Id)
            .ToArray();

        foreach (var process in processes)
        {
            try { process.CloseMainWindow(); }
            catch { /* The final running-process check decides the outcome. */ }
        }

        var deadline = DateTimeOffset.UtcNow + timeout;
        while (DateTimeOffset.UtcNow < deadline)
        {
            if (!IsRunning(app)) return true;
            await Task.Delay(200);
        }

        return !IsRunning(app);
    }

    public async Task<AppLaunchResult> LaunchAsync(
        AppDefinition app,
        LaunchTarget target,
        TimeZoneItem destination,
        string? executableArguments = null,
        bool useElevation = true,
        int? warmupSeconds = null,
        CancellationToken cancellationToken = default)
    {
        var original = TimeZoneCommand.GetCurrent();
        var requiresSystemSwitch = !string.Equals(original, destination.Id, StringComparison.OrdinalIgnoreCase);
        if (!requiresSystemSwitch)
        {
            await StartTargetAndWarmUp(app, target, destination.IanaId, executableArguments, warmupSeconds ?? app.WarmupSeconds, cancellationToken);
            return new AppLaunchResult(original, destination.Id, false, true);
        }

        var jobDirectory = Path.Combine(Path.GetTempPath(), "TimeTraveler", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(jobDirectory);
        var jobPath = Path.Combine(jobDirectory, "job.json");
        var readyPath = Path.Combine(jobDirectory, "ready");
        var donePath = Path.Combine(jobDirectory, "done");
        var resultPath = Path.Combine(jobDirectory, "result.json");
        var job = new TimeZoneLaunchJob
        {
            OriginalTimeZoneId = original,
            TargetTimeZoneId = destination.Id,
            ReadyFile = readyPath,
            DoneFile = donePath,
            ResultFile = resultPath,
            TimeoutSeconds = Math.Max(90, (warmupSeconds ?? app.WarmupSeconds) + 45),
            ParentProcessId = Environment.ProcessId
        };
        File.WriteAllText(jobPath, JsonSerializer.Serialize(job, _jsonOptions));

        Process? helper = null;
        Exception? launchError = null;
        try
        {
            helper = StartHelper(jobPath, useElevation);
            await WaitForReadyOrFailure(helper, readyPath, resultPath, TimeSpan.FromSeconds(30), cancellationToken);
            await StartTargetAndWarmUp(app, target, destination.IanaId, executableArguments, warmupSeconds ?? app.WarmupSeconds, cancellationToken);
        }
        catch (Exception error)
        {
            launchError = error;
        }
        finally
        {
            try { File.WriteAllText(donePath, DateTimeOffset.UtcNow.ToString("O")); }
            catch { /* The helper timeout still restores the original time zone. */ }
        }

        if (helper is not null)
        {
            using var waitCancellation = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            try { await helper.WaitForExitAsync(waitCancellation.Token); }
            catch (OperationCanceledException) { /* Result and actual time zone checks below remain authoritative. */ }
        }

        var helperResult = ReadHelperResult(resultPath);
        var actual = TimeZoneCommand.GetCurrent();
        var restored = string.Equals(actual, original, StringComparison.OrdinalIgnoreCase);
        if (!restored)
        {
            throw new InvalidOperationException($"RESTORE_FAILED|{original}|{actual}|{helperResult?.Error}");
        }
        if (helper is null && launchError is not null)
        {
            TryDelete(jobDirectory);
            throw launchError;
        }
        if (helperResult is null || !helperResult.Switched)
        {
            throw new InvalidOperationException(helperResult?.Error ?? "The elevated helper did not report a successful time-zone switch.");
        }
        if (!string.IsNullOrWhiteSpace(helperResult.Error))
        {
            throw new InvalidOperationException(helperResult.Error);
        }
        if (launchError is not null)
        {
            throw new InvalidOperationException(launchError.Message, launchError);
        }

        TryDelete(jobDirectory);
        return new AppLaunchResult(original, destination.Id, true, helperResult.Restored);
    }

    private Process StartHelper(string jobPath, bool useElevation)
    {
        var executable = ResolveHelperExecutable();
        var startInfo = new ProcessStartInfo
        {
            FileName = executable,
            UseShellExecute = useElevation,
            CreateNoWindow = !useElevation
        };
        if (useElevation) startInfo.Verb = "runas";
        startInfo.ArgumentList.Add(jobPath);

        try
        {
            return Process.Start(startInfo) ?? throw new InvalidOperationException("Could not start the time-zone helper.");
        }
        catch (Win32Exception error) when (error.NativeErrorCode == 1223)
        {
            throw new UnauthorizedAccessException("Administrator permission was not granted.", error);
        }
    }

    private string ResolveHelperExecutable()
    {
        var executable = _helperExecutable ?? Path.Combine(AppContext.BaseDirectory, "TimeTraveler.Helper.exe");
        if (!File.Exists(executable))
        {
            throw new FileNotFoundException("TimeTraveler.Helper.exe is missing. Re-extract the complete Time Traveler package.", executable);
        }
        return executable;
    }

    private static async Task WaitForReadyOrFailure(Process helper, string readyPath, string resultPath, TimeSpan timeout, CancellationToken cancellationToken)
    {
        var deadline = DateTimeOffset.UtcNow + timeout;
        while (DateTimeOffset.UtcNow < deadline)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (File.Exists(readyPath)) return;
            if (File.Exists(resultPath))
            {
                var result = ReadHelperResult(resultPath);
                throw new InvalidOperationException(result?.Error ?? "The time-zone helper failed before launch.");
            }
            if (helper.HasExited) throw new InvalidOperationException("The time-zone helper exited before it was ready.");
            await Task.Delay(100, cancellationToken);
        }
        throw new TimeoutException("Timed out while waiting for Windows to switch time zones.");
    }

    private static async Task StartTargetAndWarmUp(
        AppDefinition app,
        LaunchTarget target,
        string ianaTimeZone,
        string? executableArguments,
        int warmupSeconds,
        CancellationToken cancellationToken)
    {
        Process? process;
        if (target.Kind == LaunchTargetKind.Executable)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = target.Value,
                WorkingDirectory = Path.GetDirectoryName(target.Value) ?? Environment.CurrentDirectory,
                UseShellExecute = false
            };
            startInfo.Environment["TZ"] = ianaTimeZone;
            if (!string.IsNullOrWhiteSpace(executableArguments)) startInfo.ArgumentList.Add(executableArguments);
            process = Process.Start(startInfo);
        }
        else
        {
            process = Process.Start(new ProcessStartInfo(target.Value) { UseShellExecute = true });
        }

        if (process is null && target.Kind == LaunchTargetKind.Executable)
            throw new InvalidOperationException("Windows did not start the selected application.");

        var appeared = target.Kind == LaunchTargetKind.Executable;
        var deadline = DateTimeOffset.UtcNow + TimeSpan.FromSeconds(20);
        while (!appeared && DateTimeOffset.UtcNow < deadline)
        {
            cancellationToken.ThrowIfCancellationRequested();
            appeared = app.ProcessNames.Any(name => Process.GetProcessesByName(name).Any(candidate => !candidate.HasExited));
            if (!appeared) await Task.Delay(200, cancellationToken);
        }
        if (!appeared) throw new TimeoutException($"{app.EnglishName} did not finish launching in time.");

        await Task.Delay(TimeSpan.FromSeconds(Math.Max(0, warmupSeconds)), cancellationToken);
    }

    private static TimeZoneLaunchResult? ReadHelperResult(string resultPath)
    {
        try
        {
            return File.Exists(resultPath)
                ? JsonSerializer.Deserialize<TimeZoneLaunchResult>(File.ReadAllText(resultPath))
                : null;
        }
        catch
        {
            return null;
        }
    }

    private static void TryDelete(string directory)
    {
        try { Directory.Delete(directory, true); }
        catch { /* A stale temporary folder is safer than deleting before the helper exits. */ }
    }
}
