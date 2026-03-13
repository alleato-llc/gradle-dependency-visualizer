import SwiftUI

struct GraphEdgeView: View {
    let from: CGPoint
    let to: CGPoint
    var edgeColor: Color = Color.gray.opacity(0.5)

    var body: some View {
        Path { path in
            path.move(to: from)

            let controlY = (from.y + to.y) / 2
            path.addCurve(
                to: to,
                control1: CGPoint(x: from.x, y: controlY),
                control2: CGPoint(x: to.x, y: controlY)
            )
        }
        .stroke(edgeColor, lineWidth: 1)
    }
}
