import SwiftUI

struct WaniSearchView: View {
    @State private var query = ""
    let todos: [WaniTodo]
    let palette: WaniPalette
    let openTodo: (WaniTodo) -> Void

    private var results: [WaniTodo] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return todos.filter {
            $0.deletedAt == nil
                && ($0.title.localizedCaseInsensitiveContains(query)
                    || $0.notes.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                    TextField("Quick Find", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .font(.system(size: 16))
                .foregroundStyle(palette.tertiary)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(palette.hover, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("search-field")

                if results.isEmpty {
                    Text(query.isEmpty ? "Search every list, project and note." : "No matches for \(query)")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.tertiary)
                        .padding(.top, 70)
                } else {
                    VStack(spacing: 0) {
                        ForEach(results) { todo in
                            Button { openTodo(todo) } label: {
                                HStack(spacing: 13) {
                                    Circle()
                                        .stroke(palette.tertiary, lineWidth: 1.5)
                                        .frame(width: 21, height: 21)
                                    Text(todo.title)
                                        .font(.system(size: 16))
                                        .foregroundStyle(palette.text)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(todo.project?.title ?? "Inbox")
                                        .font(.system(size: 13))
                                        .foregroundStyle(palette.tertiary)
                                }
                                .padding(.vertical, 11)
                                .padding(.horizontal, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar { WaniNavigationToolbar(palette: palette) }
    }
}
