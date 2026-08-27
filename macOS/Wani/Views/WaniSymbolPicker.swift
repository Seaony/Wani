import Foundation
import SwiftUI

struct WaniSymbolPicker: View {
    let palette: WaniPalette
    let selectedSymbol: String
    let select: (String) -> Void
    let dismiss: () -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filteredSymbols: [String] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return WaniSFSymbolCatalog.names }
        return WaniSFSymbolCatalog.names.filter {
            $0.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.tertiaryText)
                TextField("Search SF Symbols", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                Text(filteredSymbols.count.formatted())
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tertiaryText)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.waniInteractive(palette))
                .accessibilityLabel("Close Symbol Picker")
            }
            .padding(.horizontal, 14)
            .frame(height: 44)

            Rectangle()
                .fill(palette.line)
                .frame(height: 1)

            if filteredSymbols.isEmpty {
                Text("No symbols found")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.tertiaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 42), spacing: 5)],
                        spacing: 5
                    ) {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            Button {
                                select(symbol)
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 17))
                                    .foregroundStyle(
                                        symbol == selectedSymbol
                                            ? palette.accent
                                            : palette.secondaryText
                                    )
                                    .frame(width: 38, height: 38)
                                    .background(
                                        symbol == selectedSymbol
                                            ? palette.softAccent
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.waniInteractive(
                                palette,
                                cornerRadius: 8,
                                showsHoverBackground: symbol != selectedSymbol
                            ))
                            .help(symbol)
                            .accessibilityLabel(symbol)
                            .accessibilityValue(symbol == selectedSymbol ? "Selected" : "")
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 420, height: 430)
        .background(palette.panel)
        .onAppear { searchFocused = true }
        .onExitCommand(perform: dismiss)
    }
}

private enum WaniSFSymbolCatalog {
    static let names: [String] = {
        guard
            let url = Bundle.main.url(
                forResource: "SFSymbolNames",
                withExtension: "plist"
            ),
            let data = try? Data(contentsOf: url),
            let names = try? PropertyListDecoder().decode([String].self, from: data)
        else {
            return ["cube.transparent"]
        }
        return names
    }()
}
