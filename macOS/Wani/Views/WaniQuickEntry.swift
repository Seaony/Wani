import SwiftUI

struct WaniQuickEntry: View {
    let palette: WaniPalette
    let destination: String
    @Binding var title: String
    let save: () -> Void
    let dismiss: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
                .waniPointingHand()

            VStack(alignment: .leading, spacing: 0) {
                Text("QUICK ENTRY")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.tertiaryText)
                    .padding(.bottom, 9)

                TextField("What's on your mind?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16.5, weight: .medium))
                    .focused($isFocused)
                    .onSubmit(save)
                    .padding(.bottom, 10)

                Rectangle().fill(palette.line).frame(height: 1)

                HStack(spacing: 7) {
                    Text(destination)
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(palette.softAccent, in: RoundedRectangle(cornerRadius: 8))
                    Text("Return to save · Esc to dismiss")
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.tertiaryText)
                    Spacer()
                    Button(action: save) {
                        Text("Save")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 7)
                            .background(palette.accent, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.waniInteractive(palette, showsHoverBackground: false))
                }
                .padding(.top, 11)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(width: 520)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.28), radius: 34, y: 18)
            .padding(.top, 126)
        }
        .onAppear { isFocused = true }
        .onExitCommand(perform: dismiss)
    }
}
