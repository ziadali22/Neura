import SwiftUI

extension View {
    func wordTypingEffect(
        shouldStartTyping: Binding<Bool>,
        fullText: String,
        font: Font,
        wordsPerSecond: Double = 1.5,
        onTypingCompleted: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            WordTypingEffectModifier(
                shouldStartTyping: shouldStartTyping,
                fullText: fullText,
                font: font,
                wordsPerSecond: wordsPerSecond,
                onTypingCompleted: onTypingCompleted
            )
        )
    }
}

/// Reveals text as a flowing cascade: each word is its own view that fades and
/// un-blurs in, with OVERLAPPING timing so several words animate at once — a
/// continuous wave rather than one-word-at-a-time stamps.
///
/// Words inherit the ambient `foregroundStyle`, so apply `.foregroundStyle(...)`
/// to (or outside of) `.wordTypingEffect(...)` rather than before it.
struct WordTypingEffectModifier: ViewModifier {
    @Binding var shouldStartTyping: Bool
    let fullText: String
    let font: Font
    let wordsPerSecond: Double
    let onTypingCompleted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Per-word reveal progress (0 → 1).
    @State private var progress: [Double] = []
    @State private var typingTask: Task<Void, Never>? = nil

    private var words: [String] {
        fullText.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    func body(content: Content) -> some View {
        // `content` is intentionally unused — we render each word individually
        // so every word can fade and blur independently.
        _ = content
        return FlowLayout(spacing: 5, lineSpacing: 7) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let p = index < progress.count ? progress[index] : 0
                Text(word)
                    .font(font)
                    .opacity(p)
                    .blur(radius: reduceMotion ? 0 : (1 - p) * 5)
            }
        }
        .onAppear { if shouldStartTyping { start() } }
        .onChange(of: shouldStartTyping) { _, new in if new { start() } }
    }

    private func start() {
        typingTask?.cancel()
        let count = words.count
        guard count > 0 else { return }

        // Snap to hidden (no animation), then cascade in.
        progress = Array(repeating: 0, count: count)

        guard !reduceMotion else {
            progress = Array(repeating: 1, count: count)
            onTypingCompleted()
            return
        }

        let stagger = 1.0 / max(wordsPerSecond, 0.5)   // delay between word starts
        let fade = max(stagger * 2.4, 0.45)            // > stagger ⇒ overlapping cascade

        typingTask = Task { @MainActor in
            for i in 0..<count {
                if Task.isCancelled { return }
                withAnimation(.easeOut(duration: fade)) {
                    if i < progress.count { progress[i] = 1 }
                }
                try? await Task.sleep(nanoseconds: UInt64(stagger * 1_000_000_000))
            }
            // Let the last word finish fading before signalling completion.
            try? await Task.sleep(nanoseconds: UInt64(fade * 1_000_000_000))
            if Task.isCancelled { return }
            onTypingCompleted()
        }
    }
}

// MARK: - Flow layout

/// A simple wrapping layout that flows subviews left-to-right and centers each row.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height }
            + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = maxWidth.isFinite ? maxWidth : (rows.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let prospective = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty, prospective > maxWidth {
                rows.append(current)
                current = Row(items: [index], width: size.width, height: size.height)
            } else {
                current.width = prospective
                current.items.append(index)
                current.height = max(current.height, size.height)
            }
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
