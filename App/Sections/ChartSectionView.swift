import SwiftUI
import Charts
import LessonKit

/// Bar or line chart from lesson data (Swift Charts is an Apple framework, not a dependency).
/// Bars rise / lines draw in when the section scrolls into view. The data's origin is always labeled.
struct ChartSectionView: View {
    let chart: LessonKit.Chart
    let sectionID: String
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 230

    private var numericX: Bool {
        chart.series.allSatisfy { $0.points.allSatisfy { if case .number = $0.x { true } else { false } } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: chart.heading)
            DataKindTag(kind: chart.dataKind)
            Staged(id: sectionID + ".chart", total: 1) { shown in
                VisualCanvas {
                    plot(grow: shown >= 1 ? 1 : 0)
                        .frame(height: height)
                        .animation(.easeOut(duration: 0.9), value: shown)
                }
            }
            md(chart.caption).font(.lessonBody).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            Label { Text(chart.dataNote) } icon: { Image(systemName: chart.dataKind == .computed ? "function" : "info.circle") }
                .font(.caption)
                .foregroundStyle(Color.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func plot(grow: Double) -> some View {
        let multi = chart.series.count > 1
        return Charts.Chart {
            ForEach(chart.series, id: \.name) { series in
                ForEach(Array(series.points.enumerated()), id: \.offset) { _, p in
                    mark(series: series, point: p, grow: grow, multi: multi)
                }
            }
        }
        .chartForegroundStyleScale(range: [theme.topic, Color.ink, Color.inkMuted])
        .chartLegend(multi ? .visible : .hidden)
        .chartXAxisLabel(chart.xLabel)
        .chartYAxisLabel(chart.yLabel + (chart.unit.map { " (\($0))" } ?? ""))
        .chartYScale(domain: .automatic(includesZero: true))
    }

    @ChartContentBuilder
    private func mark(series: ChartSeries, point p: ChartPoint, grow: Double, multi: Bool) -> some ChartContent {
        let y = p.y * grow
        let label = "\(series.name), \(p.x.display): \(format(p.y))"
        switch (chart.chartKind, p.x) {
        case (.bar, .label(let x)):
            BarMark(x: .value(chart.xLabel, x), y: .value(chart.yLabel, y))
                .foregroundStyle(by: .value("Series", series.name))
                .position(by: .value("Series", series.name))
                .annotation(position: .top, spacing: 4) {
                    Text(format(p.y)).font(.caption2.monospacedDigit()).foregroundStyle(Color.inkMuted).opacity(grow)
                }
                .accessibilityLabel(label)
        case (.bar, .number(let x)):
            BarMark(x: .value(chart.xLabel, x), y: .value(chart.yLabel, y))
                .foregroundStyle(by: .value("Series", series.name))
                .accessibilityLabel(label)
        case (.line, .number(let x)):
            LineMark(x: .value(chart.xLabel, x), y: .value(chart.yLabel, y))
                .foregroundStyle(by: .value("Series", series.name))
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.monotone)
                .accessibilityLabel(label)
        case (.line, .label(let x)):
            LineMark(x: .value(chart.xLabel, x), y: .value(chart.yLabel, y))
                .foregroundStyle(by: .value("Series", series.name))
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .symbol(by: .value("Series", series.name))
                .accessibilityLabel(label)
        }
    }

    private func format(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...2))) + (chart.unit.map { $0 == "%" ? "%" : " \($0)" } ?? "")
    }
}

struct DataKindTag: View {
    let kind: DataKind
    var body: some View {
        let (text, symbol): (String, String) = switch kind {
        case .sourced: ("Sourced data", "checkmark.seal")
        case .computed: ("Computed", "function")
        case .illustrative: ("Illustrative, not real data", "pencil.and.outline")
        }
        Label(text, systemImage: symbol)
            .font(.caption2Strong)
            .foregroundStyle(Color.inkMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().strokeBorder(Color.rule))
    }
}
