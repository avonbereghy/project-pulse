#!/usr/bin/env swift

import AppKit
import CoreGraphics

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Background: fill entire canvas, let macOS apply its own icon mask
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors: [CGColor] = [
        CGColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0),
        CGColor(red: 0.12, green: 0.10, blue: 0.22, alpha: 1.0),
    ]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    }

    // Draw contribution grid (mini heatmap)
    let gridCols = 7
    let gridRows = 5
    let padding = s * 0.15
    let gridWidth = s - padding * 2
    let gridHeight = s * 0.45
    let gridY = s * 0.42
    let cellW = (gridWidth - CGFloat(gridCols - 1) * (s * 0.02)) / CGFloat(gridCols)
    let cellH = (gridHeight - CGFloat(gridRows - 1) * (s * 0.02)) / CGFloat(gridRows)
    let cellGap = s * 0.02
    let cellRadius = s * 0.015

    // Simulated commit data
    let data: [[Double]] = [
        [0.0, 0.1, 0.0, 0.2, 0.0, 0.1, 0.0],
        [0.1, 0.3, 0.2, 0.4, 0.1, 0.3, 0.1],
        [0.2, 0.5, 0.7, 0.6, 0.3, 0.5, 0.2],
        [0.3, 0.8, 0.9, 1.0, 0.7, 0.8, 0.4],
        [0.1, 0.6, 0.8, 0.9, 0.5, 0.7, 0.3],
    ]

    for row in 0..<gridRows {
        for col in 0..<gridCols {
            let x = padding + CGFloat(col) * (cellW + cellGap)
            let y = gridY + CGFloat(gridRows - 1 - row) * (cellH + cellGap)
            let intensity = data[row][col]

            let green: CGFloat
            let alpha: CGFloat
            if intensity == 0 {
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
            } else {
                green = 0.55 + intensity * 0.45
                alpha = 0.3 + intensity * 0.7
                ctx.setFillColor(CGColor(red: 0.1 * (1 - intensity), green: green, blue: 0.2 * (1 - intensity), alpha: alpha))
            }

            let cellRect = CGRect(x: x, y: y, width: cellW, height: cellH)
            let cellPath = CGPath(roundedRect: cellRect, cornerWidth: cellRadius, cornerHeight: cellRadius, transform: nil)
            ctx.addPath(cellPath)
            ctx.fillPath()
        }
    }

    // Draw pulse line on top
    let lineY = s * 0.78
    let lineHeight = s * 0.12
    let points: [(CGFloat, CGFloat)] = [
        (0.12, 0.0), (0.25, 0.1), (0.32, -0.05),
        (0.40, 0.3), (0.45, 0.8), (0.50, 1.0),
        (0.55, 0.6), (0.60, -0.2), (0.65, 0.15),
        (0.72, 0.4), (0.78, 0.7), (0.82, 0.3),
        (0.88, 0.1),
    ]

    let linePath = CGMutablePath()
    for (i, pt) in points.enumerated() {
        let x = pt.0 * s
        let y = lineY + pt.1 * lineHeight
        if i == 0 {
            linePath.move(to: CGPoint(x: x, y: y))
        } else {
            linePath.addLine(to: CGPoint(x: x, y: y))
        }
    }

    // Glow effect
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.03, color: CGColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 0.8))
    ctx.setStrokeColor(CGColor(red: 0.3, green: 0.95, blue: 0.5, alpha: 1.0))
    ctx.setLineWidth(s * 0.025)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(linePath)
    ctx.strokePath()
    ctx.restoreGState()

    // Brighter line on top
    ctx.setStrokeColor(CGColor(red: 0.4, green: 1.0, blue: 0.6, alpha: 1.0))
    ctx.setLineWidth(s * 0.015)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(linePath)
    ctx.strokePath()

    img.unlockFocus()
    return img
}

func createIconset() {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("ProjectPulse.iconset")
    try? FileManager.default.removeItem(at: tmpDir)
    try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

    let sizes: [(String, Int)] = [
        ("icon_16x16", 16),
        ("icon_16x16@2x", 32),
        ("icon_32x32", 32),
        ("icon_32x32@2x", 64),
        ("icon_128x128", 128),
        ("icon_128x128@2x", 256),
        ("icon_256x256", 256),
        ("icon_256x256@2x", 512),
        ("icon_512x512", 512),
        ("icon_512x512@2x", 1024),
    ]

    for (name, size) in sizes {
        let img = generateIcon(size: size)
        let tiff = img.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: tiff)!
        let png = bitmap.representation(using: .png, properties: [:])!
        let path = tmpDir.appendingPathComponent("\(name).png")
        try! png.write(to: path)
    }

    let outputPath = FileManager.default.currentDirectoryPath + "/AppIcon.icns"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", tmpDir.path, "-o", outputPath]
    try! process.run()
    process.waitUntilExit()

    try? FileManager.default.removeItem(at: tmpDir)
    print("Generated \(outputPath)")
}

createIconset()
