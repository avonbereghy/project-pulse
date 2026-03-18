import SwiftUI

// Shared math helper used by both shapes
// angles: equally spaced starting from top (−π/2), clockwise
// values: normalized [0.0 ... 1.0] per spoke

struct RadarChartShape: Shape {
    let values: [Double]      // normalized 0–1, one per spoke
    let outerRadius: Double   // distance from center to outer ring

    func path(in rect: CGRect) -> Path {
        guard values.count >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        let points = spokePoints(values: values, radius: outerRadius, center: center)
        path.move(to: points[0])
        for pt in points.dropFirst() { path.addLine(to: pt) }
        path.closeSubpath()
        return path
    }
}

struct RadarGridShape: Shape {
    let spokeCount: Int
    let outerRadius: Double
    let ringFraction: Double  // e.g. 0.25, 0.5, 0.75, 1.0

    func path(in rect: CGRect) -> Path {
        guard spokeCount >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = outerRadius * ringFraction
        let values = Array(repeating: 1.0, count: spokeCount)
        var path = Path()
        let points = spokePoints(values: values, radius: r, center: center)
        path.move(to: points[0])
        for pt in points.dropFirst() { path.addLine(to: pt) }
        path.closeSubpath()
        return path
    }
}

struct RadarSpokeShape: Shape {
    let spokeCount: Int
    let outerRadius: Double

    func path(in rect: CGRect) -> Path {
        guard spokeCount >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for i in 0..<spokeCount {
            let angle = spokeAngle(index: i, count: spokeCount)
            let end = CGPoint(
                x: center.x + outerRadius * cos(angle),
                y: center.y + outerRadius * sin(angle)
            )
            path.move(to: center)
            path.addLine(to: end)
        }
        return path
    }
}

// MARK: - Shared geometry helpers

private func spokeAngle(index: Int, count: Int) -> Double {
    // Start at top (−π/2), go clockwise
    return -(.pi / 2) + (2 * .pi / Double(count)) * Double(index)
}

private func spokePoints(values: [Double], radius: Double, center: CGPoint) -> [CGPoint] {
    values.enumerated().map { i, v in
        let angle = spokeAngle(index: i, count: values.count)
        return CGPoint(
            x: center.x + radius * v * cos(angle),
            y: center.y + radius * v * sin(angle)
        )
    }
}
