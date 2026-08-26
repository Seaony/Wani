import SwiftUI

enum WaniAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

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
    case clay
    case slateBlue
    case sage
    case plum

    var id: Self { self }

    var title: String {
        switch self {
        case .terracotta: "Terracotta"
        case .clay: "Clay"
        case .slateBlue: "Slate blue"
        case .sage: "Sage"
        case .plum: "Plum"
        }
    }

    var color: Color {
        switch self {
        case .terracotta: Color(hex: 0xC05A34)
        case .clay: Color(hex: 0xA8603F)
        case .slateBlue: Color(hex: 0x4A7BA7)
        case .sage: Color(hex: 0x5B8C6B)
        case .plum: Color(hex: 0x8A5A72)
        }
    }
}

enum WaniListDensity: String, CaseIterable, Identifiable {
    case compact
    case medium
    case roomy

    var id: Self { self }

    var title: String { rawValue.capitalized }

    var rowPadding: CGFloat {
        switch self {
        case .compact: 6
        case .medium: 9
        case .roomy: 13
        }
    }
}

enum WaniLaunchDestination: String, CaseIterable, Identifiable {
    case today
    case inbox
    case upcoming

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "Today"
        case .inbox: "Inbox"
        case .upcoming: "Upcoming"
        }
    }

    var smartList: WaniSmartList {
        switch self {
        case .today: .today
        case .inbox: .inbox
        case .upcoming: .upcoming
        }
    }
}
