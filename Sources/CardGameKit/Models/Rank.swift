import Foundation

/// Rank of a Spanish deck card. Game-specific values (e.g. Mus musValue, Comparable ordering)
/// are added in each game via extension.
public enum Rank: Int, CaseIterable, Sendable, Codable, Hashable {
    case as_ = 1, two = 2, four = 4, five = 5, six = 6, seven = 7
    case sota = 10, caballo = 11, rey = 12, three = 3

    /// File name suffix used to locate card images in the asset catalog.
    /// Format: "1", "2", "sota", "caballo", "rey", etc.
    public var assetSuffix: String {
        switch self {
        case .as_:    return "1"
        case .two:    return "2"
        case .three:  return "3"
        case .four:   return "4"
        case .five:   return "5"
        case .six:    return "6"
        case .seven:  return "7"
        case .sota:   return "sota"
        case .caballo: return "caballo"
        case .rey:    return "rey"
        }
    }
}
