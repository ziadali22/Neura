import SwiftUI
import AVFoundation
import UIKit

/// A simple video player view with no controls and a transparent background.
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> _PlayerLayerView {
        let view = _PlayerLayerView()
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: _PlayerLayerView, context: Context) {}
}

// MARK: - Internal UIView

final class _PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    func setPlayer(_ player: AVPlayer) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }
}
