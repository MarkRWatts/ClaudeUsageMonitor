import AppKit

/// Draws the menu bar icon: a hollow circle, grey track, filled white clockwise from 12 o'clock.
enum UsageRingRenderer {
    static let size: CGFloat = 18
    private static let lineWidth: CGFloat = 3.6
    private static let trackColor = NSColor(white: 0.55, alpha: 1.0)

    static func image(percent: Double) -> NSImage {
        let fraction = min(max(percent, 0), 100) / 100

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let radius = (min(rect.width, rect.height) - lineWidth) / 2
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let trackRect = NSRect(
                x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

            let track = NSBezierPath(ovalIn: trackRect)
            track.lineWidth = lineWidth
            trackColor.setStroke()
            track.stroke()

            if fraction > 0 {
                // AppKit's non-flipped coordinate space has 0deg at 3 o'clock, increasing
                // counterclockwise. 12 o'clock is 90deg; a clockwise sweep from there means
                // the angle decreases toward 90 - fraction*360.
                let startAngle: CGFloat = 90
                let endAngle: CGFloat = 90 - CGFloat(fraction) * 360
                let progress = NSBezierPath()
                progress.appendArc(
                    withCenter: center, radius: radius, startAngle: startAngle,
                    endAngle: endAngle, clockwise: true)
                progress.lineWidth = lineWidth
                progress.lineCapStyle = .round
                NSColor.white.setStroke()
                progress.stroke()
            }

            return true
        }
        image.isTemplate = false
        return image
    }
}
