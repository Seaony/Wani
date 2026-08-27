import SwiftUI

struct WaniPalette {
    let desk: Color
    let background: Color
    let sidebar: Color
    let panel: Color
    let card: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let line: Color
    let sidebarDivider: Color
    let faintLine: Color
    let hover: Color
    let selectionBackground: Color
    let accent: Color
    let softAccent: Color

    init(colorScheme: ColorScheme, accent selectedAccent: WaniAccent = .terracotta) {
        if colorScheme == .dark {
            desk = Color(hex: 0x000000)
            background = Color(hex: 0x1B1D1F)
            sidebar = Color(hex: 0x151719)
            panel = Color(hex: 0x1F2123)
            card = Color(hex: 0x282A2C)
            text = Color(hex: 0xEDEDEF)
            secondaryText = Color(hex: 0x9DA0A3)
            tertiaryText = Color(hex: 0x6E7174)
            line = Color(hex: 0x2E3032)
            sidebarDivider = Color(hex: 0x0C0D0E)
            faintLine = Color.white.opacity(0.07)
            hover = Color.white.opacity(0.07)
            selectionBackground = Color.white.opacity(0.10)
            accent = selectedAccent.color(for: colorScheme)
            softAccent = Color(hex: 0x3E9BFF).opacity(0.18)
        } else {
            desk = Color(hex: 0xDCDEE2)
            background = Color(hex: 0xF6F6F8)
            sidebar = Color(hex: 0xEDEEF0)
            panel = Color(hex: 0xFBFBFC)
            card = Color(hex: 0xFFFFFF)
            text = Color(hex: 0x26282B)
            secondaryText = Color(hex: 0x6C7075)
            tertiaryText = Color(hex: 0x9CA0A6)
            line = Color(hex: 0xE1E3E7)
            sidebarDivider = Color(hex: 0xE1E3E7)
            faintLine = Color(hex: 0x3C4655).opacity(0.10)
            hover = Color(hex: 0x3C4655).opacity(0.07)
            selectionBackground = Color(hex: 0x3C4655).opacity(0.09)
            accent = selectedAccent.color(for: colorScheme)
            softAccent = Color(hex: 0xE4F0FF)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}
