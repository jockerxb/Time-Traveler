import AppKit
import Combine
import SwiftUI

private let accent = Color(red: 0.12, green: 0.43, blue: 0.92)
private let warm = Color(red: 0.96, green: 0.58, blue: 0.08)
private let projectURL = URL(string: "https://github.com/jockerxb/Time-Traveler")!

struct TimeTravelerView: View {
    @ObservedObject var model: AppModel
    @State private var pickerPresented = false
    @State private var languagePopoverPresented = false
    @State private var pendingApp: AppSpec?
    private var text: AppText { AppText(language: model.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            timeZoneSelector
            appLauncher
            status
        }
        .padding(28)
        .frame(width: 570)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $pickerPresented, onDismiss: {
            pendingApp = nil
        }) {
            ZonePicker(selected: model.selectedTimeZone, language: model.language) { destination in
                let appToLaunch = pendingApp
                pendingApp = nil
                model.chooseTimeZone(destination)
                pickerPresented = false
                if let appToLaunch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        model.launch(appToLaunch)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Traveler")
                    .font(.system(size: 24, weight: .semibold))
                Text(text.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
            languageMenu
            Link(destination: projectURL) {
                Label("GitHub", systemImage: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(accent)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(text.openGitHub)
            .accessibilityLabel(text.openGitHub)
        }
    }

    private var languageMenu: some View {
        Button {
            languagePopoverPresented.toggle()
        } label: {
            Image(systemName: "translate")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(accent)
                .frame(width: 42, height: 34)
                .background(accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(text.switchLanguage)
        .accessibilityLabel(text.switchLanguage)
        .popover(isPresented: $languagePopoverPresented, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                languageOption(.chinese, title: "中文")
                languageOption(.english, title: "English")
            }
            .padding(7)
            .frame(width: 160)
        }
    }

    private func languageOption(_ language: AppLanguage, title: String) -> some View {
        Button {
            model.chooseLanguage(language)
            languagePopoverPresented = false
        } label: {
            HStack {
                Text(title)
                Spacer()
                if model.language == language {
                    Image(systemName: "checkmark")
                        .foregroundColor(accent)
                }
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var timeZoneSelector: some View {
        HStack(spacing: 0) {
            Button {
                pendingApp = nil
                pickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: model.selectedTimeZone == nil ? "globe.badge.chevron.backward" : "globe.asia.australia.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(model.selectedTimeZone == nil ? .secondary : accent)
                        .frame(width: 28)
                    if let zone = model.selectedTimeZone {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(zone.displayCity(in: model.language))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("\(zone.offset(at: model.now)) · \(zone.time(at: model.now, language: model.language))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(text.selectLaunchTimeZone)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(text.emptyTimeZoneHint)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 15)
                .padding(.trailing, 15)
                .frame(maxWidth: .infinity, minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(model.selectedTimeZone == nil ? warm.opacity(0.35) : accent.opacity(0.28), lineWidth: 1)
        }
        .contextMenu {
            if model.selectedTimeZone != nil {
                Button(role: .destructive) {
                    model.clearTimeZone()
                } label: {
                    Label(text.clearLaunchTimeZone(), systemImage: "trash")
                }
            }
        }
    }

    private var appLauncher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text.clickToLaunch)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 12) {
                ForEach(model.apps) { app in
                    appButton(app)
                }
            }
        }
    }

    private func appButton(_ app: AppSpec) -> some View {
        let installed = model.applicationURL(for: app) != nil
        let busy = model.busyAppID == app.id
        return Button {
            guard installed else {
                model.reportMissingApplication(app)
                return
            }
            if model.selectedTimeZone == nil {
                pendingApp = app
                pickerPresented = true
            } else {
                model.launch(app)
            }
        } label: {
            VStack(spacing: 9) {
                ZStack {
                    Image(nsImage: model.applicationIcon(for: app))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 60, height: 60)
                    if busy {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                            .frame(width: 64, height: 64)
                        ProgressView().controlSize(.small).tint(.white)
                    }
                }
                .frame(width: 72, height: 72)
                Text(app.displayName(in: model.language))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(installed ? .primary : .secondary)
                    .lineLimit(1)
                if !installed {
                    Text(text.notInstalled)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppIconButtonStyle())
        .disabled(model.busyAppID != nil)
        .opacity(installed ? 1 : 0.48)
        .accessibilityLabel(
            installed
                ? text.launchAccessibility(app.displayName(in: model.language))
                : text.missingAccessibility(app.displayName(in: model.language))
        )
    }

    private var status: some View {
        HStack(spacing: 7) {
            if let message = model.statusMessage {
                Image(systemName: model.statusIsError ? "exclamationmark.circle.fill" : (model.busyAppID == nil ? "checkmark.circle.fill" : "clock.fill"))
                    .foregroundColor(model.statusIsError ? .red : accent)
                Text(message)
                    .foregroundColor(model.statusIsError ? .red : .secondary)
            } else {
                Image(systemName: "info.circle")
                Text(text.initialLaunchHint)
            }
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.06) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

final class PickerCatalog: ObservableObject {
    private let referenceDate: Date
    private var language: AppLanguage
    private var query = ""
    @Published private(set) var groups: [ZoneCatalog.OffsetGroup]

    init(language: AppLanguage) {
        let date = Date()
        referenceDate = date
        self.language = language
        groups = ZoneCatalog.groups("", at: date, language: language)
    }

    func search(_ query: String) {
        self.query = query
        groups = ZoneCatalog.groups(query, at: referenceDate, language: language)
    }

    func changeLanguage(_ language: AppLanguage) {
        self.language = language
        groups = ZoneCatalog.groups(query, at: referenceDate, language: language)
    }

    func summary(in language: AppLanguage) -> String {
        AppText(language: language).catalogSummary(
            groupCount: groups.count,
            cityCount: groups.reduce(0) { $0 + $1.zones.count }
        )
    }
}

private struct OffsetPositions: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct ZonePicker: View {
    let selected: Destination?
    let language: AppLanguage
    let onSelect: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var visibleOffset: Int?
    @StateObject private var catalog: PickerCatalog
    private var text: AppText { AppText(language: language) }

    init(selected: Destination?, language: AppLanguage, onSelect: @escaping (Destination) -> Void) {
        self.selected = selected
        self.language = language
        self.onSelect = onSelect
        _catalog = StateObject(wrappedValue: PickerCatalog(language: language))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(text.selectLaunchTimeZone).font(.system(size: 18, weight: .semibold))
                    Text(text.pickerSubtitle)
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Label(text.close, systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel(text.closeTimeZonePicker)
            }

            TextField(text.searchPlaceholder, text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(text.searchTimeZones)

            Text(catalog.summary(in: language))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: 8) {
                    catalogList.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !catalog.groups.isEmpty {
                        VStack(spacing: 4) {
                            Text("UTC").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary)
                            ScrollView {
                                VStack(spacing: 1) {
                                    ForEach(catalog.groups) { group in
                                        Button {
                                            proxy.scrollTo("offset-\(group.id)", anchor: .top)
                                        } label: {
                                            Text(group.indexTitle)
                                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 20)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(accent)
                                    }
                                }
                            }
                        }
                        .frame(width: 58)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(22)
        .frame(width: 570, height: 590)
        .onChange(of: search) { query in
            visibleOffset = nil
            catalog.search(query)
        }
        .onChange(of: language) { newLanguage in
            visibleOffset = nil
            catalog.changeLanguage(newLanguage)
        }
    }

    private var currentGroup: ZoneCatalog.OffsetGroup? {
        catalog.groups.first { $0.id == visibleOffset } ?? catalog.groups.first
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundColor(accent)
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var catalogList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(catalog.groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        groupHeader(group.title).accessibilityHidden(currentGroup?.id == group.id)
                        ForEach(group.zones) { zone in
                            let isSelected = selected?.isSameLocation(as: zone) == true
                            Button {
                                onSelect(zone)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(zone.displayCity(in: language)).font(.system(size: 13, weight: .medium))
                                        Text(zone.rawValue)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(accent)
                                    }
                                    Text(group.title)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .contentShape(Rectangle())
                                .background(isSelected ? accent.opacity(0.06) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.horizontal, 8)
                        }
                    }
                    .background(GeometryReader { geometry in
                        Color.clear.preference(
                            key: OffsetPositions.self,
                            value: [group.id: geometry.frame(in: .named("catalogScroll")).minY]
                        )
                    })
                    .id("offset-\(group.id)")
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .coordinateSpace(name: "catalogScroll")
        .onPreferenceChange(OffsetPositions.self) { positions in
            let offset = positions.filter { $0.value <= 1 }.max { $0.value < $1.value }?.key
            if visibleOffset != offset { visibleOffset = offset }
        }
        .id(search)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .topLeading) {
            if let currentGroup {
                groupHeader(currentGroup.title)
                    .background(Color(nsColor: .textBackgroundColor))
                    .padding(.horizontal, 6)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            if catalog.groups.isEmpty {
                Text(text.noSearchResults)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct TimeTravelerApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Time Traveler") {
            TimeTravelerView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
