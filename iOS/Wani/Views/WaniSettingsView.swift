import SwiftUI

struct WaniSettingsView: View {
    @AppStorage("wani.appearance") private var appearanceRawValue = WaniAppearance.system.rawValue
    @AppStorage("wani.accent") private var accentRawValue = WaniAccent.terracotta.rawValue
    @AppStorage("wani.compactRows") private var compactRows = false
    @AppStorage("wani.badge") private var badge = true
    @AppStorage("wani.deadlineNotifications") private var deadlineNotifications = true
    @AppStorage("wani.showCounts") private var showCounts = true
    @AppStorage("wani.logAtMidnight") private var logAtMidnight = true
    let palette: WaniPalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(palette.text)
                settingsSection("Appearance") {
                    Picker("Appearance", selection: $appearanceRawValue) {
                        ForEach(WaniAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    Divider().overlay(palette.line)
                    HStack {
                        Text("Accent")
                        Spacer()
                        ForEach(WaniAccent.allCases) { accent in
                            Button { accentRawValue = accent.rawValue } label: {
                                Circle()
                                    .fill(accent.color)
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if accentRawValue == accent.rawValue {
                                            Circle().stroke(palette.group, lineWidth: 2)
                                            Circle().stroke(accent.color, lineWidth: 1).padding(-3)
                                        }
                                    }
                            }
                            .accessibilityLabel(accent.title)
                        }
                    }
                    Divider().overlay(palette.line)
                    Toggle("Compact rows", isOn: $compactRows)
                }
                settingsSection("General") {
                    Toggle("Badge the app icon", isOn: $badge)
                    Divider().overlay(palette.line)
                    Toggle("Notify me about deadlines", isOn: $deadlineNotifications)
                    Divider().overlay(palette.line)
                    Toggle("Show item counts", isOn: $showCounts)
                    Divider().overlay(palette.line)
                    Toggle("Move completed to Logbook at midnight", isOn: $logAtMidnight)
                }
                settingsSection("Capture") {
                    settingsValue("Share sheet", value: "On")
                    Divider().overlay(palette.line)
                    settingsValue("Siri & Shortcuts", value: "3 phrases")
                    Divider().overlay(palette.line)
                    settingsValue("Widgets", value: "Ready")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 80)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar { WaniNavigationToolbar(palette: palette) }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11.5, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(palette.tertiary)
                .padding(.horizontal, 6)
            VStack(spacing: 12) { content() }
                .font(.system(size: 15.5))
                .foregroundStyle(palette.text)
                .padding(15)
                .background(palette.group, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(palette.line, lineWidth: 0.5))
        }
    }

    private func settingsValue(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(palette.tertiary)
        }
    }
}
