import SwiftUI

struct DocumentCoachmarkCallout: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Coachmark.title)
                .font(.buttonM)
                .foregroundStyle(Color.textPrimary)
            Text(L10n.Coachmark.subtitle)
                .font(.bodyS)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 210)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            // Arrow pointing down toward the FAB (offset toward trailing)
            CoachmarkArrow()
                .fill(Color.surfaceWhite)
                .frame(width: 16, height: 9)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 22)
                .offset(y: 8)
        }
    }
}

// MARK: - Arrow shape

private struct CoachmarkArrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5).ignoresSafeArea()
        DocumentCoachmarkCallout()
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.bottom, 110)
    }
}
