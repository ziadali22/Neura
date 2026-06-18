import SwiftUI

// MARK: - Design System Colors
// Source: Figma → Neura / Colors (node 165:30212)

extension Color {

    // MARK: Brand

    /// Primary accent color - #FF5A00
    static let accent = Color(hex: "FF5C00")

    // MARK: Backgrounds

    /// Main app background - #FCFAF8
    static let backgroundPrimary = Color(hex: "FCFAF8")

    /// Category card / folder background - #F3EDE6
    static let backgroundCard = Color(hex: "F3EDE6")

    /// Modal / sheet background - #F5F1EA
    static let backgroundModal = Color(hex: "F5F1EA")

    // MARK: Text

    /// Primary text (titles, headings) - #1F1F1F
    static let textPrimary = Color(hex: "1F1F1F")

    /// Secondary text (subtitles, descriptions) - #4A4A4A
    static let textSecondary = Color(hex: "4A4A4A")

    /// Tertiary text (placeholders, timestamps) - #7A7A7A
    static let textTertiary = Color(hex: "7A7A7A")

    /// Light text on dark backgrounds - #B6B6B6
    static let textOnDark = Color(hex: "B6B6B6")

    // MARK: Surface

    /// Pure white surface - #FFFFFF
    static let surfaceWhite = Color(hex: "FFFFFF")

    /// Dark surface (cards, buttons) - #1F1F1F
    static let surfaceDark = Color(hex: "1F1F1F")

    // MARK: Border

    /// Default stroke / divider - #E7E0D8
    static let stroke = Color(hex: "E7E0D8")
}
