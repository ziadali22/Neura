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

struct WordTypingEffectModifier: ViewModifier {
    @Binding var shouldStartTyping: Bool
    let fullText: String
    let font: Font
    let wordsPerSecond: Double
    let onTypingCompleted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Index of the last fully committed (fully visible) word
    @State private var visibleWordCount: Int = 0
    // Reveal progress of the word currently fading in (0 → 1)
    @State private var revealProgress: CGFloat = 0
    @State private var typingTask: Task<Void, Never>? = nil

    private var words: [String] {
        fullText.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    func body(content: Content) -> some View {
        ZStack {
            // Layer 1 — committed words: sharp, fully opaque.
            content.mask { committedMask }

            // Layer 2 — current word: fades in AND sharpens from blur.
            content
                .mask { currentWordMask }
                .opacity(Double(revealProgress))
                .blur(radius: reduceMotion ? 0 : (1 - revealProgress) * 6)
        }
        .onAppear { if shouldStartTyping { startTyping() } }
        .onChange(of: shouldStartTyping) { _, new in if new { startTyping() } }
    }

    // Number of characters spanned by the first `count` words joined with spaces.
    private func charCount(upToWord count: Int) -> Int {
        words.prefix(count).joined(separator: " ").count
    }

    // Mask revealing words[0..<visibleWordCount] in white, rest clear.
    private var committedMask: some View {
        var attributed = AttributedString(fullText)
        attributed.foregroundColor = .clear
        if visibleWordCount > 0 {
            let endChar = charCount(upToWord: visibleWordCount)
            let endIdx = attributed.index(attributed.startIndex, offsetByCharacters: endChar)
            attributed[attributed.startIndex..<endIdx].foregroundColor = .white
        }
        return Text(attributed)
            .font(font)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // Mask revealing ONLY words[visibleWordCount] in white (opacity/blur applied by the layer).
    private var currentWordMask: some View {
        let wordList = words
        var attributed = AttributedString(fullText)
        attributed.foregroundColor = .clear
        if visibleWordCount < wordList.count {
            let chunkStart = visibleWordCount == 0 ? 0 : charCount(upToWord: visibleWordCount)
            let chunkEnd = charCount(upToWord: visibleWordCount + 1)
            if chunkStart < chunkEnd, chunkEnd <= fullText.count {
                let startIdx = attributed.index(attributed.startIndex, offsetByCharacters: chunkStart)
                let endIdx = attributed.index(attributed.startIndex, offsetByCharacters: chunkEnd)
                attributed[startIdx..<endIdx].foregroundColor = .white
            }
        }
        return Text(attributed)
            .font(font)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func startTyping() {
        typingTask?.cancel()
        let wordList = words
        guard !wordList.isEmpty else { return }

        let interval = 1.0 / max(wordsPerSecond, 0.5)
        // Longer fade (85% of interval) gives the blur room to read before the next word.
        let fadeDuration = interval * 0.85

        typingTask = Task { @MainActor in
            visibleWordCount = 0
            revealProgress = 0

            for i in 0..<wordList.count {
                if Task.isCancelled { return }

                // Soft blur-fade-in for this word.
                withAnimation(.easeOut(duration: fadeDuration)) {
                    revealProgress = 1
                }

                // Wait the full interval before committing
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }

                // Commit — word joins the sharp committed region, reset for next word.
                visibleWordCount = i + 1
                revealProgress = 0

                if i == wordList.count - 1 {
                    onTypingCompleted()
                }
            }
        }
    }
}
