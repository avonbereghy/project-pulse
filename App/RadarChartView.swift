import SwiftUI

struct RadarChartView: View {
    let data: [(label: String, value: Double, repoCount: Int)]

    @State private var hoveredIndex: Int? = nil

    static let domainColors: [String: Color] = [
        "NLP":                    .blue,
        "Computer Vision":        .cyan,
        "Reinforcement Learning": .orange,
        "Audio":                  .purple,
        "Generative AI":          .pink,
        "Data Engineering":       .yellow,
        "Robotics":               .red,
        "App Dev":                .green,
        "Systems":                .mint,
        "Web Dev":                .teal
    ]

    func color(for label: String) -> Color {
        Self.domainColors[label] ?? .gray
    }

    private var isEmpty: Bool {
        data.isEmpty || data.allSatisfy { $0.value == 0 }
    }

    private var maxValue: Double {
        data.map(\.value).max() ?? 1.0
    }

    private var normalizedValues: [Double] {
        let mv = maxValue > 0 ? maxValue : 1.0
        return data.map { $0.value / mv }
    }

    var body: some View {
        if isEmpty {
            Text("Tag your projects with domains in Settings to see your radar chart.")
                .foregroundStyle(.secondary)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                GeometryReader { geo in
                    let diameter = min(geo.size.width, geo.size.height)
                    let outerRadius = diameter / 2.0 * 0.62
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    RadarChartCanvas(
                        data: data,
                        normalizedValues: normalizedValues,
                        outerRadius: outerRadius,
                        center: center,
                        hoveredIndex: $hoveredIndex,
                        colorFor: color(for:)
                    )
                }
                .aspectRatio(1, contentMode: .fit)

                legendView
                    .padding(.horizontal, 4)
            }
        }
    }

    private var legendView: some View {
        let sorted = data.sorted { $0.value > $1.value }
        return FlowLayout(spacing: 6) {
            ForEach(sorted, id: \.label) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(color(for: item.label))
                        .frame(width: 6, height: 6)
                    Text(item.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    Text("\(Int(item.value))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(color(for: item.label).opacity(0.1)))
            }
        }
    }
}

// MARK: - Canvas (extracted to help type-checker)

private struct RadarChartCanvas: View {
    let data: [(label: String, value: Double, repoCount: Int)]
    let normalizedValues: [Double]
    let outerRadius: Double
    let center: CGPoint
    @Binding var hoveredIndex: Int?
    let colorFor: (String) -> Color

    private let labelOffset: Double = 20.0

    var body: some View {
        ZStack {
            gridLayer
            spokesLayer
            slicesLayer
            outlineLayer
            dotsAndLabelsLayer
        }
    }

    // Grid rings
    private var gridLayer: some View {
        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
            RadarGridShape(spokeCount: data.count, outerRadius: outerRadius, ringFraction: fraction)
                .stroke(Color.primary.opacity(0.06), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        }
    }

    // Colored spokes
    private var spokesLayer: some View {
        ForEach(0..<data.count, id: \.self) { i in
            let angle = spokeAngle(index: i, count: data.count)
            Path { path in
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + outerRadius * cos(angle),
                    y: center.y + outerRadius * sin(angle)
                ))
            }
            .stroke(colorFor(data[i].label).opacity(0.2), lineWidth: 1)
        }
    }

    // Colored triangular slices
    private var slicesLayer: some View {
        ForEach(0..<data.count, id: \.self) { i in
            slicePath(index: i)
                .fill(colorFor(data[i].label).opacity(0.28))
        }
    }

    private func slicePath(index i: Int) -> Path {
        let j = (i + 1) % data.count
        let a1 = spokeAngle(index: i, count: data.count)
        let a2 = spokeAngle(index: j, count: data.count)
        let n1 = normalizedValues[i]
        let n2 = normalizedValues[j]
        return Path { path in
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + outerRadius * n1 * cos(a1),
                                     y: center.y + outerRadius * n1 * sin(a1)))
            path.addLine(to: CGPoint(x: center.x + outerRadius * n2 * cos(a2),
                                     y: center.y + outerRadius * n2 * sin(a2)))
            path.closeSubpath()
        }
    }

    // Polygon outline
    private var outlineLayer: some View {
        RadarChartShape(values: normalizedValues, outerRadius: outerRadius)
            .stroke(Color.primary.opacity(0.25), lineWidth: 1)
    }

    // Dots, labels, hover
    private var dotsAndLabelsLayer: some View {
        ForEach(0..<data.count, id: \.self) { i in
            let angle = spokeAngle(index: i, count: data.count)
            let norm = normalizedValues[i]
            let dotX = center.x + outerRadius * norm * cos(angle)
            let dotY = center.y + outerRadius * norm * sin(angle)
            let tipX = center.x + outerRadius * cos(angle)
            let tipY = center.y + outerRadius * sin(angle)
            let labelX = center.x + (outerRadius + labelOffset) * cos(angle)
            let labelY = center.y + (outerRadius + labelOffset) * sin(angle)
            let col = colorFor(data[i].label)

            ZStack {
                Circle()
                    .fill(col)
                    .frame(width: 6, height: 6)
                    .position(x: dotX, y: dotY)

                Text(data[i].label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(col)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 68)
                    .position(x: labelX, y: labelY)

                Circle()
                    .fill(Color.clear)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                    .position(x: tipX, y: tipY)
                    .onHover { hovering in hoveredIndex = hovering ? i : nil }

                if hoveredIndex == i {
                    TooltipView(label: data[i].label, value: Int(data[i].value),
                                repoCount: data[i].repoCount, accent: col)
                        .position(
                            x: clamp(tipX, min: 80, max: 1000),
                            y: clamp(tipY - 44, min: 24, max: 1000)
                        )
                        .zIndex(10)
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Tooltip

private struct TooltipView: View {
    let label: String
    let value: Int
    let repoCount: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(accent).frame(width: 7, height: 7)
            Text(label).fontWeight(.semibold)
            Text("·").foregroundStyle(.secondary)
            Text("\(value) commits").foregroundStyle(.secondary)
            Text("·").foregroundStyle(.secondary)
            Text("\(repoCount) repo\(repoCount == 1 ? "" : "s")").foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Geometry helpers

private func spokeAngle(index: Int, count: Int) -> Double {
    -(.pi / 2) + (2 * .pi / Double(count)) * Double(index)
}

private func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
    Swift.max(minVal, Swift.min(maxVal, value))
}
