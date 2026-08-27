import SwiftUI

struct WaniSidebar: View {
    let palette: WaniPalette
    let areas: [WaniArea]
    let projects: [WaniProject]
    let counts: [WaniSmartList: Int]
    let projectTallies: [UUID: WaniProjectTally]
    let areaOpenCounts: [UUID: Int]
    let showCounts: Bool
    let showAreaLines: Bool
    @Binding var selection: WaniNavigationTarget
    let openSearch: () -> Void
    let createArea: () -> Void
    let createProject: () -> Void
    let reorderArea: (UUID, UUID) -> Bool
    let reorderProject: (UUID, UUID) -> Bool
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
                    Text("⌘F")
                        .font(.system(size: 11))
                }
                .foregroundStyle(palette.tertiaryText)
                .font(.system(size: 12.5))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.waniInteractive(palette))
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
                Menu {
                    Button("New Project", systemImage: "circle", action: createProject)
                    Button("New Area", systemImage: "cube.transparent", action: createArea)
                } label: {
                    Label("New List", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .waniPointerFeedback(palette: palette)
                .accessibilityLabel("New List")
                .font(.system(size: 12.5))
                .foregroundStyle(palette.secondaryText)
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(palette.tertiaryText)
                }
                .buttonStyle(.waniInteractive(palette))
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
                    .foregroundStyle(list == .trash ? palette.tertiaryText : list.symbolColor)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
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
        .buttonStyle(.waniInteractive(palette))
        .accessibilityLabel(list.title)
        .accessibilityValue(selection == .smart(list) ? "Selected" : "")
    }

    private func areaSection(_ area: WaniArea) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 6) {
                Button {
                    if collapsedAreaIDs.contains(area.id) {
                        collapsedAreaIDs.remove(area.id)
                    } else {
                        collapsedAreaIDs.insert(area.id)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(collapsedAreaIDs.contains(area.id) ? 0 : 90))
                }
                .buttonStyle(.waniInteractive(palette))
                .accessibilityLabel(collapsedAreaIDs.contains(area.id) ? "Expand Area" : "Collapse Area")

                Button {
                    selection = .area(area.id)
                } label: {
                    Text(area.title.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1.2)
                }
                .buttonStyle(.waniInteractive(palette))
                .accessibilityLabel(area.title)
                .accessibilityValue(selection == .area(area.id) ? "Selected" : "")

                if showAreaLines {
                    Rectangle()
                        .fill(palette.line)
                        .frame(height: 1)
                } else {
                    Spacer(minLength: 0)
                }
                let count = areaOpenCounts[area.id] ?? 0
                if showCounts, count > 0 {
                    Text(count.formatted())
                        .font(.system(size: 11))
                }
            }
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                selection == .area(area.id) ? palette.softAccent : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .padding(.bottom, 5)
            .contentShape(Rectangle())
            .draggable("area:\(area.id.uuidString)")
            .dropDestination(for: String.self) { values, _ in
                guard let movingID = draggedID(in: values, prefix: "area:") else {
                    return false
                }
                return reorderArea(movingID, area.id)
            }

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
                let openCount = projectTallies[project.id]?.open ?? 0
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
            .contentShape(Rectangle())
            .draggable("project:\(project.id.uuidString)")
            .dropDestination(for: String.self) { values, _ in
                guard let movingID = draggedID(in: values, prefix: "project:") else {
                    return false
                }
                return reorderProject(movingID, project.id)
            }
        }
        .buttonStyle(.waniInteractive(palette))
        .accessibilityLabel(project.title)
        .accessibilityValue(selection == .project(project.id) ? "Selected" : "")
    }

    private func progressRing(for project: WaniProject) -> some View {
        let progress = projectTallies[project.id]?.progress ?? 0
        return ZStack {
            Circle().stroke(palette.line, lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.line)
            .frame(height: 1)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
    }

    private func draggedID(in values: [String], prefix: String) -> UUID? {
        guard let value = values.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }
}
