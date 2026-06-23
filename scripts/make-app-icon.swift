#!/usr/bin/env swift
import AppKit
import Foundation

struct IconLayer {
    let size: CGFloat

    func draw() {
        let canvas = NSRect(x: 0, y: 0, width: size, height: size)
        NSColor.clear.setFill()
        canvas.fill()

        let shell = NSBezierPath(
            roundedRect: canvas.insetBy(dx: size * 0.055, dy: size * 0.055),
            xRadius: size * 0.225,
            yRadius: size * 0.225
        )
        NSGraphicsContext.saveGraphicsState()
        shell.addClip()

        NSGradient(colors: [
            NSColor(calibratedRed: 0.07, green: 0.16, blue: 0.13, alpha: 1),
            NSColor(calibratedRed: 0.09, green: 0.28, blue: 0.30, alpha: 1),
            NSColor(calibratedRed: 0.44, green: 0.62, blue: 0.45, alpha: 1)
        ])?.draw(in: canvas, angle: -38)

        drawSun()
        drawHills()
        drawGlassBadge()

        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.18).setStroke()
        shell.lineWidth = max(1, size * 0.006)
        shell.stroke()
    }

    private func drawSun() {
        let sunRect = NSRect(
            x: size * 0.62,
            y: size * 0.61,
            width: size * 0.23,
            height: size * 0.23
        )
        NSGradient(colors: [
            NSColor(calibratedRed: 1.0, green: 0.89, blue: 0.48, alpha: 0.95),
            NSColor(calibratedRed: 1.0, green: 0.58, blue: 0.27, alpha: 0.20)
        ])?.draw(in: NSBezierPath(ovalIn: sunRect), relativeCenterPosition: NSPoint(x: -0.12, y: 0.18))
    }

    private func drawHills() {
        let far = NSBezierPath()
        far.move(to: NSPoint(x: 0, y: size * 0.42))
        far.curve(
            to: NSPoint(x: size, y: size * 0.50),
            controlPoint1: NSPoint(x: size * 0.28, y: size * 0.62),
            controlPoint2: NSPoint(x: size * 0.66, y: size * 0.31)
        )
        far.line(to: NSPoint(x: size, y: 0))
        far.line(to: NSPoint(x: 0, y: 0))
        far.close()
        NSColor(calibratedRed: 0.18, green: 0.39, blue: 0.27, alpha: 0.94).setFill()
        far.fill()

        let near = NSBezierPath()
        near.move(to: NSPoint(x: 0, y: size * 0.24))
        near.curve(
            to: NSPoint(x: size, y: size * 0.36),
            controlPoint1: NSPoint(x: size * 0.30, y: size * 0.46),
            controlPoint2: NSPoint(x: size * 0.58, y: size * 0.18)
        )
        near.line(to: NSPoint(x: size, y: 0))
        near.line(to: NSPoint(x: 0, y: 0))
        near.close()
        NSColor(calibratedRed: 0.08, green: 0.23, blue: 0.18, alpha: 0.98).setFill()
        near.fill()
    }

    private func drawGlassBadge() {
        let badge = NSRect(
            x: size * 0.18,
            y: size * 0.19,
            width: size * 0.52,
            height: size * 0.24
        )
        let radius = size * 0.055
        let path = NSBezierPath(roundedRect: badge, xRadius: radius, yRadius: radius)

        NSColor.white.withAlphaComponent(0.16).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.34).setStroke()
        path.lineWidth = max(1, size * 0.006)
        path.stroke()

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.160, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        NSAttributedString(string: "Aa", attributes: textAttributes)
            .draw(in: NSRect(x: badge.minX + size * 0.052, y: badge.minY + size * 0.020, width: badge.width, height: badge.height))
    }
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
let fileManager = FileManager.default
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for icon in iconFiles {
    let image = NSImage(size: NSSize(width: icon.pixels, height: icon.pixels))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    IconLayer(size: CGFloat(icon.pixels)).draw()
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "RuralWallpaperIcon", code: 1)
    }

    try png.write(to: outputURL.appendingPathComponent(icon.name))
}
