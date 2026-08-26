import SwiftUI

struct WaniHeadingRow: View {
    @Bindable var heading: WaniHeading
    let palette: WaniPalette
    let count: Int
    let save: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Heading", text: $heading.title)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(palette.tertiaryText)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 80, alignment: .leading)
                .onSubmit(save)
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
            if count > 0 {
                Text(count.formatted())
                    .font(.system(size: 11))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
