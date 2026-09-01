import SwiftUI

enum WaniMotion {
    static let quick = Animation.easeOut(duration: 0.12)
    static let standard = Animation.easeInOut(duration: 0.2)
    static let overlay = Animation.easeOut(duration: 0.18)
    static let taskExpansion = Animation.easeOut(duration: 0.16)
    static let taskRowExpansion = Animation.easeOut(duration: 0.38)
    static let completionRemoval = Animation.easeInOut(duration: 0.45)
    static let sidebarDisclosure = Animation.spring(
        response: 0.3,
        dampingFraction: 0.92,
        blendDuration: 0.08
    )

    static let overlayTransition = AnyTransition.opacity
    static let taskEditorTransition = AnyTransition.opacity
    static let revealTransition = AnyTransition.opacity.combined(
        with: .move(edge: .top)
    )
    static let sidebarTransition = AnyTransition.opacity.combined(
        with: .move(edge: .leading)
    )
}
