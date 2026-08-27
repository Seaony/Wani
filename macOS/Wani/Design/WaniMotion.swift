import SwiftUI

enum WaniMotion {
    static let quick = Animation.easeOut(duration: 0.12)
    static let standard = Animation.easeInOut(duration: 0.2)
    static let overlay = Animation.easeOut(duration: 0.18)

    static let overlayTransition = AnyTransition.opacity
    static let revealTransition = AnyTransition.opacity.combined(
        with: .move(edge: .top)
    )
    static let sidebarTransition = AnyTransition.opacity.combined(
        with: .move(edge: .leading)
    )
}
