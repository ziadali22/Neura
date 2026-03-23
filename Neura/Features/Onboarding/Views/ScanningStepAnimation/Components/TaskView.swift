import SwiftUI

struct TaskView: View {
    @Binding var column: Column
    @Binding var activeColumn: Column?

    @State private var scanLineY: CGFloat = -14

    private var isActive: Bool { column == activeColumn }

    var body: some View {
        if isActive {
            HStack(spacing: 12) {
                // Document icon with scan line overlay for the Scan stage
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(column.accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(column.accentColor)

                    if column.position == 0 {
                        Rectangle()
                            .fill(column.accentColor.opacity(0.7))
                            .frame(width: 36, height: 1.5)
                            .offset(y: scanLineY)
                            .clipped()
                    }
                }
                .clipShape(.rect(cornerRadius: 8))
                .onAppear {
                    guard column.position == 0 else { return }
                    withAnimation(
                        .easeInOut(duration: 0.65)
                        .repeatForever(autoreverses: true)
                    ) {
                        scanLineY = 14
                    }
                }

                // File name + stage status
                VStack(alignment: .leading, spacing: 4) {
                    Text(column.documentName)
                        .font(.labelM)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1)

                    stageStatus
                }

                Spacer()
            }
            .padding(Spacing.standard)
            .background(Color.white)
            .clipShape(.rect(cornerRadius: 12))
            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        }
    }

    @ViewBuilder
    private var stageStatus: some View {
        switch column.position {
        case 0:
            HStack(spacing: 4) {
                Circle()
                    .fill(column.accentColor)
                    .frame(width: 5, height: 5)
                Text("Scanning…")
                    .font(.captionS)
                    .foregroundStyle(column.accentColor)
            }
        case 1:
            Text("Blood Test")
                .font(.captionS)
                .foregroundStyle(column.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(column.accentColor.opacity(0.1))
                .clipShape(Capsule())
        default:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(column.accentColor)
                Text("Ready to share")
                    .font(.captionS)
                    .foregroundStyle(column.accentColor)
            }
        }
    }
}
