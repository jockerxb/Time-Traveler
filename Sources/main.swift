import AppKit
import Combine
import SwiftUI

private let accent = Color(red: 0.12, green: 0.43, blue: 0.92)
private let warm = Color(red: 0.96, green: 0.58, blue: 0.08)
private let projectURL = URL(string: "https://github.com/jockerxb/Time-Traveler")!

struct TimeTravelerView: View {
    @ObservedObject var model: AppModel
    @State private var pickerPresented = false
    @State private var pendingApp: AppSpec?

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
            ZonePicker(selected: model.selectedTimeZone) { destination in
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
                Text("让聊天软件使用你选择的时区")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Link(destination: projectURL) {
                Label("GitHub", systemImage: "arrow.up.right.square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(accent.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("打开 Time Traveler GitHub 项目")
            .accessibilityLabel("打开 Time Traveler GitHub 项目")
        }
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
                            Text(zone.city)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("\(zone.offset(at: model.now)) · \(zone.time(at: model.now))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("选择启动时区")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("首次使用时为空，选择后会保存在本机")
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
            if let zone = model.selectedTimeZone {
                Button(role: .destructive) {
                    model.clearTimeZone()
                } label: {
                    Label("清除\(zone.city)启动时区", systemImage: "trash")
                }
            }
        }
    }

    private var appLauncher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("点击图标启动")
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
            guard installed else { return }
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
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(installed ? .primary : .secondary)
                    .lineLimit(1)
                if !installed {
                    Text("未安装")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(AppIconButtonStyle())
        .disabled(!installed || model.busyAppID != nil)
        .opacity(installed ? 1 : 0.48)
        .accessibilityLabel(installed ? "启动\(app.name)" : "\(app.name)未安装")
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
                Text("首次点击应用时，如果尚未选择时区，会先打开时区选择器。")
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
    @Published private(set) var groups: [ZoneCatalog.OffsetGroup]
    var summary: String { "\(groups.count) 个时区 · \(groups.reduce(0) { $0 + $1.zones.count }) 个城市" }

    init() {
        let date = Date()
        referenceDate = date
        groups = ZoneCatalog.groups("", at: date)
    }

    func search(_ query: String) {
        groups = ZoneCatalog.groups(query, at: referenceDate)
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
    let onSelect: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var visibleOffset: Int?
    @StateObject private var catalog = PickerCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择启动时区").font(.system(size: 18, weight: .semibold))
                    Text("聊天软件会按这个时区重新启动；系统时区保持原设置。")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Label("关闭", systemImage: "xmark") }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("关闭时区选择")
            }

            TextField("搜索时区/城市，例如：utc9、北京", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("搜索全球时区")

            Text(catalog.summary)
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
                                        Text(zone.city).font(.system(size: 13, weight: .medium))
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
                Text("未找到结果，试试 utc9、utc-8 或北京。")
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
