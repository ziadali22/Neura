import SwiftUI

// MARK: - Design System Typography
// Font: Cairo (Google Fonts)
// To swap the font app-wide, change the `Cairo` enum below — every token picks it up.

// MARK: - Cairo font names

private enum Cairo {
    /// Flip to `true` to switch the entire app to SF Pro system font.
    static let useSFPro = true

    static let light     = "Cairo-Regular"
    static let regular   = "Cairo-Regular"
    static let medium    = "Cairo-Medium"
    static let bold      = "Cairo-SemiBold"
    static let extraBold = "Cairo-Bold"

    static func font(_ name: String, size: CGFloat) -> Font {
        guard !useSFPro else {
            let weight: Font.Weight = switch name {
            case extraBold: .bold
            case bold:      .semibold
            case medium:    .medium
            case light:     .light
            default:        .regular
            }
            return .system(size: size, weight: weight, design: .default)
        }
        return Font.custom(name, size: size)
    }
}

// MARK: - Font Tokens

extension Font {

    // MARK: Display

    /// 42pt ExtraBold - hero text, profile names
    static let displayArt = Cairo.font(Cairo.extraBold, size: 42)

    /// 32pt ExtraBold - smaller art display
    static let displayArtS = Cairo.font(Cairo.extraBold, size: 32)

    /// 32pt Bold - large screen titles
    static let displayXL = Cairo.font(Cairo.bold, size: 32)

    /// 28pt Bold - section headers
    static let displayL = Cairo.font(Cairo.bold, size: 28)

    // MARK: Heading

    /// 24pt Bold
    static let headingL = Cairo.font(Cairo.bold, size: 24)

    /// 20pt Medium
    static let headingM = Cairo.font(Cairo.medium, size: 20)

    /// 18pt Bold
    static let headingS = Cairo.font(Cairo.bold, size: 18)

    /// 16pt Bold
    static let headingXS = Cairo.font(Cairo.bold, size: 16)

    // MARK: Body

    /// 16pt Regular - primary body text
    static let bodyL = Cairo.font(Cairo.regular, size: 16)

    /// 14pt Regular - secondary body text
    static let bodyS = Cairo.font(Cairo.regular, size: 14)

    // MARK: Button

    /// 17pt Bold - primary buttons
    static let buttonL = Cairo.font(Cairo.bold, size: 17)

    /// 15pt Bold - secondary buttons
    static let buttonM = Cairo.font(Cairo.bold, size: 15)

    // MARK: Label & Caption

    /// 14pt Regular - art labels
    static let labelArt = Cairo.font(Cairo.regular, size: 14)

    /// 13pt Bold - metadata, tags
    static let labelM = Cairo.font(Cairo.bold, size: 13)

    /// 12pt Regular - timestamps, footnotes
    static let captionS = Cairo.font(Cairo.regular, size: 12)

    // MARK: Stats

    /// 28pt Bold - large stat value (e.g. "170 cm")
    static let statValue = Cairo.font(Cairo.bold, size: 28)

    /// 16pt Medium - stat label (e.g. "Height")
    static let statLabel = Cairo.font(Cairo.medium, size: 16)

    /// 13pt Medium - stat sublabel / unit (e.g. "cm", "last updated")
    static let statUnit = Cairo.font(Cairo.medium, size: 13)
}

// MARK: - Full Typography Style (includes line height & letter spacing)

struct AppTextStyle: ViewModifier {
    let font: Font
    let lineHeight: CGFloat
    let letterSpacing: CGFloat

    func body(content: Content) -> some View {
        content
            .font(font)
            .lineSpacing(lineHeight - UIFont.preferredFont(forTextStyle: .body).lineHeight)
            .tracking(letterSpacing)
    }
}

extension View {

    // MARK: Display

    func displayArtStyle() -> some View {
        modifier(AppTextStyle(font: .displayArt, lineHeight: 45.78, letterSpacing: 0))
    }

    func displayArtSStyle() -> some View {
        modifier(AppTextStyle(font: .displayArtS, lineHeight: 34.88, letterSpacing: 0))
    }

    func displayXLStyle() -> some View {
        modifier(AppTextStyle(font: .displayXL, lineHeight: 38.4, letterSpacing: -0.16))
    }

    func displayLStyle() -> some View {
        modifier(AppTextStyle(font: .displayL, lineHeight: 33.6, letterSpacing: -0.084))
    }

    // MARK: Heading

    func headingLStyle() -> some View {
        modifier(AppTextStyle(font: .headingL, lineHeight: 30, letterSpacing: -0.048))
    }

    func headingMStyle() -> some View {
        modifier(AppTextStyle(font: .headingM, lineHeight: 26, letterSpacing: -0.02))
    }

    func headingSStyle() -> some View {
        modifier(AppTextStyle(font: .headingS, lineHeight: 22.5, letterSpacing: -0.018))
    }

    func headingXSStyle() -> some View {
        modifier(AppTextStyle(font: .headingXS, lineHeight: 21.6, letterSpacing: 0))
    }

    // MARK: Body

    func bodyLStyle() -> some View {
        modifier(AppTextStyle(font: .bodyL, lineHeight: 24, letterSpacing: 0))
    }

    func bodySStyle() -> some View {
        modifier(AppTextStyle(font: .bodyS, lineHeight: 19.6, letterSpacing: 0.028))
    }

    // MARK: Button

    func buttonLStyle() -> some View {
        modifier(AppTextStyle(font: .buttonL, lineHeight: 22.1, letterSpacing: 0))
    }

    func buttonMStyle() -> some View {
        modifier(AppTextStyle(font: .buttonM, lineHeight: 19.5, letterSpacing: 0))
    }

    // MARK: Label & Caption

    func labelArtStyle() -> some View {
        modifier(AppTextStyle(font: .labelArt, lineHeight: 18.2, letterSpacing: 0))
    }

    func labelMStyle() -> some View {
        modifier(AppTextStyle(font: .labelM, lineHeight: 18.2, letterSpacing: 0.039))
    }

    func captionSStyle() -> some View {
        modifier(AppTextStyle(font: .captionS, lineHeight: 16.2, letterSpacing: 0.048))
    }
}
