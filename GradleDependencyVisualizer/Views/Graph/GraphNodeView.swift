import SwiftUI
import GradleDependencyVisualizerCore

struct GraphNodeView: View {
    let node: DependencyNode
    let fillColor: String
    let isHighlighted: Bool
    var isCollapsible: Bool = false
    var isCollapsed: Bool = false

    private var textColor: Color {
        Self.contrastingTextColor(for: fillColor)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(hex: fillColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighlighted ? Color.blue : Color.gray.opacity(0.5), lineWidth: isHighlighted ? 3 : 1)
            )
            .overlay {
                VStack(spacing: 2) {
                    Text(node.artifact)
                        .font(.caption.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(textColor)
                    Text(node.displayVersion)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(textColor)
                    if node.isOmitted {
                        Text("(omitted)")
                            .font(.caption2)
                            .foregroundStyle(textColor.opacity(0.7))
                    }
                }
                .padding(6)
            }
            .overlay(alignment: .bottomTrailing) {
                if isCollapsible {
                    Text(isCollapsed ? "\u{25B6}" : "\u{25BC}")
                        .font(.caption2)
                        .foregroundStyle(textColor)
                        .padding(4)
                }
            }
            .help("\(node.coordinate):\(node.displayVersion)\nSubtree size: \(node.subtreeSize)")
    }

    static func contrastingTextColor(for hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5 ? .black : .white
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
