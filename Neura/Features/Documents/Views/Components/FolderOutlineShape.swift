import SwiftUI

/// Classic macOS/iOS folder shape: body with a rounded tab at the top-left
/// and a concave shoulder transitioning to the body top edge.
struct FolderOutlineShape: Shape {
    var tabWidthFraction: CGFloat = 0.40
    var tabHeight: CGFloat = 26
    var cornerRadius: CGFloat = 22
    var tabCornerRadius: CGFloat = 11
    var shoulderRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let tw = rect.width * tabWidthFraction
        let th = tabHeight
        let r  = cornerRadius
        let tr = tabCornerRadius
        let sr = shoulderRadius

        var p = Path()

        // ── Tab ─────────────────────────────────────────────────────────
        p.move(to: CGPoint(x: tr, y: 0))
        p.addLine(to: CGPoint(x: tw - tr, y: 0))

        // Tab: top-right corner  (arc UP → RIGHT, CW on screen)
        p.addArc(center: CGPoint(x: tw - tr, y: tr),
                 radius: tr,
                 startAngle: .degrees(-90), endAngle: .degrees(0),
                 clockwise: false)

        // Tab: right side down to shoulder entry
        p.addLine(to: CGPoint(x: tw, y: th - sr))

        // Shoulder: concave arc — centre to the right of the junction
        //   A = (tw, th-sr)  →  B = (tw+sr, th)  via bottom-left quadrant
        p.addArc(center: CGPoint(x: tw + sr, y: th - sr),
                 radius: sr,
                 startAngle: .degrees(180), endAngle: .degrees(90),
                 clockwise: true)          // CCW on screen = concave dip

        // ── Body ─────────────────────────────────────────────────────────
        p.addLine(to: CGPoint(x: rect.maxX - r, y: th))

        // Body: top-right corner
        p.addArc(center: CGPoint(x: rect.maxX - r, y: th + r),
                 radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0),
                 clockwise: false)

        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))

        // Body: bottom-right corner
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                 radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90),
                 clockwise: false)

        p.addLine(to: CGPoint(x: r, y: rect.maxY))

        // Body: bottom-left corner
        p.addArc(center: CGPoint(x: r, y: rect.maxY - r),
                 radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180),
                 clockwise: false)

        // Left side up through tab
        p.addLine(to: CGPoint(x: 0, y: tr))

        // Tab: top-left corner  (arc LEFT → UP, CW on screen)
        p.addArc(center: CGPoint(x: tr, y: tr),
                 radius: tr,
                 startAngle: .degrees(180), endAngle: .degrees(-90),
                 clockwise: false)

        p.closeSubpath()
        return p
    }
}
