using TimeTraveler.Windows;
using TimeTraveler.Windows.Models;
using TimeTraveler.Windows.Services;

var failures = new List<string>();

void Check(bool condition, string message)
{
    if (!condition) failures.Add(message);
}

Check(AppCatalog.All.Count == 4, "App catalog must contain exactly four supported chat apps.");
Check(AppCatalog.All.Select(app => app.Id).Distinct().Count() == 4, "App IDs must be unique.");

var zones = TimeZoneItem.Load();
Check(zones.Count > 50, "Windows time-zone catalog is unexpectedly small.");
var china = zones.FirstOrDefault(zone => zone.Id == "China Standard Time");
Check(china is not null, "China Standard Time is missing.");
Check(china?.IanaId == "Asia/Shanghai", $"Expected Asia/Shanghai, got {china?.IanaId}.");
Check(china?.Name(AppLanguage.Chinese).Contains("北京") == true, "Chinese friendly name is missing.");
Check(china?.Name(AppLanguage.English).Contains("Beijing") == true, "English friendly name is missing.");
Check(zones.Any(zone => zone.Matches("UTC+08", AppLanguage.English)), "UTC offset search failed.");
Check(zones.Any(zone => zone.Matches("北京", AppLanguage.Chinese)), "Chinese city search failed.");

var settingsPath = Path.Combine(Path.GetTempPath(), "TimeTraveler-SmokeTests", Guid.NewGuid().ToString("N"), "settings.json");
var settingsService = new SettingsService(settingsPath);
var expectedSettings = new UserSettings { SelectedTimeZoneId = "China Standard Time", Language = AppLanguage.English };
settingsService.Save(expectedSettings);
var actualSettings = settingsService.Load();
Check(actualSettings.SelectedTimeZoneId == expectedSettings.SelectedTimeZoneId, "Settings time zone did not round-trip.");
Check(actualSettings.Language == expectedSettings.Language, "Settings language did not round-trip.");

if (failures.Count > 0)
{
    foreach (var failure in failures) Console.Error.WriteLine($"FAIL {failure}");
    return 1;
}

Console.WriteLine($"PASS Windows catalog, localization, settings, and {zones.Count} time zones");
return 0;
