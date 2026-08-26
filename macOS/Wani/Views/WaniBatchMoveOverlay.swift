import SwiftUI

struct WaniBatchMoveOverlay: View {
    let palette: WaniPalette
    let areas: [WaniArea]
    let projects: [WaniProject]
    let headings: [WaniHeading]
    @Binding var query: String
    let moveToInbox: () -> Void
    let moveToArea: (WaniArea) -> Void
    let moveToProject: (WaniProject, WaniHeading?) -> Void
    let dismiss: () -> Void

    @FocusState private var searchFocused: Bool

    private var filteredAreas: [WaniArea] {
        guard !normalizedQuery.isEmpty else { return areas }
        return areas.filter { $0.title.localizedCaseInsensitiveContains(normalizedQuery) }
    }

    private var filteredProjects: [WaniProject] {
        guard !normalizedQuery.isEmpty else { return projects }
        return projects.filter {
            $0.title.localizedCaseInsensitiveContains(normalizedQuery)
                || ($0.area?.title.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
        }
    }

    private var filteredHeadings: [WaniHeading] {
        headings.filter { heading in
            guard let project = heading.project else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            return heading.title.localizedCaseInsensitiveContains(normalizedQuery)
                || project.title.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(palette.tertiaryText)
                    TextField("Move to…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($searchFocused)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)

                Rectangle().fill(palette.line).frame(height: 1)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        destinationButton(
                            title: "Inbox",
                            subtitle: "No Project",
                            symbol: "tray",
                            action: moveToInbox
                        )

                        ForEach(filteredAreas) { area in
                            destinationButton(
                                title: area.title,
                                subtitle: "Area",
                                symbol: "cube.transparent",
                                action: { moveToArea(area) }
                            )
                        }

                        ForEach(filteredProjects) { project in
                            destinationButton(
                                title: project.title,
                                subtitle: project.area?.title ?? "Project",
                                symbol: "circle",
                                action: { moveToProject(project, nil) }
                            )
                        }

                        ForEach(filteredHeadings) { heading in
                            if let project = heading.project {
                                destinationButton(
                                    title: heading.title,
                                    subtitle: project.title,
                                    symbol: "text.alignleft",
                                    action: { moveToProject(project, heading) }
                                )
                            }
                        }

                        if filteredAreas.isEmpty
                            && filteredProjects.isEmpty
                            && filteredHeadings.isEmpty
                        {
                            Text("No destinations found")
                                .font(.system(size: 12.5))
                                .foregroundStyle(palette.tertiaryText)
                                .padding(.vertical, 26)
                        }
                    }
                    .padding(7)
                }
                .frame(maxHeight: 320)
            }
            .frame(width: 420)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 13))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: .black.opacity(0.3), radius: 34, y: 18)
            .padding(.top, 112)
        }
        .onAppear { searchFocused = true }
        .onExitCommand(perform: dismiss)
    }

    private func destinationButton(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(palette.accent)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13.5))
                    .foregroundStyle(palette.text)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}
