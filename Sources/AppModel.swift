import AppKit
import Combine
import Foundation

enum LaunchStrategy {
    case environment
    case coldStart
}

struct AppSpec: Identifiable, Hashable {
    let chineseName: String
    let englishName: String
    let bundleIdentifier: String
    let fallbackPath: String
    let strategy: LaunchStrategy
    var id: String { bundleIdentifier }
    func displayName(in language: AppLanguage) -> String { language == .chinese ? chineseName : englishName }
}

@MainActor
final class AppModel: ObservableObject {
    private static let selectedTimeZoneKey = "selectedLaunchTimeZone.v2"
    private static let languageKey = "appLanguage.v1"

    @Published private(set) var selectedTimeZone: Destination?
    @Published private(set) var language: AppLanguage
    @Published private(set) var now = Date()
    @Published private(set) var busyAppID: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var statusIsError = false

    let apps: [AppSpec] = [
        AppSpec(chineseName: "飞书", englishName: "Feishu", bundleIdentifier: "com.electron.lark", fallbackPath: "/Applications/Lark.app", strategy: .coldStart),
        AppSpec(chineseName: "微信", englishName: "WeChat", bundleIdentifier: "com.tencent.xinWeChat", fallbackPath: "/Applications/WeChat.app", strategy: .environment),
        AppSpec(chineseName: "WhatsApp", englishName: "WhatsApp", bundleIdentifier: "net.whatsapp.WhatsApp", fallbackPath: "/Applications/WhatsApp.app", strategy: .environment),
        AppSpec(chineseName: "Telegram", englishName: "Telegram", bundleIdentifier: "ru.keepcoder.Telegram", fallbackPath: "/Applications/Telegram.app", strategy: .environment),
    ]

    private let defaults: UserDefaults
    private var timer: Timer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.string(forKey: Self.languageKey), let savedLanguage = AppLanguage(rawValue: saved) {
            language = savedLanguage
        } else {
            language = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
        }
        if let saved = defaults.string(forKey: Self.selectedTimeZoneKey) {
            selectedTimeZone = Destination(rawValue: saved)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.now = Date() }
        }
    }

    func chooseLanguage(_ newLanguage: AppLanguage) {
        language = newLanguage
        defaults.set(newLanguage.rawValue, forKey: Self.languageKey)
        statusMessage = nil
        statusIsError = false
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
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: AppText(language: language).notInstalled) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func reportMissingApplication(_ app: AppSpec) {
        let text = AppText(language: language)
        let appName = app.displayName(in: language)
        statusIsError = true
        statusMessage = text.missingAppStatus(appName)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = text.missingAppTitle(appName)
        alert.informativeText = text.missingAppBody(appName)
        alert.addButton(withTitle: text.okay)
        alert.runModal()
    }

    func launch(_ app: AppSpec) {
        guard busyAppID == nil else { return }
        guard let destination = selectedTimeZone else { return }
        guard let appURL = applicationURL(for: app) else {
            reportMissingApplication(app)
            return
        }

        let launchLanguage = language
        let text = AppText(language: launchLanguage)
        let appName = app.displayName(in: launchLanguage)
        let city = destination.displayCity(in: launchLanguage)

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        if !running.isEmpty {
            let alert = NSAlert()
            alert.messageText = text.restartAppTitle(appName)
            alert.informativeText = text.restartAppBody
            alert.addButton(withTitle: text.quitAndLaunch)
            alert.addButton(withTitle: text.cancel)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        busyAppID = app.id
        statusIsError = false
        statusMessage = text.launchingStatus(app: appName, city: city)

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try AppLaunchEngine.restartAndLaunch(app: app, appURL: appURL, timeZone: destination.rawValue, language: launchLanguage)
                }.value
                statusIsError = false
                let currentText = AppText(language: language)
                statusMessage = currentText.launchedStatus(
                    app: app.displayName(in: language),
                    city: destination.displayCity(in: language)
                )
            } catch {
                statusIsError = true
                statusMessage = error.localizedDescription
                let alert = NSAlert()
                alert.messageText = AppText(language: language).launchFailed
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: AppText(language: language).okay)
                alert.runModal()
            }
            busyAppID = nil
        }
    }
}

private enum AppLaunchEngine {
    static func restartAndLaunch(app: AppSpec, appURL: URL, timeZone: String, language: AppLanguage) throws {
        let text = AppText(language: language)
        let appName = app.displayName(in: language)
        try terminateRunningApplications(for: app, language: language)

        let originalTimeZone = systemTimeZoneName()
        var switchedSystemTimeZone = false
        var capturedError: Error?

        do {
            if app.strategy == .coldStart && originalTimeZone != timeZone {
                let command = "/usr/sbin/systemsetup -settimezone \(shellQuote(timeZone)) >/dev/null; "
                    + "(/bin/sleep 45; /usr/sbin/systemsetup -settimezone \(shellQuote(originalTimeZone)) >/dev/null) >/dev/null 2>&1 &"
                try runAdministratorCommand(command, language: language)
                switchedSystemTimeZone = true
                guard waitForSystemTimeZone(timeZone, timeout: 10) else {
                    throw launchError(text.systemSwitchFailed)
                }
            }

            try launchExecutable(appURL: appURL, timeZone: timeZone, language: language)
            Thread.sleep(forTimeInterval: app.strategy == .coldStart ? 15 : 3)
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
            guard let application = running.first else {
                throw launchError(text.appDidNotAppear(appName))
            }
            DispatchQueue.main.async {
                application.activate(options: [.activateIgnoringOtherApps])
            }
        } catch {
            capturedError = error
        }

        if switchedSystemTimeZone {
            do {
                try runAdministratorCommand("/usr/sbin/systemsetup -settimezone \(shellQuote(originalTimeZone)) >/dev/null", language: language)
                guard waitForSystemTimeZone(originalTimeZone, timeout: 10) else {
                    throw launchError(text.systemRestoreFailed(originalTimeZone))
                }
            } catch {
                if capturedError == nil {
                    capturedError = launchError(text.systemMayNotHaveRestored(originalTimeZone, error: error.localizedDescription))
                }
            }
        }

        if let capturedError { throw capturedError }
    }

    private static func terminateRunningApplications(for app: AppSpec, language: AppLanguage) throws {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        running.forEach { $0.terminate() }
        guard !running.isEmpty else { return }

        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
        throw launchError(AppText(language: language).appDidNotQuit(app.displayName(in: language)))
    }

    private static func launchExecutable(appURL: URL, timeZone: String, language: AppLanguage) throws {
        guard let executable = Bundle(url: appURL)?.executableURL else {
            throw launchError(AppText(language: language).executableMissing)
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

    private static func runAdministratorCommand(_ command: String, language: AppLanguage) throws {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")
        var dictionary: NSDictionary?
        guard script?.executeAndReturnError(&dictionary) != nil, dictionary == nil else {
            let message = dictionary?[NSAppleScript.errorMessage] as? String ?? AppText(language: language).administratorAuthorizationFailed
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
