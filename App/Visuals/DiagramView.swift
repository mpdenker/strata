import SwiftUI
import LessonKit

/// Nodes and arrows. Nodes are laid out by SwiftUI (row / column / grid / cycle / free); each node reports
/// its frame through an anchor preference, and the edges are drawn behind them between those frames.
struct DiagramView: View {
    let diagram: Diagram
    let shown: Int

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility text sizes, side-by-side layouts become a single column so labels stay readable.
    private var layout: DiagramLayout {
        if typeSize.isAccessibilitySize, diagram.layout != .free { return .column }
        return diagram.layout
    }

    var body: some View {
        nodes
            .backgroundPreferenceValue(NodeFramesKey.self) { anchors in
                GeometryReader { proxy in
                    ForEach(Array((diagram.edges ?? []).enumerated()), id: \.offset) { _, edge in
                        if let a = anchors[edge.from], let b = anchors[edge.to] {
                            EdgeView(edge: edge, from: proxy[a], to: proxy[b], visible: (edge.step ?? 1) <= shown)
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private var nodes: some View {
        switch layout {
        case .row:
            HStack(alignment: .center, spacing: 28) {
                ForEach(diagram.nodes) { node($0).frame(maxWidth: .infinity) }
            }
        case .column:
            VStack(spacing: 36) {
                ForEach(diagram.nodes) { node($0).frame(maxWidth: 280) }
            }
            .frame(maxWidth: .infinity)
        case .grid:
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)], spacing: 32) {
                ForEach(diagram.nodes) { node($0) }
            }
        case .cycle:
            GeometryReader { geo in
                let size = geo.size
                let radius = min(size.width, size.height) * 0.36
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                ForEach(Array(diagram.nodes.enumerated()), id: \.element.id) { i, n in
                    let angle = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(max(1, diagram.nodes.count))
                    node(n)
                        .frame(width: size.width * 0.34)
                        .position(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                }
            }
            .aspectRatio(1, contentMode: .fit)
        case .free:
            GeometryReader { geo in
                ForEach(diagram.nodes) { n in
                    node(n)
                        .frame(width: geo.size.width * 0.3)
                        .position(x: (n.x ?? 0.5) * geo.size.width, y: (n.y ?? 0.5) * geo.size.height)
                }
            }
            .aspectRatio(diagram.aspectRatio ?? 1.4, contentMode: .fit)
        }
    }

    private func node(_ n: DiagramNode) -> some View {
        DiagramNodeView(node: n, visible: (n.step ?? 1) <= shown)
            .anchorPreference(key: NodeFramesKey.self, value: .bounds) { [n.id: $0] }
    }
}

private struct NodeFramesKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

struct DiagramNodeView: View {
    let node: DiagramNode
    let visible: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        let style = node.style ?? .filled
        VStack(spacing: 4) {
            if let symbol = node.symbol {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(style == .muted ? Color.inkMuted : theme.topicInk)
            }
            md(node.label)
                .font(.label)
                .multilineTextAlignment(.center)
                .foregroundStyle(style == .muted ? Color.inkMuted : Color.ink)
            if let detail = node.detail {
                md(detail)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            switch style {
            case .filled: shape.fill(theme.topicSoft).overlay(shape.strokeBorder(theme.topic, lineWidth: Metrics.stroke))
            case .outline: shape.fill(Color.card).overlay(shape.strokeBorder(Color.ink, lineWidth: Metrics.stroke))
            case .muted: shape.fill(Color.card).overlay(shape.strokeBorder(Color.rule, style: StrokeStyle(lineWidth: Metrics.stroke, dash: [4, 3])))
            }
        }
        .scaleEffect(visible ? 1 : 0.85)
        .opacity(visible ? 1 : 0)
    }
}

/// A line (optionally dashed, optionally with an arrowhead) between the edges of two node frames.
struct EdgeView: View {
    let edge: DiagramEdge
    let from: CGRect
    let to: CGRect
    let visible: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        let start = exitPoint(of: from, toward: CGPoint(x: to.midX, y: to.midY), gap: 4)
        let end = exitPoint(of: to, toward: CGPoint(x: from.midX, y: from.midY), gap: 6)
        let style = edge.style ?? .arrow
        ZStack {
            ArrowShape(start: start, end: end, head: style == .arrow)
                .trim(from: 0, to: visible ? 1 : 0)
                .stroke(Color.ink, style: StrokeStyle(lineWidth: Metrics.stroke, lineCap: .round, lineJoin: .round,
                                                      dash: style == .dashed ? [6, 5] : []))
            if let label = edge.label {
                md(label)
                    .font(.caption2Strong)
                    .foregroundStyle(theme.topicInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.card))
                    .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                    .opacity(visible ? 1 : 0)
            }
        }
    }
}

/// Where a line from the rect's center toward `point` leaves the rect (plus a small gap).
func exitPoint(of rect: CGRect, toward point: CGPoint, gap: CGFloat) -> CGPoint {
    let c = CGPoint(x: rect.midX, y: rect.midY)
    let dx = point.x - c.x, dy = point.y - c.y
    guard dx != 0 || dy != 0 else { return c }
    let sx = dx == 0 ? CGFloat.infinity : (rect.width / 2 + gap) / abs(dx)
    let sy = dy == 0 ? CGFloat.infinity : (rect.height / 2 + gap) / abs(dy)
    let s = min(sx, sy, 1)
    return CGPoint(x: c.x + dx * s, y: c.y + dy * s)
}

/// A straight line with an optional open arrowhead, drawn as one path so `trim` animates it.
struct ArrowShape: Shape {
    var start: CGPoint
    var end: CGPoint
    var head: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        if head {
            let angle = atan2(end.y - start.y, end.x - start.x)
            let len: CGFloat = 10, spread: CGFloat = .pi / 7
            p.move(to: CGPoint(x: end.x - len * cos(angle - spread), y: end.y - len * sin(angle - spread)))
            p.addLine(to: end)
            p.addLine(to: CGPoint(x: end.x - len * cos(angle + spread), y: end.y - len * sin(angle + spread)))
        }
        return p
    }
}
