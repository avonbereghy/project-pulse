import SwiftUI

struct RadarChartView: View {
    let data: [(label: String, value: Double, repoCount: Int)]

    @State private var hoveredIndex: Int? = nil

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
        Group {
            if isEmpty {
                Text("Tag your projects with domains in Settings to see your radar chart.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    let diameter = min(geo.size.width, geo.size.height)
                    let outerRadius = diameter / 2.0 * 0.65
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let labelOffset: Double = 18.0

                    ZStack {
                        // Layer 1: Grid rings
                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                            RadarGridShape(
                                spokeCount: data.count,
                                outerRadius: outerRadius,
                                ringFraction: fraction
                            )
                            .stroke(
                                Color.primary.opacity(0.06),
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 3])
                            )
                        }

                        // Layer 2: Spokes
                        RadarSpokeShape(spokeCount: data.count, outerRadius: outerRadius)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)

                        // Layer 3: Data polygon (filled)
                        RadarChartShape(values: normalizedValues, outerRadius: outerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        RadarChartShape(values: normalizedValues, outerRadius: outerRadius)
                            .stroke(Color.green, lineWidth: 1.5)

                        // Layer 4 & 5: Spoke tip dots, labels, and hover targets
                        ForEach(0..<data.count, id: \.self) { i in
                            let angle = spokeAngle(index: i, count: data.count)
                            let norm = normalizedValues[i]
                            let dotX = center.x + outerRadius * norm * cos(angle)
                            let dotY = center.y + outerRadius * norm * sin(angle)
                            let tipX = center.x + outerRadius * cos(angle)
                            let tipY = center.y + outerRadius * sin(angle)
                            let labelX = center.x + (outerRadius + labelOffset) * cos(angle)
                            let labelY = center.y + (outerRadius + labelOffset) * sin(angle)

                            // Dot at data vertex
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                                .position(x: dotX, y: dotY)

                            // Label at spoke tip (beyond outerRadius)
                            Text(data[i].label)
                                .font(.system(size: 10, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: 64)
                                .position(x: labelX, y: labelY)

                            // Hover hit target (transparent circle at spoke tip)
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 20, height: 20)
                                .contentShape(Circle())
                                .position(x: tipX, y: tipY)
                                .onHover { hovering in
                                    hoveredIndex = hovering ? i : nil
                                }

                            // Tooltip overlay when hovered
                            if hoveredIndex == i {
                                TooltipView(
                                    label: data[i].label,
                                    value: Int(data[i].value),
                                    repoCount: data[i].repoCount
                                )
                                .position(
                                    x: clamp(tipX, min: 70, max: geo.size.width - 70),
                                    y: tipY - 44
                                )
                                .zIndex(10)
                                .transition(.opacity)
                            }
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

// MARK: - Tooltip

private struct TooltipView: View {
    let label: String
    let value: Int
    let repoCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .fontWeight(.bold)
            Text("·")
                .foregroundStyle(.secondary)
            Text("\(value) commits")
                .foregroundStyle(.secondary)
            Text("·")
                .foregroundStyle(.secondary)
            Text("\(repoCount) repo\(repoCount == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
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

// MARK: - Geometry helpers (file-private, mirrors RadarChartShape.swift)

private func spokeAngle(index: Int, count: Int) -> Double {
    -(.pi / 2) + (2 * .pi / Double(count)) * Double(index)
}

private func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
    Swift.max(minVal, Swift.min(maxVal, value))
}
