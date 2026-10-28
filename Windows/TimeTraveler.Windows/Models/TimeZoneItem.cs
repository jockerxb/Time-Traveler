using System.Globalization;

namespace TimeTraveler.Windows.Models;

public sealed class TimeZoneItem
{
    private static readonly Dictionary<string, (string Zh, string En)> FriendlyNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ["China Standard Time"] = ("北京 / 上海", "Beijing / Shanghai"),
        ["Pacific Standard Time"] = ("洛杉矶", "Los Angeles"),
        ["Eastern Standard Time"] = ("纽约", "New York"),
        ["GMT Standard Time"] = ("伦敦", "London"),
        ["W. Europe Standard Time"] = ("巴黎 / 柏林", "Paris / Berlin"),
        ["Tokyo Standard Time"] = ("东京", "Tokyo"),
        ["Singapore Standard Time"] = ("新加坡", "Singapore"),
        ["India Standard Time"] = ("印度", "India"),
        ["AUS Eastern Standard Time"] = ("悉尼", "Sydney"),
        ["UTC"] = ("协调世界时", "UTC")
    };

    public TimeZoneInfo Zone { get; }
    public string Id => Zone.Id;
    public string IanaId { get; }

    public TimeZoneItem(TimeZoneInfo zone)
    {
        Zone = zone;
        IanaId = TimeZoneInfo.TryConvertWindowsIdToIanaId(zone.Id, out var iana) ? iana : zone.Id;
    }

    public string Name(AppLanguage language)
    {
        if (FriendlyNames.TryGetValue(Id, out var names))
        {
            return language == AppLanguage.Chinese ? names.Zh : names.En;
        }

        return Zone.StandardName;
    }

    public string OffsetText(DateTimeOffset instant)
    {
        var offset = Zone.GetUtcOffset(instant);
        var sign = offset < TimeSpan.Zero ? "-" : "+";
        offset = offset.Duration();
        return $"UTC{sign}{offset.Hours:00}:{offset.Minutes:00}";
    }

    public string DayAndTime(AppLanguage language, DateTimeOffset instant)
    {
        var local = TimeZoneInfo.ConvertTime(instant, Zone);
        var culture = language == AppLanguage.Chinese ? CultureInfo.GetCultureInfo("zh-CN") : CultureInfo.GetCultureInfo("en-US");
        var day = language == AppLanguage.Chinese ? $"周{culture.DateTimeFormat.GetAbbreviatedDayName(local.DayOfWeek).TrimStart('周')}" : culture.DateTimeFormat.GetAbbreviatedDayName(local.DayOfWeek);
        return $"{day} {local:HH:mm}";
    }

    public bool Matches(string query, AppLanguage language)
    {
        if (string.IsNullOrWhiteSpace(query)) return true;
        var value = query.Trim();
        return Id.Contains(value, StringComparison.OrdinalIgnoreCase)
               || IanaId.Contains(value, StringComparison.OrdinalIgnoreCase)
               || Name(language).Contains(value, StringComparison.CurrentCultureIgnoreCase)
               || Zone.DisplayName.Contains(value, StringComparison.CurrentCultureIgnoreCase)
               || OffsetText(DateTimeOffset.Now).Replace(":", "").Contains(value.Replace(":", ""), StringComparison.OrdinalIgnoreCase);
    }

    public static IReadOnlyList<TimeZoneItem> Load() =>
        TimeZoneInfo.GetSystemTimeZones()
            .Select(zone => new TimeZoneItem(zone))
            .OrderBy(item => item.Zone.BaseUtcOffset)
            .ThenBy(item => item.Id, StringComparer.OrdinalIgnoreCase)
            .ToArray();
}
