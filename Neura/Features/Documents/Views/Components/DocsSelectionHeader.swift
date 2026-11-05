import SwiftUI

struct DocsSelectionHeader: View {
    let title: String
    var titleFont: Font = .displayXL
    /// Used once at least one file is selected. Slightly smaller than the screen title.
    var countFont: Font = .headingL
    let selectedCount: Int
    let onSelectAll: () -> Void
    let onDone: () -> Void

    private var showsCount: Bool { selectedCount > 0 }

    private var displayTitle: String {
        showsCount ? L10n.Documents.selected(selectedCount) : title
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack {
                Button(action: onSelectAll) {
                    Text(L10n.Documents.selectAll)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Documents.done)
            }
        }
        .overlay {
            Text(displayTitle)
                .font(showsCount ? countFont : titleFont)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 108)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayTitle)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
    }
}
