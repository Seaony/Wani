import SwiftUI

struct WaniSidebar: View {
    let palette: WaniPalette
    let areas: [WaniArea]
    let projects: [WaniProject]
    let todos: [WaniTodo]
    let counts: [WaniSmartList: Int]
    let showCounts: Bool
    let showAreaLines: Bool
    @Binding var selection: WaniNavigationTarget
    let openSearch: () -> Void
    let openNewList: () -> Void
    let openSettings: () -> Void

    @State private var collapsedAreaIDs: Set<UUID> = []

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

                    let looseProjects = projects.filter { $0.area == nil }
                    if !looseProjects.isEmpty {
                        projectSection(title: "PROJECTS", projects: looseProjects)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }

            Rectangle()
                .fill(palette.line)
                .frame(height: 1)

            HStack {
                Button(action: openNewList) {
                    Label("New List", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New List")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(palette.tertiaryText)
                }
                .buttonStyle(.plain)
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
                if showCounts, let count = counts[list], count > 0 {
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
            Button {
                if collapsedAreaIDs.contains(area.id) {
                    collapsedAreaIDs.remove(area.id)
                } else {
                    collapsedAreaIDs.insert(area.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(collapsedAreaIDs.contains(area.id) ? 0 : 90))
                    Text(area.title.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1.2)
                    if showAreaLines {
                        Rectangle()
                            .fill(palette.line)
                            .frame(height: 1)
                    } else {
                        Spacer(minLength: 0)
                    }
                    let count = areaOpenCount(area)
                    if showCounts, count > 0 {
                        Text(count.formatted())
                            .font(.system(size: 11))
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 8)
            .padding(.bottom, 5)

            if !collapsedAreaIDs.contains(area.id) {
                ForEach(projects.filter { $0.area?.id == area.id }) { project in
                    projectRow(project)
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func projectSection(title: String, projects: [WaniProject]) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.2)
                Rectangle().fill(palette.line).frame(height: 1)
            }
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 8)
            .padding(.bottom, 5)

            ForEach(projects) { project in
                projectRow(project)
            }
        }
        .padding(.bottom, 12)
    }

    private func projectRow(_ project: WaniProject) -> some View {
        Button {
            selection = .project(project.id)
        } label: {
            HStack(spacing: 10) {
                progressRing(for: project)
                    .frame(width: 20)
                Text(project.title)
                    .font(.system(size: 13.5))
                Spacer()
                let openCount = WaniTaskRules.projectTasks(todos, projectID: project.id)
                    .filter { $0.status == .open }.count
                if showCounts, openCount > 0 {
                    Text(openCount.formatted())
                        .font(.system(size: 12))
                        .foregroundStyle(palette.tertiaryText)
                }
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                selection == .project(project.id) ? palette.softAccent : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(project.title)
    }

    private func progressRing(for project: WaniProject) -> some View {
        let progress = WaniTaskRules.projectProgress(todos, projectID: project.id)
        return ZStack {
            Circle().stroke(palette.line, lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }

    private func areaOpenCount(_ area: WaniArea) -> Int {
        let projectIDs = Set(projects.filter { $0.area?.id == area.id }.map(\.id))
        return todos.filter {
            guard let projectID = $0.project?.id else { return false }
            return projectIDs.contains(projectID)
                && $0.deletedAt == nil
                && $0.status == .open
        }.count
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.line)
            .frame(height: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
    }
}
