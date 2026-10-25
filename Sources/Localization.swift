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
    var openGitHub: String { value("打开 Time Traveler GitHub 项目", "Open Time Traveler on GitHub") }
    var selectLaunchTimeZone: String { value("选择启动时区", "Choose a launch time zone") }
    var emptyTimeZoneHint: String { value("首次使用时为空，选择后会保存在本机", "Your selection will be saved on this Mac") }
    var clickToLaunch: String { value("点击图标启动", "Click an icon to launch") }
    var notInstalled: String { value("未安装", "Not installed") }
    var initialLaunchHint: String {
        value("首次点击应用时，如果尚未选择时区，会先打开时区选择器。", "If no time zone is selected, the picker opens before the app launches.")
    }
    var pickerSubtitle: String {
        value("聊天软件会按这个时区重新启动；系统时区会保持或恢复为原设置。", "The app will restart in the selected time zone. Your system time zone will stay unchanged or be restored automatically.")
    }
    var close: String { value("关闭", "Close") }
    var closeTimeZonePicker: String { value("关闭时区选择", "Close the time zone picker") }
    var searchPlaceholder: String { value("搜索时区/城市，例如：UTC+9、北京", "Search by time zone or city, e.g. UTC+9 or Beijing") }
    var searchTimeZones: String { value("搜索全球时区", "Search time zones and cities") }
    var noSearchResults: String { value("未找到结果，试试 UTC+9、UTC-8 或北京。", "No results. Try UTC+9, UTC-8, or Beijing.") }
    var okay: String { value("好", "OK") }
    var cancel: String { value("取消", "Cancel") }
    var quitAndLaunch: String { value("退出并启动", "Quit and Relaunch") }
    var launchFailed: String { value("启动失败", "Launch failed") }

    func catalogSummary(groupCount: Int, cityCount: Int) -> String {
        value("\(groupCount) 个 UTC 偏移 · \(cityCount) 个地点", "\(groupCount) UTC offsets · \(cityCount) locations")
    }

    func clearLaunchTimeZone() -> String {
        value("清除当前启动时区", "Clear selected time zone")
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
        value("尚未安装\(app)", "\(app) is not installed")
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
            "Time zone changes take effect only when an app starts. Continuing will quit the running app. Make sure you have no unsent messages."
        )
    }

    func launchingStatus(app: String, city: String) -> String {
        value("正在以\(city)时区启动\(app)…", "Launching \(app) in the \(city) time zone…")
    }

    func launchedStatus(app: String, city: String) -> String {
        value("\(app)已按\(city)时区启动。", "\(app) launched in the \(city) time zone.")
    }

    var systemSwitchFailed: String {
        value("系统时区未能临时切换到目标时区。", "Time Traveler couldn’t temporarily change the system time zone.")
    }

    func appDidNotAppear(_ app: String) -> String {
        value("\(app)进程没有在预期时间内出现。", "\(app) did not finish launching in time.")
    }

    func systemRestoreFailed(_ originalTimeZone: String) -> String {
        value(
            "系统时区未能恢复为\(originalTimeZone)。请立即在系统设置中恢复。",
            "Time Traveler couldn’t restore the system time zone to \(originalTimeZone). Restore it now in System Settings."
        )
    }

    func systemMayNotHaveRestored(_ originalTimeZone: String, error: String) -> String {
        value(
            "应用可能已启动，但系统时区未能恢复为\(originalTimeZone)：\(error)",
            "The app may have launched, but Time Traveler couldn’t restore the system time zone to \(originalTimeZone): \(error)"
        )
    }

    func appDidNotQuit(_ app: String) -> String {
        value(
            "\(app)没有正常退出。请先手动退出后再试，避免丢失未发送内容。",
            "Time Traveler couldn’t quit \(app). Quit it manually and try again to avoid losing unsent messages."
        )
    }

    var executableMissing: String {
        value("无法找到应用的可执行文件。", "The app executable could not be found.")
    }

    var administratorAuthorizationFailed: String {
        value("管理员授权失败。", "Administrator permission was not granted.")
    }
}
