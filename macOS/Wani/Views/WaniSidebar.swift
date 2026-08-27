import SwiftUI

struct WaniSidebar: View {
    let palette: WaniPalette
    let areas: [WaniArea]
    let projects: [WaniProject]
    let counts: [WaniSmartList: Int]
    let projectTallies: [UUID: WaniProjectTally]
    let showCounts: Bool
    let showAreaLines: Bool
    @Binding var selection: WaniNavigationTarget
    let openSearch: () -> Void
    let createArea: () -> Void
    let createProject: () -> Void
    let updateAreaSymbol: (WaniArea, String) -> Void
    let reorderArea: (UUID, UUID) -> Bool
    let reorderProject: (UUID, UUID) -> Bool
    let moveTodoToSmartList: (UUID, WaniSmartList) -> Bool
    let moveTodoToArea: (UUID, WaniArea) -> Bool
    let moveTodoToProject: (UUID, WaniProject) -> Bool
    let openSettings: () -> Void

    @State private var collapsedAreaIDs: Set<UUID> = []
    @State private var symbolPickerAreaID: UUID?

    private let primaryLists: [WaniSmartList] = [
        .inbox, .today, .upcoming, .anytime, .someday,
    ]
    private let archiveLists: [WaniSmartList] = [.logbook, .trash]

    var body: some View {
        VStack(spacing: 0) {
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
            .buttonStyle(.waniInteractive(palette))
            .accessibilityLabel("Search")
            .padding(.top, 10)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(primaryLists) { list in
                        smartListRow(list)
                    }

                    sectionSpacing

                    ForEach(archiveLists) { list in
                        smartListRow(list)
                    }

                    sectionSpacing

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
                .fill(palette.sidebarDivider)
                .frame(height: 1)

            HStack {
                Menu {
                    Button("New Project", systemImage: "circle", action: createProject)
                    Button("New Area", systemImage: "cube.transparent", action: createArea)
                } label: {
                    Label("New List", systemImage: "plus")
                        .padding(.horizontal, 6)
                        .frame(height: 28)
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
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.waniInteractive(palette))
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
        }
        .background(palette.sidebar)
    }

    private func smartListRow(_ list: WaniSmartList) -> some View {
        Button {
            selection = .smart(list)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: sidebarSymbolName(for: list))
                    .font(.system(size: 14, weight: .semibold))
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
            .frame(height: 30)
            .background(
                selection == .smart(list) ? palette.selectionBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.waniInteractive(
            palette,
            showsHoverBackground: selection != .smart(list)
        ))
        .dropDestination(for: String.self) { values, _ in
            guard let todoID = draggedID(in: values, prefix: "todo:") else {
                return false
            }
            return moveTodoToSmartList(todoID, list)
        }
        .animation(WaniMotion.quick, value: selection)
        .accessibilityLabel(list.title)
        .accessibilityValue(selection == .smart(list) ? "Selected" : "")
    }

    private func sidebarSymbolName(for list: WaniSmartList) -> String {
        switch list {
        case .inbox: "tray.full.fill"
        case .today: "star.fill"
        case .upcoming: "calendar"
        case .anytime: "square.stack.3d.up.fill"
        case .someday: "archivebox.fill"
        case .logbook: "book.closed.fill"
        case .trash: "trash.fill"
        }
    }

    private func areaSection(_ area: WaniArea) -> some View {
        let areaProjects = projects.filter { $0.area?.id == area.id }
        let isCollapsed = collapsedAreaIDs.contains(area.id)

        return VStack(spacing: 1) {
            HStack(spacing: 6) {
                Button {
                    symbolPickerAreaID = area.id
                } label: {
                    Image(systemName: area.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.waniInteractive(palette))
                .accessibilityLabel("Change \(area.title) Icon")
                .popover(
                    isPresented: Binding(
                        get: { symbolPickerAreaID == area.id },
                        set: { isPresented in
                            if !isPresented, symbolPickerAreaID == area.id {
                                symbolPickerAreaID = nil
                            }
                        }
                    ),
                    arrowEdge: .leading
                ) {
                    WaniSymbolPicker(
                        palette: palette,
                        selectedSymbol: area.symbolName,
                        select: { symbol in
                            updateAreaSymbol(area, symbol)
                            symbolPickerAreaID = nil
                        },
                        dismiss: { symbolPickerAreaID = nil }
                    )
                }

                Button {
                    selection = .area(area.id)
                    toggleArea(area)
                } label: {
                    HStack(spacing: 6) {
                        Text(area.title.uppercased())
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(1.2)
                            .lineLimit(1)
                            .layoutPriority(1)

                        if showAreaLines {
                            Rectangle()
                                .fill(palette.line)
                                .frame(minWidth: 10, maxWidth: .infinity)
                                .frame(height: 1)
                        } else {
                            Spacer(minLength: 0)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                            .frame(width: 26, height: 26)
                            .animation(WaniMotion.sidebarDisclosure, value: isCollapsed)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.waniInteractive(
                    palette,
                    showsHoverBackground: selection != .area(area.id)
                ))
                .accessibilityLabel(isCollapsed ? "Expand Area" : "Collapse Area")
            }
            .foregroundStyle(palette.tertiaryText)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                selection == .area(area.id) ? palette.selectionBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .padding(.bottom, 5)
            .contentShape(Rectangle())
            .draggable("area:\(area.id.uuidString)")
            .dropDestination(for: String.self) { values, _ in
                if let todoID = draggedID(in: values, prefix: "todo:") {
                    return moveTodoToArea(todoID, area)
                }
                guard let movingID = draggedID(in: values, prefix: "area:") else {
                    return false
                }
                return reorderArea(movingID, area.id)
            }
            .animation(WaniMotion.quick, value: selection)

            VStack(spacing: 1) {
                ForEach(areaProjects) { project in
                    projectRow(project)
                }
            }
            .frame(
                height: isCollapsed ? 0 : projectGroupHeight(areaProjects.count),
                alignment: .top
            )
            .opacity(isCollapsed ? 0 : 1)
            .offset(y: isCollapsed ? -5 : 0)
            .scaleEffect(y: isCollapsed ? 0.97 : 1, anchor: .top)
            .clipped()
            .allowsHitTesting(!isCollapsed)
            .accessibilityHidden(isCollapsed)
            .animation(WaniMotion.sidebarDisclosure, value: isCollapsed)
        }
        .padding(.bottom, 12)
    }

    private func toggleArea(_ area: WaniArea) {
        withAnimation(WaniMotion.sidebarDisclosure) {
            if collapsedAreaIDs.contains(area.id) {
                collapsedAreaIDs.remove(area.id)
            } else {
                collapsedAreaIDs.insert(area.id)
            }
        }
    }

    private func projectGroupHeight(_ projectCount: Int) -> CGFloat {
        CGFloat(max(projectCount * 33 - 1, 0))
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
                selection == .project(project.id) ? palette.selectionBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
            .draggable("project:\(project.id.uuidString)")
            .dropDestination(for: String.self) { values, _ in
                if let todoID = draggedID(in: values, prefix: "todo:") {
                    return moveTodoToProject(todoID, project)
                }
                guard let movingID = draggedID(in: values, prefix: "project:") else {
                    return false
                }
                return reorderProject(movingID, project.id)
            }
        }
        .buttonStyle(.waniInteractive(
            palette,
            showsHoverBackground: selection != .project(project.id)
        ))
        .animation(WaniMotion.quick, value: selection)
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

    private var sectionSpacing: some View {
        Color.clear
            .frame(height: 15)
    }

    private func draggedID(in values: [String], prefix: String) -> UUID? {
        guard let value = values.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }
}
