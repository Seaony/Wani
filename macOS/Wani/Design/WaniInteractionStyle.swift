import AppKit
import SwiftUI

struct WaniInteractiveButtonStyle: ButtonStyle {
    let palette: WaniPalette
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .waniPointerFeedback(
                palette: palette,
                cornerRadius: cornerRadius,
                isPressed: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == WaniInteractiveButtonStyle {
    static func waniInteractive(
        _ palette: WaniPalette,
        cornerRadius: CGFloat = 8
    ) -> WaniInteractiveButtonStyle {
        WaniInteractiveButtonStyle(
            palette: palette,
            cornerRadius: cornerRadius
        )
    }
}

extension View {
    func waniPointerFeedback(
        palette: WaniPalette,
        cornerRadius: CGFloat = 8,
        isPressed: Bool = false
    ) -> some View {
        modifier(WaniPointerFeedbackModifier(
            highlightColor: palette.hover,
            cornerRadius: cornerRadius,
            isPressed: isPressed
        ))
    }

    func waniPointingHand() -> some View {
        modifier(WaniPointerFeedbackModifier(
            highlightColor: nil,
            cornerRadius: 0,
            isPressed: false
        ))
    }
}

private struct WaniPointerFeedbackModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let highlightColor: Color?
    let cornerRadius: CGFloat
    let isPressed: Bool

    @State private var isHovered = false
    @State private var cursorIsPushed = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .opacity(isPressed && isEnabled ? 0.72 : 1)
            .overlay {
                if let highlightColor, isHovered && isEnabled {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(highlightColor)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.1), value: isHovered)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .onHover { hovering in
                isHovered = hovering
                updateCursor(hovering && isEnabled)
            }
            .onChange(of: isEnabled) { _, enabled in
                updateCursor(isHovered && enabled)
            }
            .onDisappear {
                updateCursor(false)
            }
    }

    private func updateCursor(_ shouldUsePointingHand: Bool) {
        guard cursorIsPushed != shouldUsePointingHand else { return }
        if shouldUsePointingHand {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
        cursorIsPushed = shouldUsePointingHand
    }
}
