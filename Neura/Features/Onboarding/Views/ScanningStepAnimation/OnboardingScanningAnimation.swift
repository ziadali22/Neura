import SwiftUI

struct OnboardingScanningAnimation: View {
    var onComplete: (() -> Void)? = nil

    @Namespace private var namespace

    @State private var columns: [Column] = []
    @State private var spacing: CGFloat = .zero
    @State private var activeColumn: Column? = nil

    var body: some View {
        VStack(spacing: spacing) {
            ForEach($columns) { $column in
                ColumnCard(column: $column, activeColumn: $activeColumn, namespace: namespace)

                if column != columns.last, !column.isExpanded {
                    Rectangle()
                        .foregroundStyle(Color.stroke)
                        .frame(width: 1, height: CGFloat(Spacing.standard * 2))
                }
            }
        }
        .task {
            await startAnimation()
        }
    }

    // MARK: - Animation

    @MainActor
    private func startAnimation() async {
        let stages: [Column] = [.scan, .organize, .share]

        // Cards enter one by one
        for stage in stages {
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { columns.append(stage) }
            try? await Task.sleep(for: .milliseconds(460))
        }

        guard !Task.isCancelled else { return }

        // Expand and overlap all cards
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            columns.indices.forEach { columns[$0].isExpanded = true }
            spacing = -CGFloat(Spacing.small)
        }

        try? await Task.sleep(for: .milliseconds(620))
        guard !Task.isCancelled else { return }

        // Cycle the active document through each stage
        await cycleActive()
    }

    @MainActor
    private func cycleActive() async {
        for column in columns {
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) { activeColumn = column }
            try? await Task.sleep(for: .milliseconds(820))
        }
        // Settle on the last active state — animation complete
        onComplete?()
    }
}

#Preview {
    OnboardingScanningAnimation()
        .padding(24)
        .background(Color.backgroundPrimary)
}
