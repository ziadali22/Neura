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

    // Index of the last fully committed (fully visible) word
    @State private var visibleWordCount: Int = 0
    // Opacity of the word currently fading in (0 → 1)
    @State private var revealProgress: CGFloat = 0
    @State private var typingTask: Task<Void, Never>? = nil

    private var words: [String] {
        fullText.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    func body(content: Content) -> some View {
        content
            .mask { wordMask }
            .onAppear { if shouldStartTyping { startTyping() } }
            .onChange(of: shouldStartTyping) { _, new in if new { startTyping() } }
    }

    // Builds an AttributedString where:
    //  - words[0..<visibleWordCount]           → fully white (opacity 1)
    //  - words[visibleWordCount]               → white at revealProgress opacity (fading in)
    //  - words[visibleWordCount+1...]          → clear (hidden)
    private var wordMask: some View {
        let wordList = words
        var attributed = AttributedString(fullText)
        attributed.foregroundColor = .clear

        func charRange(upToWord count: Int) -> Int {
            wordList.prefix(count).joined(separator: " ").count
        }

        // Fully visible region
        if visibleWordCount > 0 {
            let endChar = charRange(upToWord: visibleWordCount)
            let endIdx = attributed.index(attributed.startIndex, offsetByCharacters: endChar)
            attributed[attributed.startIndex..<endIdx].foregroundColor = .white
        }

        // Currently fading-in word (includes the leading space for words after the first)
        if visibleWordCount < wordList.count, revealProgress > 0 {
            let chunkStart = visibleWordCount == 0
                ? 0
                : charRange(upToWord: visibleWordCount) // end of prev visible text = start of space+word
            let chunkEnd = charRange(upToWord: visibleWordCount + 1)

            if chunkStart < chunkEnd, chunkEnd <= fullText.count {
                let startIdx = attributed.index(attributed.startIndex, offsetByCharacters: chunkStart)
                let endIdx   = attributed.index(attributed.startIndex, offsetByCharacters: chunkEnd)
                attributed[startIdx..<endIdx].foregroundColor = .white.opacity(Double(revealProgress))
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
        // Fade duration is ~65% of the interval so the word is fully visible before the next one starts
        let fadeDuration = interval * 0.65

        typingTask = Task { @MainActor in
            visibleWordCount = 0
            revealProgress = 0

            for i in 0..<wordList.count {
                if Task.isCancelled { return }

                // Soft fade-in for this word
                withAnimation(.easeInOut(duration: fadeDuration)) {
                    revealProgress = 1
                }

                // Wait the full interval before committing
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { return }

                // Commit — word moves into the fully-visible region, reset progress for next word
                visibleWordCount = i + 1
                revealProgress = 0

                if i == wordList.count - 1 {
                    onTypingCompleted()
                }
            }
        }
    }
}
