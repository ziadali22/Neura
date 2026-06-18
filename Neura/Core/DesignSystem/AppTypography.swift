import SwiftUI

// MARK: - Design System Typography
// Font: Estedad
// To swap the font app-wide, change the `Estedad` enum below — every token picks it up.

// MARK: - Estedad font names

private enum Estedad {
    /// Flip to `true` to switch the entire app to SF Pro system font.
    static let useSFPro = false

    static let regular   = "Estedad-Regular"
    static let medium    = "Estedad-Medium"
    static let bold      = "Estedad-Bold"
    static let semibold  = "Estedad-SemiBold"

    static func font(_ name: String, size: CGFloat) -> Font {
        guard !useSFPro else {
            let weight: Font.Weight = switch name {
            case bold:      .semibold
            case medium:    .medium
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
    static let displayArt = Estedad.font(Estedad.bold, size: 42)

    /// 32pt ExtraBold - smaller art display
    static let displayArtS = Estedad.font(Estedad.bold, size: 32)

    /// 32pt Bold - large screen titles
    static let displayXL = Estedad.font(Estedad.bold, size: 32)
    static let displaySemi = Estedad.font(Estedad.semibold, size: 32)

    /// 28pt Bold - section headers
    static let displayL = Estedad.font(Estedad.bold, size: 28)

    // MARK: Heading

    /// 24pt Bold
    static let headingL = Estedad.font(Estedad.bold, size: 24)

    /// 20pt Medium
    static let headingM = Estedad.font(Estedad.medium, size: 20)

    /// 18pt Bold
    static let headingS = Estedad.font(Estedad.bold, size: 18)

    /// 16pt Bold
    static let headingXS = Estedad.font(Estedad.bold, size: 16)

    // MARK: Body

    /// 16pt Regular - primary body text
    static let bodyL = Estedad.font(Estedad.regular, size: 16)
    static let BodyML = Estedad.font(Estedad.medium, size: 16)

    /// 14pt Regular - secondary body text
    static let bodyS = Estedad.font(Estedad.regular, size: 14)

    // MARK: Button

    /// 17pt Bold - primary buttons
    static let buttonL = Estedad.font(Estedad.bold, size: 17)

    /// 15pt Bold - secondary buttons
    static let buttonM = Estedad.font(Estedad.bold, size: 15)

    // MARK: Label & Caption

    /// 14pt Regular - art labels
    static let labelArt = Estedad.font(Estedad.regular, size: 14)

    /// 13pt Bold - metadata, tags
    static let labelM = Estedad.font(Estedad.bold, size: 13)

    /// 12pt Regular - timestamps, footnotes
    static let captionS = Estedad.font(Estedad.regular, size: 12)

    // MARK: Stats

    /// 28pt Bold - large stat value (e.g. "170 cm")
    static let statValue = Estedad.font(Estedad.bold, size: 28)

    /// 16pt Medium - stat label (e.g. "Height")
    static let statLabel = Estedad.font(Estedad.medium, size: 16)

    /// 13pt Medium - stat sublabel / unit (e.g. "cm", "last updated")
    static let statUnit = Estedad.font(Estedad.medium, size: 13)
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
