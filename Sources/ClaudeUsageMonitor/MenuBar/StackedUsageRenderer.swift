import AppKit

/// Renders the ring plus a two-line "percent over reset time" title as a single composited
/// image. `NSStatusBarButton` centers a plain `image` as one block reliably; asking it to
/// vertically center a two-line `attributedTitle` next to a separately-centered image doesn't
/// line up the same way, so this bakes both into pixels we position ourselves.
enum StackedUsageRenderer {
    private static let ringSize: CGFloat = 15
    private static let ringLineWidth: CGFloat = 2.4
    private static let verticalPadding: CGFloat = 2
    private static let topFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    private static let bottomFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)
    private static let lineGap: CGFloat = 0
    private static let ringToTextGap: CGFloat = 4

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static func image(percent: Double, resetsAt: Date?, showRing: Bool) -> NSImage {
        let topText = "\(Int(percent.rounded()))%"
        let bottomText = resetsAt.map { shortTimeFormatter.string(from: $0) } ?? "—"

        let topAttrs: [NSAttributedString.Key: Any] = [.font: topFont, .foregroundColor: NSColor.white]
        let bottomAttrs: [NSAttributedString.Key: Any] = [
            .font: bottomFont, .foregroundColor: NSColor(white: 0.75, alpha: 1.0),
        ]
        let topSize = topText.size(withAttributes: topAttrs)
        let bottomSize = bottomText.size(withAttributes: bottomAttrs)
        let textWidth = max(topSize.width, bottomSize.width)
        let ringWidth = showRing ? ringSize + ringToTextGap : 0
        let width = 1 + ringWidth + textWidth + 1

        // Size the canvas to the text actually measured, not a guessed constant — a fixed
        // height shorter than the real two-line block clips the bottom line against the
        // image's own bounds instead of just leaving less padding.
        let blockHeight = topSize.height + lineGap + bottomSize.height
        let height = max(ringSize, blockHeight) + verticalPadding

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            if showRing {
                let ringRect = NSRect(x: 1, y: (height - ringSize) / 2, width: ringSize, height: ringSize)
                UsageRingRenderer.drawRing(in: ringRect, percent: percent, lineWidth: ringLineWidth)
            }

            // Non-flipped context: a point passed to `draw(at:)` is the bottom-left of that
            // line's bounding box, so stack bottom-up — place the bottom line first, then the
            // top line directly above it — and center the two-line block in `rect`.
            let blockBottom = (rect.height - blockHeight) / 2
            let textX = 1 + ringWidth

            bottomText.draw(
                at: NSPoint(x: textX + (textWidth - bottomSize.width) / 2, y: blockBottom),
                withAttributes: bottomAttrs)
            topText.draw(
                at: NSPoint(
                    x: textX + (textWidth - topSize.width) / 2, y: blockBottom + bottomSize.height + lineGap),
                withAttributes: topAttrs)

            return true
        }
        image.isTemplate = false
        return image
    }
}
