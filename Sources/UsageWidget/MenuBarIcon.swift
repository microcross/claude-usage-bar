import AppKit

// MenuBarExtra flattens its label into a template image, which drops stroked
// SwiftUI Shapes entirely (they render as blank space). Drawing the donuts
// into an NSImage with Core Graphics and marking it isTemplate is the same
// path native status icons use, so it renders reliably and adapts to
// light/dark menu bars.
enum MenuBarIcon {
    static func image(session: Double?, weekly: Double?) -> NSImage {
        let height: CGFloat = 18
        let ringDiameter: CGFloat = 16
        let spacing: CGFloat = 5
        let width = ringDiameter * 2 + spacing + 2
        let size = NSSize(width: width, height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            let y = (height - ringDiameter) / 2
            drawRing(in: CGRect(x: 1, y: y, width: ringDiameter, height: ringDiameter),
                     percent: session, letter: "S")
            drawRing(in: CGRect(x: 1 + ringDiameter + spacing, y: y, width: ringDiameter, height: ringDiameter),
                     percent: weekly, letter: "W")
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawRing(in rect: CGRect, percent: Double?, letter: String) {
        let lineWidth: CGFloat = 2.5
        let inset = lineWidth / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2 - inset

        // Track: faint full circle so an empty ring is still visible.
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor.black.withAlphaComponent(0.3).setStroke()
        track.stroke()

        if let percent {
            let clamped = min(max(percent, 0), 100)
            if clamped > 0 {
                // NSBezierPath angles are counterclockwise from 3 o'clock;
                // start at 12 o'clock (90°) and sweep clockwise with usage.
                let fill = NSBezierPath()
                fill.appendArc(withCenter: center, radius: radius,
                               startAngle: 90, endAngle: 90 - clamped / 100 * 360,
                               clockwise: true)
                fill.lineWidth = lineWidth
                fill.lineCapStyle = .round
                NSColor.black.setStroke()
                fill.stroke()
            }
        }

        let font = NSFont.systemFont(ofSize: 7.5, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black.withAlphaComponent(percent == nil ? 0.4 : 0.9)
        ]
        let text = NSAttributedString(string: letter, attributes: attrs)
        let textSize = text.size()
        text.draw(at: CGPoint(x: center.x - textSize.width / 2,
                              y: center.y - textSize.height / 2))
    }
}
