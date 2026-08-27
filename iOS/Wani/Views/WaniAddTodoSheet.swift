import SwiftData
import SwiftUI

struct WaniAddTodoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let projects: [WaniProject]
    let initialDestination: WaniAddDestination
    let palette: WaniPalette
    @State private var title = ""
    @State private var destination: WaniAddDestination

    init(
        projects: [WaniProject],
        initialDestination: WaniAddDestination,
        palette: WaniPalette
    ) {
        self.projects = projects
        self.initialDestination = initialDestination
        self.palette = palette
        _destination = State(initialValue: initialDestination)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("What's on your mind?", text: $title)
                .font(.system(size: 19, weight: .medium))
                .submitLabel(.done)
                .onSubmit(add)
                .accessibilityIdentifier("new-todo-title")
            Divider().overlay(palette.line)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    chip("Inbox", .inbox)
                    chip("Today", .today)
                    ForEach(projects.prefix(3)) { project in
                        chip(project.title, .project(project.id))
                    }
                }
            }
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(palette.secondary)
                Spacer()
                Button("Add", action: add)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 11))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("add-todo-confirm")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(palette.background)
    }

    private func chip(_ label: String, _ value: WaniAddDestination) -> some View {
        Button { destination = value } label: {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(destination == value ? palette.accent : palette.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    destination == value ? palette.softAccent : palette.hover,
                    in: RoundedRectangle(cornerRadius: 9)
                )
        }
        .buttonStyle(.plain)
    }

    private func add() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var descriptor = FetchDescriptor<WaniTodo>(
            sortBy: [SortDescriptor(\WaniTodo.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let maxSortOrder = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? 0
        let todo: WaniTodo
        switch destination {
        case .inbox:
            todo = WaniTodo(title: trimmed, schedule: .inbox, sortOrder: maxSortOrder + 1)
        case .today:
            todo = WaniTodo(
                title: trimmed,
                schedule: .date,
                startDate: Calendar.current.startOfDay(for: .now),
                sortOrder: maxSortOrder + 1
            )
        case .project(let id):
            todo = WaniTodo(
                title: trimmed,
                schedule: .anytime,
                project: projects.first { $0.id == id },
                sortOrder: maxSortOrder + 1
            )
        }
        modelContext.insert(todo)
        try? modelContext.save()
        dismiss()
    }
}
