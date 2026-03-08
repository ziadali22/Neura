import SwiftUI

// MARK: - Design System Typography
// Source: Figma → Neura / Typography (node 244:8109)
// All styles use SF Pro (system font)

// MARK: - Font Tokens

extension Font {

    // MARK: Display

    /// 42pt Heavy - hero text, profile names
    static let displayArt = Font.system(size: 42, weight: .heavy)

    /// 32pt Heavy - smaller art display
    static let displayArtS = Font.system(size: 32, weight: .heavy)

    /// 32pt Semibold - large screen titles
    static let displayXL = Font.system(size: 32, weight: .semibold)

    /// 28pt Semibold - section headers
    static let displayL = Font.system(size: 28, weight: .semibold)

    // MARK: Heading

    /// 24pt Semibold
    static let headingL = Font.system(size: 24, weight: .semibold)

    /// 20pt Regular
    static let headingM = Font.system(size: 20, weight: .regular)

    /// 18pt Medium
    static let headingS = Font.system(size: 18, weight: .medium)

    /// 16pt Medium
    static let headingXS = Font.system(size: 16, weight: .medium)

    // MARK: Body

    /// 16pt Regular - primary body text
    static let bodyL = Font.system(size: 16, weight: .regular)

    /// 14pt Regular - secondary body text
    static let bodyS = Font.system(size: 14, weight: .regular)

    // MARK: Button

    /// 17pt Semibold - primary buttons
    static let buttonL = Font.system(size: 17, weight: .semibold)

    /// 15pt Semibold - secondary buttons
    static let buttonM = Font.system(size: 15, weight: .semibold)

    // MARK: Label & Caption

    /// 14pt Regular - art labels
    static let labelArt = Font.system(size: 14, weight: .regular)

    /// 13pt Medium - metadata, tags
    static let labelM = Font.system(size: 13, weight: .medium)

    /// 12pt Regular - timestamps, footnotes
    static let captionS = Font.system(size: 12, weight: .regular)
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
