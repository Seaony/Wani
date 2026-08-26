import SwiftUI

struct WaniSettingsOverlay: View {
    enum Tab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case quickEntry = "Quick Entry"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .appearance: "circle.lefthalf.filled"
            case .quickEntry: "keyboard"
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
    let dismiss: () -> Void

    @State private var tab: Tab = .appearance

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
                    case .appearance:
                        appearanceContent
                    case .quickEntry:
                        quickEntryContent
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

    private var quickEntryContent: some View {
        VStack(spacing: 13) {
            settingRow("Quick Entry") {
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
