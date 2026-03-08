import Foundation

enum Category: String, CaseIterable, Identifiable {
    case all = "All"
    case cardiology = "Cardiology"
    case neurology = "Neurology"
    case gynaecology = "Gynaecology"

    var id: String { rawValue }
}
