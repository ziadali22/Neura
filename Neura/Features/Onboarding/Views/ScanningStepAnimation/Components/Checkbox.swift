import SwiftUI

struct Checkbox: View {
    @Binding var column: Column

    private let size: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(column.isCompleted ? column.accentColor : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(column.accentColor, lineWidth: 1.5)
            )
            .frame(width: size, height: size)
            .overlay {
                if column.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: column.isCompleted)
    }
}
