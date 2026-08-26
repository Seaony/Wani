import SwiftUI

struct WaniSearchOverlay: View {
    let palette: WaniPalette
    let todos: [WaniTodo]
    @Binding var query: String
    let open: (WaniTodo) -> Void
    let dismiss: () -> Void
    @FocusState private var isFocused: Bool

    private var results: [WaniTodo] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return todos
            .filter { $0.deletedAt == nil && WaniTaskRules.matches($0, query: query) }
            .prefix(20)
            .map { $0 }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search everything", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15.5))
                        .focused($isFocused)
                    Text(query.isEmpty ? "⌘K" : "\(results.count) found")
                        .font(.system(size: 11))
                }
                .foregroundStyle(palette.tertiaryText)
                .padding(.horizontal, 18)
                .frame(height: 48)

                Rectangle().fill(palette.line).frame(height: 1)

                if results.isEmpty {
                    Text(query.isEmpty ? "Search across every list, project and note." : "No matches")
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(results) { todo in
                                Button {
                                    open(todo)
                                } label: {
                                    HStack(spacing: 11) {
                                        Circle()
                                            .stroke(palette.tertiaryText, lineWidth: 1.5)
                                            .frame(width: 13, height: 13)
                                        Text(todo.title)
                                            .font(.system(size: 13.5))
                                            .foregroundStyle(palette.text)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(locationTitle(for: todo))
                                            .font(.system(size: 11))
                                            .foregroundStyle(palette.tertiaryText)
                                    }
                                    .padding(.horizontal, 11)
                                    .frame(height: 38)
                                }
                                .buttonStyle(.plain)
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
        }
        .onAppear { isFocused = true }
        .onExitCommand(perform: dismiss)
    }

    private func locationTitle(for todo: WaniTodo) -> String {
        if todo.status == .open, todo.deletedAt == nil, let project = todo.project {
            return project.title
        }
        return WaniTaskRules.primaryList(for: todo).title
    }
}
