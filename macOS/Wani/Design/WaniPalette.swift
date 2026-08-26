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
    let faintLine: Color
    let hover: Color
    let accent: Color
    let softAccent: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            desk = Color(hex: 0x100E0C)
            background = Color(hex: 0x1D1915)
            sidebar = Color(hex: 0x231E1A)
            panel = Color(hex: 0x1E1A16)
            card = Color(hex: 0x282219)
            text = Color(hex: 0xEFE7DC)
            secondaryText = Color(hex: 0xAC9F92)
            tertiaryText = Color(hex: 0x83766A)
            line = Color(hex: 0x342D26)
            faintLine = Color.white.opacity(0.07)
            hover = Color.white.opacity(0.07)
            accent = Color(hex: 0xE0794E)
            softAccent = Color(hex: 0xE0794E).opacity(0.16)
        } else {
            desk = Color(hex: 0xE7DDCE)
            background = Color(hex: 0xF4EEE6)
            sidebar = Color(hex: 0xEFE7DB)
            panel = Color(hex: 0xFAF5ED)
            card = Color(hex: 0xFFFDF9)
            text = Color(hex: 0x3A312A)
            secondaryText = Color(hex: 0x786A5E)
            tertiaryText = Color(hex: 0xAAA095)
            line = Color(hex: 0xE7DDCF)
            faintLine = Color(hex: 0x8C735A).opacity(0.11)
            hover = Color(hex: 0xB49678).opacity(0.14)
            accent = Color(hex: 0xC05A34)
            softAccent = Color(hex: 0xF7E4D9)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}
