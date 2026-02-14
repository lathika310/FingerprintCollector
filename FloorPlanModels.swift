import Foundation

enum FloorPlanID: String, Codable, CaseIterable, Identifiable {
    case eng4North = "ENG4_NORTH"
    case eng4South = "ENG4_SOUTH"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eng4North: return "ENG 4 North"
        case .eng4South: return "ENG 4 South"
        }
    }

    var assetName: String {
        switch self {
        case .eng4North: return "eng4_north"
        case .eng4South: return "eng4_south"
        }
    }
}

struct AnchorPoint: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var xNorm: Double   // 0..1 (origin top-left)
    var yNorm: Double   // 0..1 (origin top-left)
    var createdAt: Date = Date()
}

