import SwiftUI

struct WaniSidebar: View {
    let palette: WaniPalette
    let areas: [WaniArea]
    let projects: [WaniProject]
    let counts: [WaniSmartList: Int]
    @Binding var selection: WaniNavigationTarget
    let openSearch: () -> Void

    private let primaryLists: [WaniSmartList] = [
        .inbox, .today, .upcoming, .anytime, .someday,
    ]
    private let archiveLists: [WaniSmartList] = [.logbook, .trash]

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 46)

            Button(action: openSearch) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                    Spacer()
                    Text("⌘K")
                        .font(.system(size: 11))
                }
                .foregroundStyle(palette.tertiaryText)
                .font(.system(size: 12.5))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)
            .accessibilityLabel("Search")
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(primaryLists) { list in
                        smartListRow(list)
                    }

                    divider

                    ForEach(archiveLists) { list in
                        smartListRow(list)
                    }

                    divider

                    ForEach(areas) { area in
                        areaSection(area)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }

            Rectangle()
                .fill(palette.line)
                .frame(height: 1)

            HStack {
                Label("New List", systemImage: "plus")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(palette.tertiaryText)
                    .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 18)
            .frame(height: 46)
        }
        .background(palette.sidebar)
    }

    private func smartListRow(_ list: WaniSmartList) -> some View {
        Button {
            selection = .smart(list)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: list.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(list.symbolColor)
                    .frame(width: 20, height: 20)
                Text(list.title)
                    .font(.system(size: 13.5, weight: .medium))
                Spacer()
                if let count = counts[list], count > 0 {
                    Text(count.formatted())
                        .font(.system(size: 12))
                        .foregroundStyle(palette.tertiaryText)
                }
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                selection == .smart(list) ? palette.softAccent : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(list.title)
    }

    private func areaSection(_ area: WaniArea) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                Text(area.title.uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.2)
                Rectangle()
                    .fill(palette.line)
                    .frame(height: 1)
            }
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 8)
            .padding(.bottom, 5)

            ForEach(projects.filter { $0.area?.id == area.id }) { project in
                Button {
                    selection = .project(project.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.accent)
                            .frame(width: 20)
                        Text(project.title)
                            .font(.system(size: 13.5))
                        Spacer()
                    }
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(
                        selection == .project(project.id)
                            ? palette.softAccent
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.line)
            .frame(height: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
    }
}
