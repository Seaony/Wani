import SwiftUI

struct WaniPageHeader: View {
    let title: String
    let symbol: String
    let color: Color
    let progress: Double?
    let palette: WaniPalette

    var body: some View {
        HStack(spacing: 11) {
            if let progress {
                WaniProgressRing(
                    progress: progress,
                    color: palette.accent,
                    background: palette.line,
                    size: 26,
                    lineWidth: 4
                )
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(palette.text)
            Spacer()
        }
    }
}

struct WaniProgressRing: View {
    let progress: Double
    let color: Color
    let background: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(background, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct WaniNavigationToolbar: ToolbarContent {
    @Environment(\.dismiss) private var dismiss
    let palette: WaniPalette

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Back")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.tertiary)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(palette.line, lineWidth: 1.5))
                .accessibilityHidden(true)
        }
    }
}

struct WaniSectionTitle: View {
    let title: String
    let palette: WaniPalette

    init(_ title: String, palette: WaniPalette) {
        self.title = title
        self.palette = palette
    }

    var body: some View {
        HStack(spacing: 11) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(palette.text)
            Rectangle().fill(palette.line).frame(height: 0.5)
        }
        .padding(.bottom, 8)
    }
}

struct WaniEmptyState: View {
    let title: String
    let message: String
    let palette: WaniPalette

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(palette.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
        .padding(.horizontal, 24)
    }
}
