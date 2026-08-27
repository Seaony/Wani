import SwiftUI

struct WaniSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var cloudSyncMonitor: WaniCloudSyncMonitor

    @AppStorage("appearance") private var appearanceRaw = WaniAppearance.system.rawValue
    @AppStorage("accent") private var accentRaw = WaniAccent.terracotta.rawValue
    @AppStorage("listDensity") private var densityRaw = WaniListDensity.medium.rawValue
    @AppStorage("dockCountMode") private var dockCountModeRaw = WaniDockCountMode.todayOnly.rawValue
    @AppStorage("launchDestination") private var launchDestinationRaw = WaniLaunchDestination.today.rawValue
    @AppStorage("textSize") private var textSizeRaw = WaniTextSize.standard.rawValue
    @AppStorage("groupTodayByProjectOrArea") private var groupTodayByProjectOrArea = true
    @AppStorage("keepWindowWidthWhenResizingSidebar") private var keepWindowWidth = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("showDockBadge") private var showDockBadge = false
    @AppStorage("deadlineNotificationsEnabled") private var deadlineNotificationsEnabled = true
    @AppStorage("moveToLogbookAtMidnight") private var moveToLogbookAtMidnight = false
    @AppStorage("showSidebarCounts") private var showSidebarCounts = true
    @AppStorage("showAreaLines") private var showAreaLines = true
    @AppStorage("quickEntryUsesCurrentList") private var quickEntryUsesCurrentList = true
    @AppStorage("globalQuickEntryShortcut") private var quickEntryShortcutRaw =
        WaniQuickEntryShortcut.controlSpace.rawValue

    @State private var launchAtLogin = false
    @State private var startupError = ""
    @State private var quickEntryShortcutError = ""

    init(cloudSyncEnabled: Bool) {
        _cloudSyncMonitor = StateObject(
            wrappedValue: WaniCloudSyncMonitor(enabled: cloudSyncEnabled)
        )
    }

    private var appearance: WaniAppearance {
        get { WaniAppearance(rawValue: appearanceRaw) ?? .system }
        nonmutating set { appearanceRaw = newValue.rawValue }
    }

    private var accent: WaniAccent {
        get { WaniAccent(rawValue: accentRaw) ?? .terracotta }
        nonmutating set { accentRaw = newValue.rawValue }
    }

    private var density: WaniListDensity {
        get { WaniListDensity(rawValue: densityRaw) ?? .medium }
        nonmutating set { densityRaw = newValue.rawValue }
    }

    private var dockCountMode: WaniDockCountMode {
        get { WaniDockCountMode(rawValue: dockCountModeRaw) ?? .todayOnly }
        nonmutating set { dockCountModeRaw = newValue.rawValue }
    }

    private var launchDestination: WaniLaunchDestination {
        get { WaniLaunchDestination(rawValue: launchDestinationRaw) ?? .today }
        nonmutating set { launchDestinationRaw = newValue.rawValue }
    }

    private var textSize: WaniTextSize {
        get { WaniTextSize(rawValue: textSizeRaw) ?? .standard }
        nonmutating set { textSizeRaw = newValue.rawValue }
    }

    private var quickEntryShortcut: WaniQuickEntryShortcut {
        get {
            WaniQuickEntryShortcut(rawValue: quickEntryShortcutRaw) ?? .controlSpace
        }
        nonmutating set { quickEntryShortcutRaw = newValue.rawValue }
    }

    private var palette: WaniPalette {
        WaniPalette(colorScheme: colorScheme, accent: accent)
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "slider.horizontal.3")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }

            quickEntryTab
                .tabItem {
                    Label("Quick Entry", systemImage: "plus.circle")
                }
        }
        .frame(width: 528, height: 430)
        .tint(palette.accent)
        .preferredColorScheme(appearance.colorScheme)
        .dynamicTypeSize(textSize.dynamicTypeSize)
        .onAppear {
            launchAtLogin = WaniStartupService.isEnabled
        }
        .onChange(of: quickEntryShortcutRaw) {
            quickEntryShortcutError =
                WaniGlobalHotKey.shared.register(quickEntryShortcut) ?? ""
        }
    }

    private var generalTab: some View {
        Form {
            Picker("Move completed items:", selection: $moveToLogbookAtMidnight) {
                Text("Immediately").tag(false)
                Text("At midnight").tag(true)
            }

            Picker(
                "Dock count:",
                selection: Binding(get: { dockCountMode }, set: { dockCountMode = $0 })
            ) {
                ForEach(WaniDockCountMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle("Show count on the Dock icon", isOn: $showDockBadge)

            Picker(
                "On launch, open:",
                selection: Binding(
                    get: { launchDestination },
                    set: { launchDestination = $0 }
                )
            ) {
                ForEach(WaniLaunchDestination.allCases) { destination in
                    Text(destination.title).tag(destination)
                }
            }

            LabeledContent("Text size:") {
                HStack(spacing: 10) {
                    Text("A")
                        .font(.system(size: 12))
                    Slider(
                        value: Binding(
                            get: {
                                Double(WaniTextSize.allCases.firstIndex(of: textSize) ?? 1)
                            },
                            set: { index in
                                textSize = WaniTextSize.allCases[Int(index.rounded())]
                            }
                        ),
                        in: 0...Double(WaniTextSize.allCases.count - 1),
                        step: 1
                    )
                    Text("A")
                        .font(.system(size: 18))
                }
                .frame(width: 250)
            }

            LabeledContent("") {
                Text(textSize.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 225, alignment: .center)
            }

            Divider()

            Toggle(
                "Group to-dos in the Today list by project or area",
                isOn: $groupTodayByProjectOrArea
            )
            Toggle(
                "Keep window width when resizing the sidebar",
                isOn: $keepWindowWidth
            )

            HStack {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Spacer()
                Button("Manage…") {
                    WaniStartupService.openManagement()
                }
            }

            Toggle("Show icon in the menu bar", isOn: $showMenuBarIcon)
            Toggle("Notify me about deadlines", isOn: $deadlineNotificationsEnabled)

            if !startupError.isEmpty {
                Text(startupError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("iCloud Sync") {
                syncSettings
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var appearanceTab: some View {
        Form {
            LabeledContent("Theme:") {
                HStack(spacing: 10) {
                    ForEach(WaniAppearance.allCases) { item in
                        themeCard(item)
                    }
                }
            }

            LabeledContent("Accent:") {
                HStack(spacing: 9) {
                    ForEach(WaniAccent.allCases) { item in
                        Button {
                            accent = item
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 20, height: 20)
                                .padding(3)
                                .overlay {
                                    if accent == item {
                                        Circle().stroke(item.color, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(item.title)
                        .accessibilityLabel(item.title)
                    }
                }
            }

            Picker(
                "List density:",
                selection: Binding(get: { density }, set: { density = $0 })
            ) {
                ForEach(WaniListDensity.allCases) { item in
                    Text(item.title).tag(item)
                }
            }

            Divider()

            Toggle("Show item counts in the sidebar", isOn: $showSidebarCounts)
            Toggle("Separator lines between areas", isOn: $showAreaLines)
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var quickEntryTab: some View {
        Form {
            LabeledContent("Quick Entry:") {
                HStack(spacing: 9) {
                    keycap("N")
                    Text("anywhere in the app")
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Search:") {
                keycap("⌘K")
            }

            LabeledContent("Dismiss:") {
                keycap("Esc")
            }

            Picker(
                "Global Quick Entry:",
                selection: Binding(
                    get: { quickEntryShortcut },
                    set: { quickEntryShortcut = $0 }
                )
            ) {
                ForEach(WaniQuickEntryShortcut.allCases) { shortcut in
                    Text(shortcut.title).tag(shortcut)
                }
            }

            if !quickEntryShortcutError.isEmpty {
                Text(quickEntryShortcutError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Toggle(
                "Send new items to the list I'm looking at",
                isOn: $quickEntryUsesCurrentList
            )

            Text("Off puts everything in the Inbox instead.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)
        }
        .formStyle(.grouped)
        .padding(20)
    }

    @ViewBuilder
    private var syncSettings: some View {
        LabeledContent("iCloud:") {
            HStack(alignment: .top, spacing: 9) {
                Circle()
                    .fill(syncStatusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(cloudSyncMonitor.accountState.title)
                    Text(cloudSyncMonitor.accountState.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        Divider()

        LabeledContent("Recent activity:") {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    cloudSyncMonitor.lastActivity
                        ?? "No CloudKit activity recorded this launch"
                )
                if let date = cloudSyncMonitor.lastActivityDate {
                    Text(date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !cloudSyncMonitor.lastError.isEmpty {
                    Text(cloudSyncMonitor.lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        LabeledContent("Status:") {
            Button("Check Again") {
                cloudSyncMonitor.refreshAccountStatus()
            }
        }
    }

    private func themeCard(_ item: WaniAppearance) -> some View {
        let previewColors = switch item {
        case .system: (Color(hex: 0xEDEEF0), Color(hex: 0x1F2123))
        case .light: (Color(hex: 0xEDEEF0), Color(hex: 0xFBFBFC))
        case .dark: (Color(hex: 0x151719), Color(hex: 0x1F2123))
        }

        return Button {
            appearance = item
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    previewColors.0.frame(width: 24)
                    previewColors.1
                }
                .frame(width: 72, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 5))

                Text(item.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
            }
            .padding(4)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        appearance == item ? palette.accent : palette.line,
                        lineWidth: appearance == item ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(appearance == item ? "Selected" : "")
    }

    private func keycap(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(palette.line, lineWidth: 0.5)
            }
    }

    private var syncStatusColor: Color {
        switch cloudSyncMonitor.accountState {
        case .available:
            Color(hex: 0x5B8C6C)
        case .checking:
            palette.accent
        case .localOnly:
            palette.tertiaryText
        case .noAccount, .restricted, .temporarilyUnavailable, .couldNotDetermine:
            Color(hex: 0xC3564C)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                do {
                    try WaniStartupService.setEnabled(enabled)
                    launchAtLogin = WaniStartupService.isEnabled
                    startupError = ""
                } catch {
                    launchAtLogin = WaniStartupService.isEnabled
                    startupError = error.localizedDescription
                }
            }
        )
    }
}
