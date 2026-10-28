namespace TimeTraveler.Windows.Models;

public sealed class UserSettings
{
    public string? SelectedTimeZoneId { get; set; }
    public AppLanguage Language { get; set; } = AppLanguage.Chinese;
}
