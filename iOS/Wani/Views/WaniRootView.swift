import SwiftUI

struct WaniRootView: View {
    let areas: [WaniArea]
    let projects: [WaniProject]
    let todos: [WaniTodo]
    let projectMetrics: [UUID: WaniProjectTally]
    let listCounts: [WaniSmartList: Int]
    let palette: WaniPalette
    let open: (WaniRoute) -> Void
    @AppStorage("wani.badge") private var showsBadge = true
    @AppStorage("wani.showCounts") private var showsCounts = true
    @State private var collapsedAreaIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button { open(.search) } label: {
                    Label("Quick Find", systemImage: "magnifyingglass")
                        .font(.system(size: 15.5))
                        .foregroundStyle(palette.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(palette.hover, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("quick-find")
                .padding(.bottom, 17)

                smartRow(.inbox)
                Color.clear.frame(height: 10)
                smartRow(.today)
                smartRow(.upcoming)
                smartRow(.anytime)
                smartRow(.someday)
                Color.clear.frame(height: 10)
                smartRow(.logbook)
                smartRow(.trash)

                ForEach(areas) { area in areaSection(area) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 105)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button { open(.settings) } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
                    .font(.system(size: 15))
                    .foregroundStyle(palette.tertiary)
                    .padding(.vertical, 10)
            }
            .accessibilityIdentifier("settings")
            .frame(maxWidth: .infinity)
            .background(palette.background.opacity(0.97))
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func smartRow(_ list: WaniSmartList) -> some View {
        let count = listCounts[list, default: 0]
        return Button { open(.smart(list)) } label: {
            HStack(spacing: 14) {
                Image(systemName: list.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(listColor(list))
                    .frame(width: 26, height: 26)
                    .background(listColor(list).opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Text(list.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                let newCount = list == .today
                    ? todos.filter { $0.isNew && $0.status == .open && $0.deletedAt == nil }.count
                    : 0
                if showsBadge && newCount > 0 {
                    Text(newCount.formatted())
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(palette.accent, in: Capsule())
                }
                if showsCounts && count > 0 {
                    Text(count.formatted())
                        .font(.system(size: 15))
                        .foregroundStyle(palette.tertiary)
                }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("list-\(list.rawValue)")
    }

    private func areaSection(_ area: WaniArea) -> some View {
        let areaProjects = projects.filter {
            $0.area?.id == area.id
                && $0.completedAt == nil
                && $0.canceledAt == nil
                && $0.deletedAt == nil
        }
        let isCollapsed = collapsedAreaIDs.contains(area.id)
        return VStack(spacing: 0) {
            Divider().overlay(palette.line).padding(.vertical, 18)
            Button {
                if isCollapsed { collapsedAreaIDs.remove(area.id) }
                else { collapsedAreaIDs.insert(area.id) }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "hexagon")
                        .foregroundStyle(palette.tertiary)
                        .frame(width: 26)
                    Text(area.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.tertiary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                ForEach(areaProjects) { project in
                    Button { open(.project(project.id)) } label: {
                        HStack(spacing: 14) {
                            WaniProgressRing(
                                progress: projectMetrics[project.id]?.progress ?? 0,
                                color: palette.accent,
                                background: palette.line,
                                size: 20,
                                lineWidth: 3
                            )
                            .frame(width: 26)
                            Text(project.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(palette.text)
                            Spacer()
                            let count = projectMetrics[project.id]?.open ?? 0
                            if showsCounts && count > 0 {
                                Text(count.formatted())
                                    .font(.system(size: 15))
                                    .foregroundStyle(palette.tertiary)
                            }
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("project-\(project.id.uuidString)")
                }
                .padding(.top, 6)
            }
        }
    }

    private func listColor(_ list: WaniSmartList) -> Color {
        switch list {
        case .inbox: Color(rgb: 0x4A7BA7)
        case .today: Color(rgb: 0xC9922A)
        case .upcoming: Color(rgb: 0xC3564C)
        case .anytime, .logbook: Color(rgb: 0x5B8C6C)
        case .someday: Color(rgb: 0x9A8A5F)
        case .trash: palette.tertiary
        }
    }
}
