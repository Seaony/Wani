import SwiftUI

struct WaniBatchMoveOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let palette: WaniPalette
    let areas: [WaniArea]
    let projects: [WaniProject]
    let headings: [WaniHeading]
    @Binding var query: String
    let inboxSelected: Bool
    let selectedAreaID: UUID?
    let selectedProjectID: UUID?
    let selectedHeadingID: UUID?
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

    private var hasFilteredDestinations: Bool {
        !filteredAreas.isEmpty
            || !filteredProjects.isEmpty
            || !filteredHeadings.isEmpty
    }

    private var destinationListHeight: CGFloat {
        let destinationCount = 1
            + filteredAreas.count
            + filteredProjects.count
            + filteredHeadings.count
        let dividerHeight: CGFloat = hasFilteredDestinations ? 9 : 0
        let emptyMessageHeight: CGFloat = hasFilteredDestinations ? 0 : 50
        return min(
            CGFloat(destinationCount) * 26 + dividerHeight + emptyMessageHeight,
            226
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .waniPointingHand()

            VStack(spacing: 0) {
                TextField("Move", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
                    .focused($searchFocused)
                    .padding(.horizontal, 12)
                    .frame(height: 32)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        destinationButton(
                            title: "Inbox",
                            subtitle: "No Project",
                            symbol: "tray",
                            isSelected: inboxSelected,
                            action: moveToInbox
                        )

                        if hasFilteredDestinations {
                            Rectangle()
                                .fill(palette.line)
                                .frame(height: 1)
                                .padding(.vertical, 4)
                        }

                        ForEach(filteredAreas) { area in
                            destinationButton(
                                title: area.title,
                                subtitle: "Area",
                                symbol: area.symbolName,
                                isSelected: selectedAreaID == area.id,
                                action: { moveToArea(area) }
                            )
                        }

                        ForEach(filteredProjects) { project in
                            destinationButton(
                                title: project.title,
                                subtitle: project.area?.title ?? "Project",
                                symbol: "circle",
                                isSelected: selectedProjectID == project.id
                                    && selectedHeadingID == nil,
                                action: { moveToProject(project, nil) }
                            )
                        }

                        ForEach(filteredHeadings) { heading in
                            if let project = heading.project {
                                destinationButton(
                                    title: heading.title,
                                    subtitle: project.title,
                                    symbol: "text.alignleft",
                                    isSelected: selectedHeadingID == heading.id,
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
                    .padding(.horizontal, 7)
                }
                .frame(height: destinationListHeight)
            }
            .frame(width: 280)
            .background(
                colorScheme == .dark ? Color(hex: 0x1F1F1F) : palette.card,
                in: RoundedRectangle(cornerRadius: 13)
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: .black.opacity(0.34), radius: 12, y: 5)
            .padding(.bottom, 39)
        }
        .onAppear { searchFocused = true }
        .onExitCommand(perform: dismiss)
    }

    private func destinationButton(
        title: String,
        subtitle: String,
        symbol: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : palette.accent)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : palette.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                isSelected ? Color(hex: 0x3367BD) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.waniInteractive(
            palette,
            cornerRadius: 7,
            showsHoverBackground: !isSelected
        ))
        .accessibilityLabel("\(title), \(subtitle)")
    }
}
