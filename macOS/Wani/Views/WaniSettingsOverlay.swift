import SwiftUI

struct WaniSettingsOverlay: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case quickEntry = "Quick Entry"
        case sync = "Sync"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .general: "gearshape"
            case .appearance: "circle.lefthalf.filled"
            case .quickEntry: "keyboard"
            case .sync: "icloud"
            }
        }
    }

    let palette: WaniPalette
    @Binding var appearance: WaniAppearance
    @Binding var accent: WaniAccent
    @Binding var density: WaniListDensity
    @Binding var showCounts: Bool
    @Binding var showAreaLines: Bool
    @Binding var quickEntryUsesCurrentList: Bool
    @Binding var quickEntryShortcut: WaniQuickEntryShortcut
    let quickEntryShortcutError: String
    @Binding var launchDestination: WaniLaunchDestination
    @Binding var showMenuBarIcon: Bool
    @Binding var showDockBadge: Bool
    @Binding var deadlineNotificationsEnabled: Bool
    @Binding var moveToLogbookAtMidnight: Bool
    @ObservedObject var cloudSyncMonitor: WaniCloudSyncMonitor
    let dismiss: () -> Void

    @State private var tab: Tab = .appearance
    @State private var launchAtLogin = false
    @State private var startupError = ""

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 0) {
                titleBar
                Rectangle().fill(palette.line).frame(height: 1)
                tabBar
                Rectangle().fill(palette.line).frame(height: 1)

                Group {
                    switch tab {
                    case .general:
                        generalContent
                    case .appearance:
                        appearanceContent
                    case .quickEntry:
                        quickEntryContent
                    case .sync:
                        syncContent
                    }
                }
                .frame(minHeight: 258, alignment: .top)
            }
            .frame(width: 544)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.34), radius: 38, y: 20)
            .padding(.top, 78)
        }
        .onExitCommand(perform: dismiss)
        .onAppear {
            launchAtLogin = WaniStartupService.isEnabled
        }
    }

    private var titleBar: some View {
        HStack {
            Button(action: dismiss) {
                Circle().fill(Color(red: 0.94, green: 0.40, blue: 0.36))
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Settings")
            Circle().fill(palette.line).frame(width: 12, height: 12)
            Circle().fill(palette.line).frame(width: 12, height: 12)
            Spacer()
            Text(tab.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)
            Spacer()
            Color.clear.frame(width: 52, height: 1)
        }
        .padding(.horizontal, 13)
        .frame(height: 52)
        .background(palette.sidebar)
    }

    private var tabBar: some View {
        HStack(spacing: 1) {
            ForEach(Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 19, weight: .regular))
                        Text(item.rawValue)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(tab == item ? palette.accent : palette.secondaryText)
                    .frame(width: 92, height: 48)
                    .background(
                        tab == item ? palette.softAccent : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.rawValue)
                .accessibilityIdentifier("settings-tab-\(item.rawValue)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(palette.sidebar)
    }

    private var appearanceContent: some View {
        VStack(spacing: 13) {
            settingRow("Theme", alignment: .top) {
                HStack(spacing: 11) {
                    ForEach(WaniAppearance.allCases) { item in
                        themeCard(item)
                    }
                }
            }

            divider

            settingRow("Accent") {
                HStack(spacing: 10) {
                    ForEach(WaniAccent.allCases) { item in
                        Button {
                            accent = item
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 19, height: 19)
                                .padding(3)
                                .overlay {
                                    if accent == item {
                                        Circle().stroke(item.color, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                    }
                }
            }

            divider

            settingRow("Sidebar", alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    preferenceToggle("Show item counts", isOn: $showCounts)
                    preferenceToggle("Separator lines between areas", isOn: $showAreaLines)
                }
            }

            settingRow("List density") {
                Picker("List density", selection: $density) {
                    ForEach(WaniListDensity.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private var generalContent: some View {
        VStack(spacing: 13) {
            settingRow("Startup", alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    preferenceToggle("Launch at login", isOn: launchAtLoginBinding)
                    preferenceToggle("Show icon in the menu bar", isOn: $showMenuBarIcon)
                    preferenceToggle("Badge the Dock icon with today's count", isOn: $showDockBadge)

                    if !startupError.isEmpty {
                        Text(startupError)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            divider

            settingRow("On launch, open") {
                Picker("On launch, open", selection: $launchDestination) {
                    ForEach(WaniLaunchDestination.allCases) { destination in
                        Text(destination.title).tag(destination)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            settingRow("Notifications") {
                preferenceToggle(
                    "Notify me about deadlines",
                    isOn: $deadlineNotificationsEnabled
                )
            }

            divider

            settingRow("Completed items", alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    preferenceToggle(
                        "Move to Logbook at midnight",
                        isOn: $moveToLogbookAtMidnight
                    )
                    Text("Until then they stay visible inside their project.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.tertiaryText)
                        .padding(.leading, 23)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private var quickEntryContent: some View {
        VStack(spacing: 13) {
            settingRow("In-app Quick Entry") {
                HStack(spacing: 7) {
                    Text("N")
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(palette.card, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.line, lineWidth: 0.5))
                    Text("anywhere in the app")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.tertiaryText)
                }
            }

            settingRow("Global Quick Entry", alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Global Quick Entry", selection: $quickEntryShortcut) {
                        ForEach(WaniQuickEntryShortcut.allCases) { shortcut in
                            Text(shortcut.title).tag(shortcut)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)

                    if !quickEntryShortcutError.isEmpty {
                        Text(quickEntryShortcutError)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            settingRow("Search") {
                keycap("⌘K")
            }

            settingRow("Dismiss") {
                keycap("Esc")
            }

            divider

            settingRow("New items go to", alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    preferenceToggle(
                        "The list I'm looking at",
                        isOn: $quickEntryUsesCurrentList
                    )
                    Text("Off puts everything in the Inbox instead.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.tertiaryText)
                        .padding(.leading, 23)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private var syncContent: some View {
        VStack(spacing: 13) {
            settingRow("iCloud", alignment: .top) {
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(syncStatusColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cloudSyncMonitor.accountState.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.text)
                        Text(cloudSyncMonitor.accountState.detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(palette.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            divider

            settingRow("Recent activity", alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cloudSyncMonitor.lastActivity ?? "No CloudKit activity recorded this launch")
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.secondaryText)
                    if let date = cloudSyncMonitor.lastActivityDate {
                        Text(date.formatted(date: .abbreviated, time: .standard))
                            .font(.system(size: 11.5))
                            .foregroundStyle(palette.tertiaryText)
                    }
                    if !cloudSyncMonitor.lastError.isEmpty {
                        Text(cloudSyncMonitor.lastError)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            settingRow("Status") {
                Button("Check Again") {
                    cloudSyncMonitor.refreshAccountStatus()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.accent)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    private var syncStatusColor: Color {
        switch cloudSyncMonitor.accountState {
        case .available:
            Color(red: 0.36, green: 0.55, blue: 0.42)
        case .checking:
            palette.accent
        case .localOnly:
            palette.tertiaryText
        case .noAccount, .restricted, .temporarilyUnavailable, .couldNotDetermine:
            Color(red: 0.76, green: 0.34, blue: 0.30)
        }
    }

    private func themeCard(_ item: WaniAppearance) -> some View {
        Button {
            appearance = item
        } label: {
            VStack(spacing: 7) {
                HStack(spacing: 0) {
                    Color(hex: item == .light ? 0xEFE7DB : 0x231E1A)
                        .frame(width: 42)
                    Color(hex: item == .light ? 0xFAF5ED : 0x1E1A16)
                }
                .frame(height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(item.title)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.text)
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(appearance == item ? palette.accent : palette.line, lineWidth: appearance == item ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }

    private func settingRow<Content: View>(
        _ title: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: alignment, spacing: 14) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryText)
                .frame(width: 150, alignment: .trailing)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func preferenceToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .font(.system(size: 13))
            .foregroundStyle(palette.text)
            .tint(palette.accent)
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

    private func keycap(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.line, lineWidth: 0.5))
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.faintLine)
            .frame(height: 1)
            .padding(.vertical, 3)
    }
}
