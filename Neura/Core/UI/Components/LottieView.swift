import SwiftUI
import Lottie

/// SwiftUI wrapper around Lottie's `LottieAnimationView`.
/// Loads a named animation from the main bundle and plays it.
struct LottieView: UIViewRepresentable {
    /// Bundle resource name (without the `.json` extension).
    let name: String
    var loopMode: LottieLoopMode = .playOnce
    var contentMode: UIView.ContentMode = .scaleAspectFit
    /// Called once when a `.playOnce` animation finishes playing.
    var onComplete: () -> Void = {}

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: name)
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        animationView.play { finished in
            if finished { onComplete() }
        }
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
