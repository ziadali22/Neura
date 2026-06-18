import SwiftUI
import AVFoundation

struct OnboardingProfileCardIntroStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Video player

    @State private var player = AVQueuePlayer()
    @State private var looper: AVPlayerLooper?

    // MARK: - Animation state

    @State private var cardOpacity: CGFloat = 0
    @State private var cardScale: CGFloat = 0.85
    @State private var showTitle: Bool = false
    @State private var showSubtitle: Bool = false
    @State private var showButton: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero: video springs in
            VideoPlayerView(player: player)
                .containerRelativeFrame(.vertical) { h, _ in h * 0.55 }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 24)
                .opacity(cardOpacity)
                .scaleEffect(cardScale)

            Spacer(minLength: 36)

            // Text block
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.Onboarding.ProfileCardIntro.title)
                    .font(.displayL)
                    .foregroundStyle(Color.textPrimary)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 16)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                        value: showTitle
                    )

                Text(L10n.Onboarding.ProfileCardIntro.subtitle)
                    .font(.bodyL)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 16)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                        value: showSubtitle
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Continue button
            OnboardingContinueButton(action: viewModel.advance)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 24)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                    value: showButton
                )
        }
        .task { await runAnimationSequence() }
        .onDisappear { player.pause() }
    }

    // MARK: - Animation sequence

    @MainActor
    private func runAnimationSequence() async {
        setupLoopingPlayer()

        guard !reduceMotion else {
            cardOpacity = 1; cardScale = 1
            showTitle = true; showSubtitle = true; showButton = true
            return
        }

        // Video springs in
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
            cardOpacity = 1
            cardScale   = 1
        }

        // Title
        try? await Task.sleep(for: .milliseconds(400))
        showTitle = true

        // Subtitle
        try? await Task.sleep(for: .milliseconds(180))
        showSubtitle = true

        // Button
        try? await Task.sleep(for: .milliseconds(180))
        showButton = true
    }

    private func setupLoopingPlayer() {
        player.isMuted = true
        Task.detached(priority: .userInitiated) {
            guard let url = Self.videoURL() else { return }
            let item = AVPlayerItem(url: url)
            await MainActor.run {
                self.looper = AVPlayerLooper(player: self.player, templateItem: item)
                self.player.play()
            }
        }
    }

    private nonisolated static func videoURL() -> URL? {
        if let url = Bundle.main.url(forResource: "CardVideo", withExtension: "mp4") {
            return url
        }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("CardVideo.mp4")
        if FileManager.default.fileExists(atPath: tmp.path) { return tmp }
        guard let data = NSDataAsset(name: "CardVideo")?.data,
              (try? data.write(to: tmp)) != nil else { return nil }
        return tmp
    }
}

#Preview {
    OnboardingProfileCardIntroStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
