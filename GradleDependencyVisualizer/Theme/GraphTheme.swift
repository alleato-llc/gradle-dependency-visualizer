import Foundation

enum GraphTheme: String, CaseIterable, Identifiable {
    case pastel
    case ocean
    case earth
    case monochrome
    case highContrast
    case warmGradient
    case coolGradient
    case sunset
    case forest
    case neon
    case nordic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pastel: "Pastel"
        case .ocean: "Ocean"
        case .earth: "Earth"
        case .monochrome: "Monochrome"
        case .highContrast: "High Contrast"
        case .warmGradient: "Warm Gradient"
        case .coolGradient: "Cool Gradient"
        case .sunset: "Sunset"
        case .forest: "Forest"
        case .neon: "Neon"
        case .nordic: "Nordic"
        }
    }

    var nodeColors: [String] {
        switch self {
        case .pastel:
            ["#FFB3BA", "#FFDFBA", "#FFFFBA", "#BAFFC9",
             "#BAE1FF", "#E8BAFF", "#FFB3E6", "#C9BAFF",
             "#BAFFF5", "#FFE8BA"]
        case .ocean:
            ["#0077B6", "#00B4D8", "#48CAE4", "#90E0EF",
             "#023E8A", "#0096C7", "#ADE8F4", "#CAF0F8",
             "#005F73", "#94D2BD"]
        case .earth:
            ["#606C38", "#283618", "#DDA15E", "#BC6C25",
             "#FEFAE0", "#8B7355", "#A0522D", "#6B8E23",
             "#BDB76B", "#D2B48C"]
        case .monochrome:
            ["#2B2B2B", "#404040", "#555555", "#6A6A6A",
             "#808080", "#959595", "#AAAAAA", "#BFBFBF",
             "#D4D4D4", "#E9E9E9"]
        case .highContrast:
            ["#FF0000", "#00AA00", "#0000FF", "#FF8800",
             "#AA00AA", "#00AAAA", "#FFDD00", "#FF00AA",
             "#88FF00", "#0088FF"]
        case .warmGradient:
            ["#E53935", "#F4511E", "#FB8C00", "#FFB300",
             "#FDD835", "#C62828", "#D84315", "#EF6C00",
             "#FF8F00", "#F9A825"]
        case .coolGradient:
            ["#1565C0", "#0277BD", "#00838F", "#00695C",
             "#4527A0", "#283593", "#1976D2", "#0288D1",
             "#00ACC1", "#7B1FA2"]
        case .sunset:
            ["#E65100", "#F4511E", "#FF7043", "#FF8A65",
             "#CE93D8", "#BA68C8", "#AB47BC", "#FFB74D",
             "#FFCC80", "#F48FB1"]
        case .forest:
            ["#1B5E20", "#2E7D32", "#388E3C", "#43A047",
             "#4E342E", "#5D4037", "#6D4C41", "#66BB6A",
             "#81C784", "#A5D6A7"]
        case .neon:
            ["#00E5FF", "#76FF03", "#FF1744", "#D500F9",
             "#FFEA00", "#00E676", "#FF6D00", "#651FFF",
             "#F50057", "#00B0FF"]
        case .nordic:
            ["#5E81AC", "#81A1C1", "#88C0D0", "#8FBCBB",
             "#A3BE8C", "#B48EAD", "#BF616A", "#D08770",
             "#EBCB8B", "#E5E9F0"]
        }
    }

    var rootNodeColor: String {
        switch self {
        case .pastel: "#4A90D9"
        case .ocean: "#03045E"
        case .earth: "#3A5A40"
        case .monochrome: "#1A1A1A"
        case .highContrast: "#000000"
        case .warmGradient: "#B71C1C"
        case .coolGradient: "#0D1B2A"
        case .sunset: "#4A0E4E"
        case .forest: "#0B2618"
        case .neon: "#1A1A2E"
        case .nordic: "#2E3440"
        }
    }

    var conflictNodeColor: String { "#FF6B6B" }

    var omittedNodeColor: String { "#B0B0B0" }

    var edgeColor: String {
        switch self {
        case .pastel: "#808080"
        case .ocean: "#457B9D"
        case .earth: "#5C4033"
        case .monochrome: "#666666"
        case .highContrast: "#000000"
        case .warmGradient: "#8B4513"
        case .coolGradient: "#37474F"
        case .sunset: "#7B4B6A"
        case .forest: "#3E2723"
        case .neon: "#4A4A6A"
        case .nordic: "#4C566A"
        }
    }
}
