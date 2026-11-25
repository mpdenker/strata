import SwiftUI
import LessonKit

/// Free-form drawing on a 0…1 canvas: rectangles, circles, polygons (maps-as-shapes), lines/arrows,
/// text and SF Symbols. Parts appear in `step` order; lines draw themselves.
struct ShapesView: View {
    let visual: ShapesVisual
    let shown: Int

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                ForEach(Array(visual.items.enumerated()), id: \.offset) { _, item in
                    ShapeItemView(item: item, canvas: size, visible: (item.step ?? 1) <= shown)
                }
            }
        }
        .aspectRatio(visual.aspectRatio, contentMode: .fit)
    }
}

private struct ShapeItemView: View {
    let item: ShapeItem
    let canvas: CGSize
    let visible: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        let W = canvas.width, H = canvas.height
        let fill = theme.color(item.fill ?? defaultFill)
        let stroke = theme.color(item.stroke ?? defaultStroke)
        let strokeStyle = StrokeStyle(lineWidth: Metrics.stroke, lineCap: .round, lineJoin: .round,
                                      dash: item.dashed == true ? [6, 5] : [])

        switch item.shape {
        case .rect:
            let w = (item.w ?? 0.2) * W, h = (item.h ?? 0.2) * H
            let shape = RoundedRectangle(cornerRadius: (item.corner ?? 0.03) * W, style: .continuous)
            shape.fill(fill)
                .overlay(shape.stroke(stroke, style: strokeStyle))
                .frame(width: w, height: h)
                .position(x: (item.x ?? 0) * W + w / 2, y: (item.y ?? 0) * H + h / 2)
                .scaleEffect(visible ? 1 : 0.9)
                .opacity(visible ? 1 : 0)

        case .circle:
            let d = 2 * (item.r ?? 0.05) * W
            Circle().fill(fill)
                .overlay(Circle().stroke(stroke, style: strokeStyle))
                .frame(width: d, height: d)
                .position(x: (item.x ?? 0.5) * W, y: (item.y ?? 0.5) * H)
                .scaleEffect(visible ? 1 : 0.6)
                .opacity(visible ? 1 : 0)

        case .polygon:
            let poly = NormalizedPath(points: item.points ?? [], closed: true, arrow: false)
            poly.fill(fill)
                .overlay(poly.stroke(stroke, style: strokeStyle))
                .frame(width: W, height: H)
                .opacity(visible ? 1 : 0)

        case .line:
            NormalizedPath(points: item.points ?? [], closed: false, arrow: item.arrow == true)
                .trim(from: 0, to: visible ? 1 : 0)
                .stroke(stroke, style: strokeStyle)
                .frame(width: W, height: H)

        case .text:
            md(item.text ?? "")
                .font(font(item.textSize ?? .caption))
                .foregroundStyle(item.fill.map(theme.color) ?? Color.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: W * 0.45)
                .fixedSize(horizontal: false, vertical: true)
                .position(x: (item.x ?? 0.5) * W, y: (item.y ?? 0.5) * H)
                .opacity(visible ? 1 : 0)

        case .symbol:
            Image(systemName: item.name ?? "questionmark")
                .font(.system(size: max(12, (item.size ?? 0.1) * W)))
                .foregroundStyle(item.fill.map(theme.color) ?? theme.topic)
                .position(x: (item.x ?? 0.5) * W, y: (item.y ?? 0.5) * H)
                .scaleEffect(visible ? 1 : 0.5)
                .opacity(visible ? 1 : 0)
        }
    }

    private var defaultFill: ColorToken {
        switch item.shape {
        case .rect, .circle, .polygon: .topicSoft
        case .line, .text: .ink
        case .symbol: .topic
        }
    }

    private var defaultStroke: ColorToken {
        switch item.shape {
        case .polygon, .rect, .circle: .topic
        default: .ink
        }
    }

    private func font(_ size: TextSize) -> Font {
        switch size {
        case .caption: .caption.weight(.medium)
        case .body: .callout
        case .headline: .headline
        case .title: .displaySmall
        }
    }
}

/// A polyline/polygon whose points are fractions of the frame it's drawn in.
struct NormalizedPath: Shape {
    var points: [[Double]]
    var closed: Bool
    var arrow: Bool

    func path(in rect: CGRect) -> Path {
        let pts = points.compactMap { p -> CGPoint? in
            guard p.count == 2 else { return nil }
            return CGPoint(x: rect.minX + p[0] * rect.width, y: rect.minY + p[1] * rect.height)
        }
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        pts.dropFirst().forEach { path.addLine(to: $0) }
        if closed { path.closeSubpath() }
        if arrow, pts.count >= 2 {
            let end = pts[pts.count - 1], prev = pts[pts.count - 2]
            let angle = atan2(end.y - prev.y, end.x - prev.x)
            let len: CGFloat = 10, spread: CGFloat = .pi / 7
            path.move(to: CGPoint(x: end.x - len * cos(angle - spread), y: end.y - len * sin(angle - spread)))
            path.addLine(to: end)
            path.addLine(to: CGPoint(x: end.x - len * cos(angle + spread), y: end.y - len * sin(angle + spread)))
        }
        return path
    }
}
