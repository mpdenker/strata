import SwiftUI
import LessonKit

// MARK: - Comparison (A vs B, or 3 columns)

struct ComparisonView: View {
    let comparison: Comparison
    let sectionID: String
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(text: comparison.heading)
            Staged(id: sectionID + ".rows", total: comparison.rows.count + 1) { shown in
                if typeSize.isAccessibilitySize {
                    stacked(shown)
                } else {
                    grid(shown)
                }
            }
            if let takeaway = comparison.takeaway {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(theme.topicInk).accessibilityHidden(true)
                    md(takeaway).font(.body.weight(.medium)).foregroundStyle(Color.ink)
                }
            }
        }
    }

    /// Normal sizes: a table with the row labels on the left.
    private func grid(_ shown: Int) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(Array(comparison.columns.enumerated()), id: \.offset) { i, col in
                    columnHeader(col, index: i)
                }
            }
            .appears(shown >= 1)
            ForEach(Array(comparison.rows.enumerated()), id: \.offset) { r, row in
                Divider().overlay(Color.rule).gridCellColumns(comparison.columns.count + 1)
                    .appears(shown >= r + 2)
                GridRow(alignment: .firstTextBaseline) {
                    md(row.label).font(.caption2Strong).foregroundStyle(Color.inkMuted).textCase(.uppercase)
                    ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                        md(value).font(.callout).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 10)
                .appears(shown >= r + 2)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Color.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).strokeBorder(Color.rule))
    }

    /// Accessibility sizes: one card per row, each column's value labeled.
    private func stacked(_ shown: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(comparison.rows.enumerated()), id: \.offset) { r, row in
                VStack(alignment: .leading, spacing: 8) {
                    md(row.label).font(.headline).foregroundStyle(Color.ink)
                    ForEach(Array(zip(comparison.columns, row.values).enumerated()), id: \.offset) { _, pair in
                        (Text(pair.0.title + ": ").bold().foregroundColor(theme.topicInk) + md(pair.1))
                            .font(.body)
                            .foregroundStyle(Color.ink)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.card))
                .appears(shown >= r + 1)
            }
        }
    }

    private func columnHeader(_ col: ComparisonColumn, index: Int) -> some View {
        HStack(spacing: 6) {
            if let s = col.symbol { Image(systemName: s).accessibilityHidden(true) }
            md(col.title)
        }
        .font(.headline)
        .foregroundStyle(index == 0 ? theme.topicInk : Color.ink)
        .padding(.bottom, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Timeline (vertical spine: works at every text size)

struct TimelineView: View {
    let timeline: Timeline
    let sectionID: String
    @Environment(\.theme) private var theme

    var body: some View {
        let events = timeline.sortedEvents
        let gaps = spacing(for: events)
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(text: timeline.heading)
            Staged(id: sectionID + ".events", total: events.count, stagger: .milliseconds(180)) { shown in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { i, event in
                        row(event, isLast: i == events.count - 1, gapBelow: gaps[i], visible: i < shown)
                    }
                }
            }
        }
    }

    private func row(_ e: TimelineEvent, isLast: Bool, gapBelow: CGFloat, visible: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(visible ? theme.topic : Color.rule)
                    .overlay(Circle().strokeBorder(Color.paper, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .padding(.top, 3)
                if !isLast {
                    Rectangle()
                        .fill(theme.topic.opacity(0.5))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(y: visible ? 1 : 0, anchor: .top)
                }
            }
            .frame(width: 14)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(e.date)
                    .font(.caption2Strong.monospacedDigit())
                    .foregroundStyle(theme.topicInk)
                md(e.title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let d = e.detail {
                    md(d).font(.callout).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, isLast ? 0 : gapBelow)
            .appears(visible)
        }
        .accessibilityElement(children: .combine)
    }

    /// "even": the same gap between events. "linear": bigger gaps for bigger jumps in time,
    /// square-rooted so one huge gap doesn't push everything off screen.
    private func spacing(for events: [TimelineEvent]) -> [CGFloat] {
        guard (timeline.scale ?? .even) == .linear, events.count > 1 else {
            return Array(repeating: 20, count: events.count)
        }
        let deltas = zip(events, events.dropFirst()).map { $1.sortKey - $0.sortKey }
        let maxDelta = max(deltas.max() ?? 1, 1)
        return deltas.map { 14 + 56 * CGFloat(sqrt($0 / maxDelta)) } + [0]
    }
}

// MARK: - Steps (numbered / flow / cycle)

struct StepsView: View {
    let steps: Steps
    let sectionID: String
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(text: steps.heading)
            switch steps.style {
            case .numbered: numbered
            case .flow: flow
            case .cycle: cycle
            }
        }
    }

    private var numbered: some View {
        Staged(id: sectionID + ".steps", total: steps.steps.count) { shown in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Text("\(i + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(Color.ink)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(theme.topicSoft))
                                .overlay(Circle().strokeBorder(theme.topic, lineWidth: Metrics.stroke))
                            if i < steps.steps.count - 1 {
                                Rectangle().fill(Color.rule).frame(width: 2).frame(maxHeight: .infinity)
                            }
                        }
                        .accessibilityHidden(true)
                        stepText(step)
                            .padding(.bottom, i < steps.steps.count - 1 ? 20 : 0)
                    }
                    .appears(i < shown)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Step \(i + 1): ") + Text(plain(step.title)) + Text(step.body.map { ". " + plain($0) } ?? ""))
                }
            }
        }
    }

    private var flow: some View {
        Staged(id: sectionID + ".steps", total: steps.steps.count) { shown in
            VStack(spacing: 6) {
                ForEach(Array(steps.steps.enumerated()), id: \.offset) { i, step in
                    if i > 0 {
                        Image(systemName: "arrow.down")
                            .font(.headline)
                            .foregroundStyle(theme.topic)
                            .appears(i < shown)
                            .accessibilityHidden(true)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        if let s = step.symbol {
                            Image(systemName: s).font(.title3).foregroundStyle(theme.topicInk).frame(width: 28).accessibilityHidden(true)
                        }
                        stepText(step)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.card))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(theme.topic, lineWidth: 1.5))
                    .appears(i < shown)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// A loop: drawn as a cycle diagram, with each step's explanation listed underneath.
    private var cycle: some View {
        let nodes = steps.steps.enumerated().map { i, s in
            DiagramNode(id: "s\(i)", label: s.title, detail: nil, symbol: s.symbol, x: nil, y: nil, style: .filled, step: i + 1)
        }
        let edges = nodes.indices.map { i in
            DiagramEdge(from: "s\(i)", to: "s\((i + 1) % nodes.count)", label: nil, style: .arrow, step: i + 2)
        }
        let diagram = Diagram(layout: .cycle, nodes: nodes, edges: edges, aspectRatio: nil)
        let summary = steps.steps.map { plain($0.title) }.joined(separator: ", then ") + ", and back to the start."
        return VStack(alignment: .leading, spacing: 14) {
            Staged(id: sectionID + ".cycle", total: nodes.count + 1) { shown in
                VisualCanvas { DiagramView(diagram: diagram, shown: shown) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("A repeating cycle: \(summary)"))
            ForEach(Array(steps.steps.enumerated()).filter { $0.element.body != nil }, id: \.offset) { i, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(i + 1).").font(.headline.monospacedDigit()).foregroundStyle(theme.topicInk)
                    (md(step.title).bold() + Text(" — ") + md(step.body ?? "")).font(.callout).foregroundStyle(Color.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func stepText(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            md(step.title).font(.headline).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            if let b = step.body {
                md(b).font(.callout).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
