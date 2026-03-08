import Foundation

struct GroupedDocument: Identifiable {
    let id = UUID()
    let month: String
    let documents: [Document]
}
