import SwiftUI

struct WaniProjectEditor: View {
    let palette: WaniPalette
    let areas: [WaniArea]
    let canComplete: Bool
    let save: (String, String, UUID?) -> Void
    let complete: () -> Void
    let dismiss: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var areaID: UUID?
    @FocusState private var titleFocused: Bool

    init(
        palette: WaniPalette,
        project: WaniProject,
        areas: [WaniArea],
        canComplete: Bool,
        save: @escaping (String, String, UUID?) -> Void,
        complete: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.palette = palette
        self.areas = areas
        self.canComplete = canComplete
        self.save = save
        self.complete = complete
        self.dismiss = dismiss
        _title = State(initialValue: project.title)
        _notes = State(initialValue: project.notes)
        _areaID = State(initialValue: project.area?.id)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Edit Project")
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

                fieldLabel("NAME")
                TextField("Project name", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))
                    .focused($titleFocused)
                    .onSubmit(saveChanges)

                fieldLabel("NOTES")
                TextEditor(text: $notes)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 92)
                    .background(palette.hover, in: RoundedRectangle(cornerRadius: 8))

                fieldLabel("AREA")
                Picker("Area", selection: $areaID) {
                    Text("No Area").tag(UUID?.none)
                    ForEach(areas) { area in
                        Text(area.title).tag(Optional(area.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button(action: complete) {
                        Label("Complete Project", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(canComplete ? palette.accent : palette.tertiaryText)
                    .disabled(!canComplete)

                    if !canComplete {
                        Text("Complete or cancel every open to-do first.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(palette.tertiaryText)
                    }
                }

                HStack {
                    Spacer()
                    Button("Cancel", action: dismiss)
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.secondaryText)
                    Button("Save", action: saveChanges)
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
            .frame(width: 430)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.28), radius: 34, y: 18)
        }
        .onAppear { titleFocused = true }
        .onExitCommand(perform: dismiss)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(palette.tertiaryText)
    }

    private func saveChanges() {
        guard !trimmedTitle.isEmpty else { return }
        save(trimmedTitle, notes, areaID)
    }
}
