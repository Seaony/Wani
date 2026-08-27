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
        case .terracotta: "Blue"
        case .clay: "Teal"
        case .slateBlue: "Amber"
        case .sage: "Olive"
        case .plum: "Plum"
        }
    }

    var color: Color {
        switch self {
        case .terracotta: Color(hex: 0x0E7AFE)
        case .clay: Color(hex: 0x2C93A8)
        case .slateBlue: Color(hex: 0xE06F2C)
        case .sage: Color(hex: 0x5F8B4C)
        case .plum: Color(hex: 0x8A5A72)
        }
    }

    func color(for colorScheme: ColorScheme) -> Color {
        if self == .terracotta, colorScheme == .dark {
            return Color(hex: 0x3E9BFF)
        }
        return color
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

enum WaniDockCountMode: String, CaseIterable, Identifiable {
    case todayOnly
    case dueAndToday

    var id: Self { self }

    var title: String {
        switch self {
        case .todayOnly: "Today only"
        case .dueAndToday: "Due + Today"
        }
    }
}

enum WaniTextSize: String, CaseIterable, Identifiable {
    case small
    case standard
    case large
    case larger
    case largest

    var id: Self { self }

    var title: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        case .larger: "Larger"
        case .largest: "Largest"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .medium
        case .standard: .large
        case .large: .xLarge
        case .larger: .xxLarge
        case .largest: .xxxLarge
        }
    }
}
