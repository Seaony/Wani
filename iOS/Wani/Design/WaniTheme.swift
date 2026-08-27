import SwiftUI

enum WaniAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum WaniAccent: String, CaseIterable, Identifiable {
    case terracotta
    case sienna
    case blue
    case green

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terracotta: "Blue"
        case .sienna: "Teal"
        case .blue: "Amber"
        case .green: "Olive"
        }
    }

    var color: Color {
        switch self {
        case .terracotta: Color(rgb: 0x0E7AFE)
        case .sienna: Color(rgb: 0x2C93A8)
        case .blue: Color(rgb: 0xE06F2C)
        case .green: Color(rgb: 0x5F8B4C)
        }
    }

    func color(for colorScheme: ColorScheme) -> Color {
        if self == .terracotta, colorScheme == .dark {
            return Color(rgb: 0x3E9BFF)
        }
        return color
    }
}

struct WaniPalette {
    let background: Color
    let group: Color
    let text: Color
    let secondary: Color
    let tertiary: Color
    let line: Color
    let hover: Color
    let softAccent: Color
    let accent: Color

    init(colorScheme: ColorScheme, accent: WaniAccent) {
        self.accent = accent.color(for: colorScheme)
        if colorScheme == .dark {
            background = Color(rgb: 0x141618)
            group = Color(rgb: 0x232527)
            text = Color(rgb: 0xEDEDEF)
            secondary = Color(rgb: 0x9DA0A3)
            tertiary = Color(rgb: 0x6E7174)
            line = Color(rgb: 0x2E3032)
            hover = Color.white.opacity(0.07)
            softAccent = Color(rgb: 0x3E9BFF).opacity(0.18)
        } else {
            background = Color(rgb: 0xF6F6F8)
            group = Color(rgb: 0xFFFFFF)
            text = Color(rgb: 0x26282B)
            secondary = Color(rgb: 0x6C7075)
            tertiary = Color(rgb: 0x9CA0A6)
            line = Color(rgb: 0xE1E3E7)
            hover = Color(rgb: 0x3C4655).opacity(0.07)
            softAccent = Color(rgb: 0xE4F0FF)
        }
    }
}

/// Presentation for the shared smart lists. iOS uses the lighter outline symbols,
/// so this stays on the platform side rather than in the shared domain.
extension WaniSmartList {
    var title: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .inbox: "tray"
        case .today: "star.fill"
        case .upcoming: "calendar"
        case .anytime: "square.3.layers.3d"
        case .someday: "archivebox"
        case .logbook: "checkmark.square"
        case .trash: "trash"
        }
    }
}

extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8) & 0xff) / 255,
            blue: Double(rgb & 0xff) / 255
        )
    }
}
