using System.Diagnostics;
using System.Text.Json;

if (args.Length != 1) return 64;

var outputPath = Path.GetFullPath(args[0]);
Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
var startInfo = new ProcessStartInfo
{
    FileName = "tzutil.exe",
    UseShellExecute = false,
    RedirectStandardOutput = true,
    RedirectStandardError = true,
    CreateNoWindow = true
};
startInfo.ArgumentList.Add("/g");
using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Could not start tzutil.exe.");
var windowsTimeZone = process.StandardOutput.ReadToEnd().Trim();
var error = process.StandardError.ReadToEnd();
process.WaitForExit();
if (process.ExitCode != 0) throw new InvalidOperationException(error);

var result = new
{
    tzEnvironment = Environment.GetEnvironmentVariable("TZ"),
    windowsTimeZoneId = windowsTimeZone,
    dotNetLocalTimeZoneId = TimeZoneInfo.Local.Id,
    timestamp = DateTimeOffset.Now
};
File.WriteAllText(outputPath, JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true }));
return 0;
