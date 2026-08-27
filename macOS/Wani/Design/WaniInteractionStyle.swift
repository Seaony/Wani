import AppKit
import SwiftUI

struct WaniInteractiveButtonStyle: ButtonStyle {
    let palette: WaniPalette
    var cornerRadius: CGFloat = 8
    var showsHoverBackground = true
    var horizontalPadding: CGFloat = 0
    var verticalPadding: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .waniPointerFeedback(
                palette: palette,
                cornerRadius: cornerRadius,
                isPressed: configuration.isPressed,
                showsHoverBackground: showsHoverBackground
            )
    }
}

extension ButtonStyle where Self == WaniInteractiveButtonStyle {
    static func waniInteractive(
        _ palette: WaniPalette,
        cornerRadius: CGFloat = 8,
        showsHoverBackground: Bool = true,
        horizontalPadding: CGFloat = 0,
        verticalPadding: CGFloat = 0
    ) -> WaniInteractiveButtonStyle {
        WaniInteractiveButtonStyle(
            palette: palette,
            cornerRadius: cornerRadius,
            showsHoverBackground: showsHoverBackground,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
    }
}

extension View {
    func waniPointerFeedback(
        palette: WaniPalette,
        cornerRadius: CGFloat = 8,
        isPressed: Bool = false,
        showsHoverBackground: Bool = true
    ) -> some View {
        modifier(WaniPointerFeedbackModifier(
            highlightColor: showsHoverBackground ? palette.hover : nil,
            cornerRadius: cornerRadius,
            isPressed: isPressed,
            cursor: .pointingHand
        ))
    }

    func waniPointingHand() -> some View {
        modifier(WaniPointerFeedbackModifier(
            highlightColor: nil,
            cornerRadius: 0,
            isPressed: false,
            cursor: .pointingHand
        ))
    }

    func waniResizeLeftRight() -> some View {
        modifier(WaniPointerFeedbackModifier(
            highlightColor: nil,
            cornerRadius: 0,
            isPressed: false,
            cursor: .resizeLeftRight
        ))
    }
}

private struct WaniPointerFeedbackModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let highlightColor: Color?
    let cornerRadius: CGFloat
    let isPressed: Bool
    let cursor: NSCursor

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
            cursor.push()
        } else {
            NSCursor.pop()
        }
        cursorIsPushed = shouldUsePointingHand
    }
}
