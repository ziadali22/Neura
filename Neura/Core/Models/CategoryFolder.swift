import SwiftUI

struct CategoryFolder: Identifiable {
    let id = UUID()
    let name: String
    var count: Int
    let icon: String
    let gradientColors: [Color]
}
