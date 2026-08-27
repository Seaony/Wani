import SwiftUI

struct WaniSearchOverlay: View {
    let palette: WaniPalette
    let areas: [WaniArea]
    let projects: [WaniProject]
    let todos: [WaniTodo]
    let deferCompletedUntilMidnight: Bool
    @Binding var query: String
    let openArea: (WaniArea) -> Void
    let openProject: (WaniProject) -> Void
    let openTodo: (WaniTodo) -> Void
    let dismiss: () -> Void
    @FocusState private var isFocused: Bool

    private static let shownPerCategory = 20

    private var areaMatches: [WaniArea] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return areas.filter { WaniTaskRules.matches($0, query: query) }
    }

    private var projectMatches: [WaniProject] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return projects.filter {
            $0.deletedAt == nil && WaniTaskRules.matches($0, query: query)
        }
    }

    private var todoMatches: [WaniTodo] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return todos.filter {
            $0.deletedAt == nil && WaniTaskRules.matches($0, query: query)
        }
    }

    private var areaResults: [WaniArea] {
        Array(areaMatches.prefix(Self.shownPerCategory))
    }

    private var projectResults: [WaniProject] {
        Array(projectMatches.prefix(Self.shownPerCategory))
    }

    private var todoResults: [WaniTodo] {
        Array(todoMatches.prefix(Self.shownPerCategory))
    }

    /// Counts every match, not just the listed ones, so the header cannot report
    /// "20 found" when the store holds two hundred.
    private var resultCount: Int {
        areaMatches.count + projectMatches.count + todoMatches.count
    }

    private var hiddenResultCount: Int {
        resultCount - (areaResults.count + projectResults.count + todoResults.count)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .waniPointingHand()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search everything", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15.5))
                        .focused($isFocused)
                        .onSubmit(openFirstResult)
                    Text(query.isEmpty ? "⌘F" : "\(resultCount) found")
                        .font(.system(size: 11))
                }
                .foregroundStyle(palette.tertiaryText)
                .padding(.horizontal, 18)
                .frame(height: 48)

                Rectangle().fill(palette.line).frame(height: 1)

                if resultCount == 0 {
                    Text(query.isEmpty ? "Search across every list, project and note." : "No matches")
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(areaResults) { area in
                                resultRow(
                                    title: area.title,
                                    location: "Area",
                                    symbol: "cube.transparent",
                                    action: { openArea(area) }
                                )
                            }
                            ForEach(projectResults) { project in
                                resultRow(
                                    title: project.title,
                                    location: project.area?.title ?? "Project",
                                    symbol: "circle",
                                    action: { openProject(project) }
                                )
                            }
                            ForEach(todoResults) { todo in
                                resultRow(
                                    title: todo.title,
                                    location: locationTitle(for: todo),
                                    symbol: "circle",
                                    action: { openTodo(todo) }
                                )
                            }
                            if hiddenResultCount > 0 {
                                Text("\(hiddenResultCount) more — keep typing to narrow it down")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(palette.tertiaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 11)
                                    .frame(height: 30)
                            }
                        }
                        .padding(7)
                    }
                    .frame(maxHeight: 330)
                }
            }
            .frame(width: 560)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.28), radius: 34, y: 18)
            .padding(.top, 84)

            Button("Close Search", action: dismiss)
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .onAppear { isFocused = true }
        .onExitCommand(perform: dismiss)
    }

    private func resultRow(
        title: String,
        location: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(width: 13, height: 13)
                Text(title)
                    .font(.system(size: 13.5))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Spacer()
                Text(location)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(.horizontal, 11)
            .frame(height: 38)
        }
        .buttonStyle(.waniInteractive(palette))
    }

    private func openFirstResult() {
        if let area = areaResults.first {
            openArea(area)
        } else if let project = projectResults.first {
            openProject(project)
        } else if let todo = todoResults.first {
            openTodo(todo)
        }
    }

    private func locationTitle(for todo: WaniTodo) -> String {
        let awaitingArchive = WaniTaskRules.isAwaitingMidnightArchive(
            todo,
            enabled: deferCompletedUntilMidnight
        )
        if (todo.status == .open || awaitingArchive),
           todo.deletedAt == nil,
           let project = todo.project {
            return project.title
        }
        if (todo.status == .open || awaitingArchive),
           todo.deletedAt == nil,
           let area = todo.area {
            return area.title
        }
        return WaniTaskRules.primaryList(
            for: todo,
            deferCompletedUntilMidnight: deferCompletedUntilMidnight
        ).title
    }
}
