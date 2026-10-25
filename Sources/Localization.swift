import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
    var localeIdentifier: String { self == .chinese ? "zh_CN" : "en_US" }
}

struct AppText: Sendable {
    let language: AppLanguage

    private func value(_ chinese: String, _ english: String) -> String {
        language == .chinese ? chinese : english
    }

    var subtitle: String { value("让聊天软件使用你选择的时区", "Launch chat apps in your chosen time zone") }
    var switchLanguage: String { value("切换语言", "Switch language") }
    var openGitHub: String { value("打开 Time Traveler GitHub 项目", "Open the Time Traveler GitHub project") }
    var selectLaunchTimeZone: String { value("选择启动时区", "Choose launch time zone") }
    var emptyTimeZoneHint: String { value("首次使用时为空，选择后会保存在本机", "Choose once and it will be saved on this Mac") }
    var clickToLaunch: String { value("点击图标启动", "Click an icon to launch") }
    var notInstalled: String { value("未安装", "Not installed") }
    var initialLaunchHint: String {
        value("首次点击应用时，如果尚未选择时区，会先打开时区选择器。", "If no time zone is selected, the picker opens before the app launches.")
    }
    var pickerSubtitle: String {
        value("聊天软件会按这个时区重新启动；系统时区会保持或恢复为原设置。", "The chat app will restart in this time zone; the system time zone stays unchanged or is restored automatically.")
    }
    var close: String { value("关闭", "Close") }
    var closeTimeZonePicker: String { value("关闭时区选择", "Close time zone picker") }
    var searchPlaceholder: String { value("搜索时区/城市，例如：utc9、北京", "Search time zone or city, e.g. utc9, Beijing") }
    var searchTimeZones: String { value("搜索全球时区", "Search global time zones") }
    var noSearchResults: String { value("未找到结果，试试 utc9、utc-8 或北京。", "No results. Try utc9, utc-8, or Beijing.") }
    var okay: String { value("好", "OK") }
    var cancel: String { value("取消", "Cancel") }
    var quitAndLaunch: String { value("退出并启动", "Quit and Launch") }
    var launchFailed: String { value("启动失败", "Launch Failed") }

    func catalogSummary(groupCount: Int, cityCount: Int) -> String {
        value("\(groupCount) 个时区 · \(cityCount) 个城市", "\(groupCount) time zones · \(cityCount) cities")
    }

    func clearLaunchTimeZone(_ city: String) -> String {
        value("清除\(city)启动时区", "Clear \(city) launch time zone")
    }

    func launchAccessibility(_ app: String) -> String {
        value("启动\(app)", "Launch \(app)")
    }

    func missingAccessibility(_ app: String) -> String {
        value("\(app)未安装，点击查看提示", "\(app) is not installed. Click for details")
    }

    func missingAppStatus(_ app: String) -> String {
        value("尚未安装\(app)，请安装后再试。", "\(app) is not installed. Install it and try again.")
    }

    func missingAppTitle(_ app: String) -> String {
        value("尚未安装\(app)", "\(app) Is Not Installed")
    }

    func missingAppBody(_ app: String) -> String {
        value("请先安装\(app)，然后再试。", "Install \(app), then try again.")
    }

    func restartAppTitle(_ app: String) -> String {
        value("重新启动\(app)？", "Restart \(app)?")
    }

    var restartAppBody: String {
        value(
            "时区只在启动时读取。继续操作会先退出当前进程，请确认没有未发送的内容。",
            "The time zone is read only at launch. Continuing will quit the current process, so make sure nothing is waiting to be sent."
        )
    }

    func launchingStatus(app: String, city: String) -> String {
        value("正在以\(city)时区启动\(app)…", "Launching \(app) in the \(city) time zone…")
    }

    func launchedStatus(app: String, city: String) -> String {
        value("\(app)已按\(city)时区启动。", "\(app) launched in the \(city) time zone.")
    }

    var systemSwitchFailed: String {
        value("系统时区未能临时切换到目标时区。", "The system time zone could not be switched temporarily.")
    }

    func appDidNotAppear(_ app: String) -> String {
        value("\(app)进程没有在预期时间内出现。", "The \(app) process did not appear in time.")
    }

    func systemRestoreFailed(_ originalTimeZone: String) -> String {
        value(
            "系统时区未能恢复为\(originalTimeZone)。请立即在系统设置中恢复。",
            "The system time zone could not be restored to \(originalTimeZone). Restore it in System Settings now."
        )
    }

    func systemMayNotHaveRestored(_ originalTimeZone: String, error: String) -> String {
        value(
            "应用可能已启动，但系统时区未能恢复为\(originalTimeZone)：\(error)",
            "The app may have launched, but the system time zone could not be restored to \(originalTimeZone): \(error)"
        )
    }

    func appDidNotQuit(_ app: String) -> String {
        value(
            "\(app)没有正常退出。请先手动退出后再试，避免丢失未发送内容。",
            "\(app) did not quit normally. Quit it manually and try again to avoid losing unsent content."
        )
    }

    var executableMissing: String {
        value("无法找到应用的可执行文件。", "The app executable could not be found.")
    }

    var administratorAuthorizationFailed: String {
        value("管理员授权失败。", "Administrator authorization failed.")
    }
}
