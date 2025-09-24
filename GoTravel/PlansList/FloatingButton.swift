import SwiftUI

struct FloatingButton: View {
    var action: () -> Void
    var systemImageName: String = "plus"
    var size: CGFloat = 56
    var backgroundColor: Color = Color.accentColor
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 4)

                Image(systemName: systemImageName)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel(Text("追加"))
    }
}
