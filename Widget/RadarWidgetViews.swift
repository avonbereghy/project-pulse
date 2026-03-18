import WidgetKit
import SwiftUI

// MARK: - Polygon Math Helpers

private func radarPoint(index: Int, count: Int, value: Double, radius: Double, center: CGPoint) -> CGPoint {
    let angle = -(.pi / 2) + (2 * .pi / Double(count)) * Double(index)
    return CGPoint(
        x: center.x + radius * value * cos(angle),
        y: center.y + radius * value * sin(angle)
    )
}

private func normalizedValues(_ values: [Double]) -> [Double] {
    guard let max = values.max(), max > 0 else { return values.map { _ in 0 } }
    return values.map { $0 / max }
}

// MARK: - Shared Polygon Path Builder

private func radarPath(values: [Double], radius: Double, center: CGPoint) -> Path {
    guard values.count >= 3 else { return Path() }
    var path = Path()
    let pts = values.enumerated().map { i, v in radarPoint(index: i, count: values.count, value: v, radius: radius, center: center) }
    path.move(to: pts[0])
    for pt in pts.dropFirst() { path.addLine(to: pt) }
    path.closeSubpath()
    return path
}

// MARK: - Spoke path helper

private func spokePath(index: Int, count: Int, outerRadius: Double, center: CGPoint) -> Path {
    let tip = radarPoint(index: index, count: count, value: 1.0, radius: outerRadius, center: center)
    var path = Path()
    path.move(to: center)
    path.addLine(to: tip)
    return path
}

// MARK: - Label position helper

private struct RadarSpokeLabel: Identifiable {
    let id: Int
    let label: String
    let value: Double
    let x: Double
    let y: Double
}

private func spokeLabels(data: [(label: String, value: Double)], outerRadius: Double, center: CGPoint, labelOffset: Double = 12) -> [RadarSpokeLabel] {
    let count = data.count
    let r = outerRadius + labelOffset
    var result: [RadarSpokeLabel] = []
    for (i, item) in data.enumerated() {
        let angle = -(.pi / 2) + (2 * .pi / Double(count)) * Double(i)
        result.append(RadarSpokeLabel(
            id: i,
            label: item.label,
            value: item.value,
            x: center.x + r * cos(angle),
            y: center.y + r * sin(angle)
        ))
    }
    return result
}

// MARK: - Medium Radar Widget View

struct RadarWidgetMediumView: View {
    let data: [(label: String, value: Double)]

    private var isEmpty: Bool {
        data.isEmpty || data.allSatisfy { $0.value == 0 }
    }

    var body: some View {
        Group {
            if isEmpty {
                Text("No domain data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    RadarMediumCanvas(data: data, size: geo.size)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

private struct RadarMediumCanvas: View {
    let data: [(label: String, value: Double)]
    let size: CGSize

    private var outerRadius: Double { Double(min(size.width, size.height)) * 0.28 }
    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
    private var count: Int { data.count }
    private var norm: [Double] { normalizedValues(data.map { $0.value }) }
    private var labels: [RadarSpokeLabel] { spokeLabels(data: data, outerRadius: outerRadius, center: center) }

    var body: some View {
        ZStack {
            gridRings
            spokes
            filledPolygon
            spokeLabelViews
        }
    }

    private var gridRings: some View {
        let ones = Array(repeating: 1.0, count: count)
        return ZStack {
            radarPath(values: ones, radius: outerRadius * 0.5, center: center)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            radarPath(values: ones, radius: outerRadius, center: center)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var spokes: some View {
        ForEach(0..<count, id: \.self) { i in
            spokePath(index: i, count: count, outerRadius: outerRadius, center: center)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
    }

    private var filledPolygon: some View {
        ZStack {
            radarPath(values: norm, radius: outerRadius, center: center)
                .fill(Color.green.opacity(0.25))
            radarPath(values: norm, radius: outerRadius, center: center)
                .stroke(Color.green, lineWidth: 1)
        }
    }

    private var spokeLabelViews: some View {
        ForEach(labels) { item in
            Text(item.label)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .position(x: item.x, y: item.y)
        }
    }
}

// MARK: - Large Radar Widget View

struct RadarWidgetLargeView: View {
    let data: [(label: String, value: Double)]

    private var isEmpty: Bool {
        data.isEmpty || data.allSatisfy { $0.value == 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "scope")
                    .foregroundStyle(.green)
                Text("Domain Focus")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(data.count) domains")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isEmpty {
                Spacer()
                Text("Tag projects in ProjectPulse\nto see domain focus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else {
                GeometryReader { geo in
                    RadarLargeCanvas(data: data, size: geo.size)
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

private struct RadarLargeCanvas: View {
    let data: [(label: String, value: Double)]
    let size: CGSize

    private var outerRadius: Double { Double(min(size.width, size.height)) * 0.32 }
    private var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
    private var count: Int { data.count }
    private var norm: [Double] { normalizedValues(data.map { $0.value }) }
    private var labels: [RadarSpokeLabel] { spokeLabels(data: data, outerRadius: outerRadius, center: center) }

    var body: some View {
        ZStack {
            gridRings
            spokes
            filledPolygon
            spokeLabelViews
        }
    }

    private var gridRings: some View {
        let ones = Array(repeating: 1.0, count: count)
        return ZStack {
            radarPath(values: ones, radius: outerRadius * 0.5, center: center)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            radarPath(values: ones, radius: outerRadius, center: center)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private var spokes: some View {
        ForEach(0..<count, id: \.self) { i in
            spokePath(index: i, count: count, outerRadius: outerRadius, center: center)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
    }

    private var filledPolygon: some View {
        ZStack {
            radarPath(values: norm, radius: outerRadius, center: center)
                .fill(Color.green.opacity(0.25))
            radarPath(values: norm, radius: outerRadius, center: center)
                .stroke(Color.green, lineWidth: 1)
        }
    }

    private var spokeLabelViews: some View {
        ForEach(labels) { item in
            VStack(spacing: 1) {
                Text(item.label)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(Int(item.value))")
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }
            .position(x: item.x, y: item.y)
        }
    }
}
