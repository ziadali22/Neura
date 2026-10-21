import SwiftUI

/// One page in the Document Details strip. Identity is separate from the image
/// so deleting, reordering, and the full-screen pager stay stable.
struct ScannedPage: Identifiable {
    let id: UUID
    let image: UIImage

    init(id: UUID = UUID(), image: UIImage) {
        self.id = id
        self.image = image
    }
}
