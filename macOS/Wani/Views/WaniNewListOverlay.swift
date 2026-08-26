import SwiftUI

struct WaniNewListOverlay: View {
    enum ListKind: String, CaseIterable, Identifiable {
        case project = "Project"
        case area = "Area"

        var id: String { rawValue }
    }

    let palette: WaniPalette
    let areas: [WaniArea]
    let saveArea: (String) -> Void
    let saveProject: (String, UUID?) -> Void
    let dismiss: () -> Void

    @State private var kind: ListKind = .project
    @State private var title = ""
    @State private var areaID: UUID?
    @FocusState private var titleFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("New List")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.tertiaryText)
                    .accessibilityLabel("Close")
                }

                Picker("List type", selection: $kind) {
                    ForEach(ListKind.allCases) { listKind in
                        Text(listKind.rawValue).tag(listKind)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 7) {
                    Text("NAME")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(palette.tertiaryText)
                    TextField(kind == .project ? "Project name" : "Area name", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))
                        .focused($titleFocused)
                        .onSubmit(save)
                }

                if kind == .project {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("AREA")
                            .font(.system(size: 10.5, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(palette.tertiaryText)
                        Picker("Area", selection: $areaID) {
                            Text("No Area").tag(UUID?.none)
                            ForEach(areas) { area in
                                Text(area.title).tag(Optional(area.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel", action: dismiss)
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.secondaryText)
                    Button("Create", action: save)
                        .buttonStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
                        .disabled(trimmedTitle.isEmpty)
                        .opacity(trimmedTitle.isEmpty ? 0.5 : 1)
                }
            }
            .padding(22)
            .frame(width: 410)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.28), radius: 34, y: 18)
        }
        .onAppear { titleFocused = true }
        .onExitCommand(perform: dismiss)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        switch kind {
        case .project:
            saveProject(trimmedTitle, areaID)
        case .area:
            saveArea(trimmedTitle)
        }
    }
}
