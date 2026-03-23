import SwiftUI

struct ColumnCard: View {
    @Binding var column: Column
    @Binding var activeColumn: Column?

    var namespace: Namespace.ID

    private var leadingPadding: CGFloat {
        guard column.isExpanded else { return .zero }
        let multiplier: CGFloat = column.position.isEven ? -1 : 1
        return multiplier * 2 * Spacing.standard
    }

    private var rotationDegrees: CGFloat {
        guard column.isExpanded else { return .zero }
        return column.position.isEven ? -4 : 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.standard) {
            // Title pill
            HStack(spacing: Spacing.medium) {
                if !column.isExpanded {
                    Checkbox(column: $column)
                }

                Image(systemName: column.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(column.isExpanded ? column.accentColor : column.accentColor)
                    .frame(width: 24, height: 24)
                    .background(column.isExpanded ? Color.clear : column.accentColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))

                Text(column.title)
                    .font(.headingXS)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if column.isCompleted && !column.isExpanded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(column.accentColor)
                }
            }
            .padding(.vertical, Spacing.medium)
            .padding(.horizontal, Spacing.standard)
            .background(Color.white)
            .clipShape(.rect(cornerRadius: column.isExpanded ? 12 : 14))
            .overlay {
                if !column.isExpanded {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.stroke, lineWidth: 1)
                }
            }

            // Expanded content
            if column.isExpanded {
                Text(column.subtitle)
                    .font(.bodyS)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, Spacing.small)

                TaskView(column: $column, activeColumn: $activeColumn)
                    .matchedGeometryEffect(id: "task", in: namespace)
            }
        }
        .padding(column.isExpanded ? Spacing.standard : .zero)
        .background {
            if column.isExpanded {
                RoundedRectangle(cornerRadius: 20)
                    .fill(column.accentColor)
            }
        }
        .rotationEffect(.degrees(rotationDegrees))
        .padding(.leading, leadingPadding)
    }

    private func redactedBar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.black.opacity(0.15))
            .frame(width: width, height: 10)
    }
}
