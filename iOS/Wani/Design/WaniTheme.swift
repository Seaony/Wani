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

    var color: Color {
        switch self {
        case .terracotta: Color(rgb: 0xC05A34)
        case .sienna: Color(rgb: 0xA8603F)
        case .blue: Color(rgb: 0x4A7BA7)
        case .green: Color(rgb: 0x5B8C6B)
        }
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
        self.accent = accent.color
        if colorScheme == .dark {
            background = Color(rgb: 0x1E1A16)
            group = Color(rgb: 0x26211B)
            text = Color(rgb: 0xEFE7DC)
            secondary = Color(rgb: 0xAC9F92)
            tertiary = Color(rgb: 0x83766A)
            line = Color(rgb: 0x332C25)
            hover = Color.white.opacity(0.07)
            softAccent = Color(rgb: 0xE0794E).opacity(0.18)
        } else {
            background = Color(rgb: 0xFAF5ED)
            group = Color(rgb: 0xFFFDF9)
            text = Color(rgb: 0x3A312A)
            secondary = Color(rgb: 0x786A5E)
            tertiary = Color(rgb: 0xAAA095)
            line = Color(rgb: 0xE7DDCF)
            hover = Color(rgb: 0xB49678).opacity(0.13)
            softAccent = Color(rgb: 0xF7E4D9)
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
