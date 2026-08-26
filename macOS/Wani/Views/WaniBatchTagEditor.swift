import SwiftUI

struct WaniBatchTagEditor: View {
    let palette: WaniPalette
    let knownTags: [String]
    let selectedTagNames: [[String]]
    let setTag: (String, Bool) -> Void
    let clear: () -> Void

    @State private var query = ""
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "tag")
                    .foregroundStyle(palette.tertiaryText)
                TextField("Filter or add tag", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .focused($queryFocused)
                    .onSubmit(addQueryTag)
                Button("Clear", action: clear)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(palette.accent)
                    .disabled(selectedTagNames.allSatisfy(\.isEmpty))
            }
            .padding(.horizontal, 12)
            .frame(height: 42)

            Rectangle().fill(palette.line).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredTags, id: \.self) { tag in
                        tagButton(tag)
                    }

                    if canAddQueryTag {
                        Button(action: addQueryTag) {
                            Label("Add “\(normalizedQuery)”", systemImage: "plus")
                                .font(.system(size: 12.5))
                                .foregroundStyle(palette.accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add tag \(normalizedQuery)")
                    } else if filteredTags.isEmpty {
                        Text("No tags yet")
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.tertiaryText)
                            .padding(.vertical, 22)
                    }
                }
                .padding(7)
            }
            .frame(maxHeight: 250)
        }
        .background(palette.hover, in: RoundedRectangle(cornerRadius: 9))
        .onAppear { queryFocused = true }
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredTags: [String] {
        guard !normalizedQuery.isEmpty else { return knownTags }
        return knownTags.filter {
            $0.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var canAddQueryTag: Bool {
        !normalizedQuery.isEmpty && !knownTags.contains {
            $0.caseInsensitiveCompare(normalizedQuery) == .orderedSame
        }
    }

    private func tagButton(_ tag: String) -> some View {
        let count = selectedTagNames.filter { tags in
            tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
        }.count
        let isOn = count == selectedTagNames.count && !selectedTagNames.isEmpty
        let isMixed = count > 0 && !isOn

        return Button {
            setTag(tag, !isOn)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isOn ? "checkmark.square.fill" : (isMixed ? "minus.square.fill" : "square"))
                    .foregroundStyle(isOn || isMixed ? palette.accent : palette.tertiaryText)
                Text(tag)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.text)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tag \(tag)")
        .accessibilityValue(isOn ? "Selected" : (isMixed ? "Mixed" : "Not Selected"))
    }

    private func addQueryTag() {
        guard canAddQueryTag else { return }
        setTag(normalizedQuery, true)
        query = ""
    }
}
