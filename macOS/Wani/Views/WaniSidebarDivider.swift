import AppKit
import SwiftUI

struct WaniSidebarDivider: View {
    @Binding var sidebarWidth: Double
    let keepWindowWidth: Bool
    let resizeEnded: (Double) -> Void

    @State private var dragStartWidth: Double?
    @State private var dragStartWindowFrame: NSRect?

    private let widthRange = 190.0...360.0

    var body: some View {
        Color.clear
        .frame(width: 7)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = sidebarWidth
                        dragStartWindowFrame = NSApp.keyWindow?.frame
                    }
                    let proposedWidth = (dragStartWidth ?? sidebarWidth)
                        + value.translation.width
                    withAnimation(nil) {
                        sidebarWidth = min(
                            max(proposedWidth, widthRange.lowerBound),
                            widthRange.upperBound
                        )
                    }
                    if !keepWindowWidth,
                       let startWidth = dragStartWidth,
                       let startFrame = dragStartWindowFrame,
                       let window = NSApp.keyWindow {
                        var frame = startFrame
                        frame.size.width = max(
                            window.minSize.width,
                            startFrame.width + sidebarWidth - startWidth
                        )
                        window.setFrame(frame, display: true, animate: false)
                    }
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    dragStartWindowFrame = nil
                    resizeEnded(sidebarWidth)
                }
        )
        .waniResizeLeftRight()
        .accessibilityLabel("Resize Sidebar")
    }
}
