import AppKit
import Combine
import Foundation

enum LaunchStrategy {
    case environment
    case coldStart
}

struct AppSpec: Identifiable, Hashable {
    let name: String
    let bundleIdentifier: String
    let fallbackPath: String
    let strategy: LaunchStrategy
    var id: String { bundleIdentifier }
}

@MainActor
final class AppModel: ObservableObject {
    private static let selectedTimeZoneKey = "selectedLaunchTimeZone.v2"

    @Published private(set) var selectedTimeZone: Destination?
    @Published private(set) var now = Date()
    @Published private(set) var busyAppID: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusIsError = false

    let apps: [AppSpec] = [
        AppSpec(name: "飞书", bundleIdentifier: "com.electron.lark", fallbackPath: "/Applications/Lark.app", strategy: .coldStart),
        AppSpec(name: "微信", bundleIdentifier: "com.tencent.xinWeChat", fallbackPath: "/Applications/WeChat.app", strategy: .environment),
        AppSpec(name: "WhatsApp", bundleIdentifier: "net.whatsapp.WhatsApp", fallbackPath: "/Applications/WhatsApp.app", strategy: .environment),
        AppSpec(name: "Telegram", bundleIdentifier: "ru.keepcoder.Telegram", fallbackPath: "/Applications/Telegram.app", strategy: .environment),
    ]

    private let defaults: UserDefaults
    private var timer: Timer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.string(forKey: Self.selectedTimeZoneKey) {
            selectedTimeZone = Destination(rawValue: saved)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.now = Date() }
        }
    }

    func chooseTimeZone(_ destination: Destination) {
        selectedTimeZone = destination
        defaults.set(destination.rawValue, forKey: Self.selectedTimeZoneKey)
        statusMessage = nil
        statusIsError = false
    }

    func clearTimeZone() {
        selectedTimeZone = nil
        defaults.removeObject(forKey: Self.selectedTimeZoneKey)
        statusMessage = nil
        statusIsError = false
    }

    func applicationURL(for app: AppSpec) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            return url
        }
        guard FileManager.default.fileExists(atPath: app.fallbackPath) else { return nil }
        return URL(fileURLWithPath: app.fallbackPath)
    }

    func applicationIcon(for app: AppSpec) -> NSImage {
        guard let url = applicationURL(for: app) else {
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "未安装") ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func reportMissingApplication(_ app: AppSpec) {
        statusIsError = true
        statusMessage = "尚未安装\(app.name)，请安装后再试。"

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "尚未安装\(app.name)"
        alert.informativeText = "请先安装\(app.name)，然后再试。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    func launch(_ app: AppSpec) {
        guard busyAppID == nil else { return }
        guard let destination = selectedTimeZone else { return }
        guard let appURL = applicationURL(for: app) else {
            reportMissingApplication(app)
            return
        }

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        if !running.isEmpty {
            let alert = NSAlert()
            alert.messageText = "重新启动\(app.name)？"
            alert.informativeText = "时区只在启动时读取。继续操作会先退出当前进程，请确认没有未发送的内容。"
            alert.addButton(withTitle: "退出并启动")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        busyAppID = app.id
        statusIsError = false
        statusMessage = "正在以\(destination.city)时区启动\(app.name)…"

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try AppLaunchEngine.restartAndLaunch(app: app, appURL: appURL, timeZone: destination.rawValue)
                }.value
                statusIsError = false
                statusMessage = "\(app.name)已按\(destination.city)时区启动。"
            } catch {
                statusIsError = true
                statusMessage = error.localizedDescription
                let alert = NSAlert()
                alert.messageText = "启动失败"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "好")
                alert.runModal()
            }
            busyAppID = nil
        }
    }
}

private enum AppLaunchEngine {
    static func restartAndLaunch(app: AppSpec, appURL: URL, timeZone: String) throws {
        try terminateRunningApplications(for: app)

        let originalTimeZone = systemTimeZoneName()
        var switchedSystemTimeZone = false
        var capturedError: Error?

        do {
            if app.strategy == .coldStart && originalTimeZone != timeZone {
                let command = "/usr/sbin/systemsetup -settimezone \(shellQuote(timeZone)) >/dev/null; "
                    + "(/bin/sleep 45; /usr/sbin/systemsetup -settimezone \(shellQuote(originalTimeZone)) >/dev/null) >/dev/null 2>&1 &"
                try runAdministratorCommand(command)
                switchedSystemTimeZone = true
                guard waitForSystemTimeZone(timeZone, timeout: 10) else {
                    throw launchError("系统时区未能临时切换到目标时区。")
                }
            }

            try launchExecutable(appURL: appURL, timeZone: timeZone)
            Thread.sleep(forTimeInterval: app.strategy == .coldStart ? 15 : 3)
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
            guard let application = running.first else {
                throw launchError("\(app.name)进程没有在预期时间内出现。")
            }
            DispatchQueue.main.async {
                application.activate(options: [.activateIgnoringOtherApps])
            }
        } catch {
            capturedError = error
        }

        if switchedSystemTimeZone {
            do {
                try runAdministratorCommand("/usr/sbin/systemsetup -settimezone \(shellQuote(originalTimeZone)) >/dev/null")
                guard waitForSystemTimeZone(originalTimeZone, timeout: 10) else {
                    throw launchError("系统时区未能恢复为\(originalTimeZone)。请立即在系统设置中恢复。")
                }
            } catch {
                if capturedError == nil {
                    capturedError = launchError("应用可能已启动，但系统时区未能恢复为\(originalTimeZone)：\(error.localizedDescription)")
                }
            }
        }

        if let capturedError { throw capturedError }
    }

    private static func terminateRunningApplications(for app: AppSpec) throws {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        running.forEach { $0.terminate() }
        guard !running.isEmpty else { return }

        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
        throw launchError("\(app.name)没有正常退出。请先手动退出后再试，避免丢失未发送内容。")
    }

    private static func launchExecutable(appURL: URL, timeZone: String) throws {
        guard let executable = Bundle(url: appURL)?.executableURL else {
            throw launchError("无法找到应用的可执行文件。")
        }

        let process = Process()
        process.executableURL = executable
        process.currentDirectoryURL = appURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let inherited = ProcessInfo.processInfo.environment
        let allowedKeys = ["HOME", "USER", "LOGNAME", "TMPDIR", "PATH", "LANG", "LC_ALL", "LC_CTYPE", "SHELL"]
        var environment = Dictionary(uniqueKeysWithValues: allowedKeys.compactMap { key in
            inherited[key].map { (key, $0) }
        })
        environment["TZ"] = timeZone
        process.environment = environment

        let safeName = appURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "-").lowercased()
        let logURL = URL(fileURLWithPath: "/private/tmp/time-traveler-\(safeName).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logURL)
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        try? handle.close()
    }

    private static func systemTimeZoneName() -> String {
        if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: "/etc/localtime"),
           let range = destination.range(of: "/zoneinfo/") {
            return String(destination[range.upperBound...])
        }
        NSTimeZone.resetSystemTimeZone()
        return TimeZone.current.identifier
    }

    private static func waitForSystemTimeZone(_ name: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if systemTimeZoneName() == name { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    private static func runAdministratorCommand(_ command: String) throws {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")
        var dictionary: NSDictionary?
        guard script?.executeAndReturnError(&dictionary) != nil, dictionary == nil else {
            let message = dictionary?[NSAppleScript.errorMessage] as? String ?? "管理员授权失败。"
            throw launchError(message)
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func launchError(_ message: String) -> NSError {
        NSError(domain: "local.xubo.TimeTraveler", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
