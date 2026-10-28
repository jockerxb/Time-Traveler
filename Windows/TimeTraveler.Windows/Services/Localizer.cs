namespace TimeTraveler.Windows.Services;

public sealed class Localizer
{
    public AppLanguage Language { get; }

    public Localizer(AppLanguage language) => Language = language;

    private string Pick(string chinese, string english) => Language == AppLanguage.Chinese ? chinese : english;

    public string Subtitle => Pick("让聊天软件使用你选择的时区", "Launch chat apps in your chosen time zone");
    public string SwitchLanguage => Pick("切换语言", "Switch language");
    public string OpenGitHub => Pick("打开 Time Traveler GitHub 项目", "Open Time Traveler on GitHub");
    public string ChooseTimeZone => Pick("选择启动时区", "Choose a launch time zone");
    public string EmptyTimeZone => Pick("首次使用时为空，选择后会保存在本机", "Your selection will be saved on this PC");
    public string ClickToLaunch => Pick("点击图标启动", "Click an icon to launch");
    public string NotInstalled => Pick("未安装", "Not installed");
    public string InitialHint => Pick("首次点击应用时，如果尚未选择时区，会先打开时区选择器。", "If no time zone is selected, the picker opens before the app launches.");
    public string WindowsHint => Pick("Windows 兼容模式会短暂切换系统时区，并在启动后自动恢复。", "Windows compatibility mode briefly changes the system time zone and restores it after launch.");
    public string SearchPlaceholder => Pick("搜索时区或城市，例如 UTC+8、北京", "Search by time zone or city, e.g. UTC+8 or Beijing");
    public string NoResults => Pick("未找到匹配的时区", "No matching time zones");
    public string Cancel => Pick("取消", "Cancel");
    public string Close => Pick("关闭", "Close");
    public string NotInstalledTitle(string app) => Pick($"尚未安装{app}", $"{app} is not installed");
    public string NotInstalledBody(string app) => Pick($"未找到{app}。请安装后再试。", $"Time Traveler could not find {app}. Install it and try again.");
    public string RestartTitle(string app) => Pick($"重新启动{app}？", $"Relaunch {app}?");
    public string RestartBody => Pick("时区只在启动时读取。继续会先正常退出当前进程，请确认没有未发送的内容。", "Time zone changes take effect only when an app starts. Continuing will quit the running app. Make sure you have no unsent messages.");
    public string Launching(string app) => Pick($"正在按所选时区启动{app}…", $"Launching {app} in the selected time zone…");
    public string LaunchSucceeded(string app) => Pick($"{app}已启动，系统时区已恢复。", $"{app} launched and the system time zone was restored.");
    public string LaunchFailed => Pick("启动失败", "Launch failed");
    public string PermissionDenied => Pick("未获得管理员权限，无法临时切换系统时区。", "Administrator permission was not granted, so the system time zone could not be changed temporarily.");
    public string RestoreFailed(string zone) => Pick($"系统时区未能恢复为 {zone}。请立即在 Windows 设置中恢复。", $"The system time zone could not be restored to {zone}. Restore it now in Windows Settings.");
    public string AppDidNotQuit(string app) => Pick($"{app}没有正常退出。请手动退出后再试。", $"{app} did not quit. Quit it manually and try again.");
    public string GitHubLabel => "GitHub";
    public string PickerSubtitle => Pick("按城市、Windows 时区或 UTC 偏移搜索", "Search by city, Windows time zone, or UTC offset");
    public string UseThisTimeZone => Pick("使用此时区", "Use this time zone");
    public string ClearTimeZone => Pick("清除当前时区", "Clear current time zone");
    public string Confirm => Pick("继续", "Continue");
    public string UnexpectedError => Pick("发生未知错误。", "An unexpected error occurred.");
}
