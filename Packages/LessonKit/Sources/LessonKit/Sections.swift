import Foundation

// Section types (SPEC.md §6.3). In JSON a section is one flat object:
//   { "id": "…", "type": "timeline", "sourceRefs": […], "contested": {…}, …type-specific fields… }
// In Swift it's a `LessonSection` holding the common fields plus a `SectionBody` enum with the typed payload.

public enum SectionType: String, Codable, Sendable, Hashable, CaseIterable {
    case hook, textVisual, keyIdea, comparison, timeline, steps, chart, quote, check, recap
}

public struct LessonSection: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var sourceRefs: [String]?
    public var contested: Contested?
    /// For worked examples: how the numbers were calculated ("1,000 × 1.07^40"). Shown to the reader.
    public var computed: String?
    public var body: SectionBody

    public var type: SectionType { body.type }

    private enum CommonKeys: String, CodingKey { case id, type, sourceRefs, contested, computed }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CommonKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sourceRefs = try c.decodeIfPresent([String].self, forKey: .sourceRefs)
        contested = try c.decodeIfPresent(Contested.self, forKey: .contested)
        computed = try c.decodeIfPresent(String.self, forKey: .computed)
        let raw = try c.decode(String.self, forKey: .type)
        guard let type = SectionType(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c,
                debugDescription: "unknown section type '\(raw)'. Expected one of: "
                    + SectionType.allCases.map(\.rawValue).joined(separator: ", "))
        }
        // The payload reads its own keys from the same JSON object.
        switch type {
        case .hook: body = .hook(try Hook(from: decoder))
        case .textVisual: body = .textVisual(try TextVisual(from: decoder))
        case .keyIdea: body = .keyIdea(try KeyIdea(from: decoder))
        case .comparison: body = .comparison(try Comparison(from: decoder))
        case .timeline: body = .timeline(try Timeline(from: decoder))
        case .steps: body = .steps(try Steps(from: decoder))
        case .chart: body = .chart(try Chart(from: decoder))
        case .quote: body = .quote(try Quote(from: decoder))
        case .check: body = .check(try Check(from: decoder))
        case .recap: body = .recap(try Recap(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CommonKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type.rawValue, forKey: .type)
        try c.encodeIfPresent(sourceRefs, forKey: .sourceRefs)
        try c.encodeIfPresent(contested, forKey: .contested)
        try c.encodeIfPresent(computed, forKey: .computed)
        switch body {
        case .hook(let v): try v.encode(to: encoder)
        case .textVisual(let v): try v.encode(to: encoder)
        case .keyIdea(let v): try v.encode(to: encoder)
        case .comparison(let v): try v.encode(to: encoder)
        case .timeline(let v): try v.encode(to: encoder)
        case .steps(let v): try v.encode(to: encoder)
        case .chart(let v): try v.encode(to: encoder)
        case .quote(let v): try v.encode(to: encoder)
        case .check(let v): try v.encode(to: encoder)
        case .recap(let v): try v.encode(to: encoder)
        }
    }
}

public enum SectionBody: Sendable, Hashable {
    case hook(Hook)
    case textVisual(TextVisual)
    case keyIdea(KeyIdea)
    case comparison(Comparison)
    case timeline(Timeline)
    case steps(Steps)
    case chart(Chart)
    case quote(Quote)
    case check(Check)
    case recap(Recap)

    public var type: SectionType {
        switch self {
        case .hook: .hook
        case .textVisual: .textVisual
        case .keyIdea: .keyIdea
        case .comparison: .comparison
        case .timeline: .timeline
        case .steps: .steps
        case .chart: .chart
        case .quote: .quote
        case .check: .check
        case .recap: .recap
        }
    }
}

// MARK: - Payloads

public struct Hook: Codable, Sendable, Hashable {
    public var headline: String
    public var body: String
    public var visual: Visual?
}

public enum TextVisualLayout: String, Codable, Sendable, Hashable, CaseIterable { case visualFirst, textFirst }

public struct TextVisual: Codable, Sendable, Hashable {
    public var heading: String?
    public var body: String
    public var visual: Visual
    public var layout: TextVisualLayout?
}

public struct KeyIdea: Codable, Sendable, Hashable {
    public var statement: String
    public var body: String?
    public var symbol: String?
}

public struct ComparisonColumn: Codable, Sendable, Hashable {
    public var title: String
    public var symbol: String?
}

public struct ComparisonRow: Codable, Sendable, Hashable {
    public var label: String
    public var values: [String]
}

public struct Comparison: Codable, Sendable, Hashable {
    public var heading: String?
    public var columns: [ComparisonColumn]
    public var rows: [ComparisonRow]
    public var takeaway: String?
}

public enum TimelineScale: String, Codable, Sendable, Hashable, CaseIterable { case linear, even }

public struct TimelineEvent: Codable, Sendable, Hashable {
    public var date: String            // what's displayed: "27 BCE", "c. 300 BCE", "1 Jan 1983"
    public var sortKey: Double         // for ordering / spacing; negative = BCE
    public var title: String
    public var detail: String?
    public var approx: Bool?
}

public struct Timeline: Codable, Sendable, Hashable {
    public var heading: String?
    public var events: [TimelineEvent]
    public var scale: TimelineScale?

    public var sortedEvents: [TimelineEvent] { events.sorted { $0.sortKey < $1.sortKey } }
}

public enum StepsStyle: String, Codable, Sendable, Hashable, CaseIterable { case numbered, cycle, flow }

public struct Step: Codable, Sendable, Hashable {
    public var title: String
    public var body: String?
    public var symbol: String?
}

public struct Steps: Codable, Sendable, Hashable {
    public var heading: String?
    public var steps: [Step]
    public var style: StepsStyle
}

public enum ChartKind: String, Codable, Sendable, Hashable, CaseIterable { case bar, line }

/// Where chart numbers come from. `sourced` needs sourceRefs; `computed` shows its formula; `illustrative` is labeled.
public enum DataKind: String, Codable, Sendable, Hashable, CaseIterable { case sourced, computed, illustrative }

/// An x value: a number (continuous axis, e.g. years) or a label (categories).
public enum ChartX: Codable, Sendable, Hashable {
    case number(Double)
    case label(String)

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let s = try? c.decode(String.self) { self = .label(s); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "x must be a number or a string")
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .number(let d): try c.encode(d)
        case .label(let s): try c.encode(s)
        }
    }

    public var display: String {
        switch self {
        case .number(let d): d.rounded() == d ? String(Int(d)) : String(d)
        case .label(let s): s
        }
    }
}

public struct ChartPoint: Codable, Sendable, Hashable {
    public var x: ChartX
    public var y: Double
}

public struct ChartSeries: Codable, Sendable, Hashable {
    public var name: String
    public var points: [ChartPoint]
}

public struct Chart: Codable, Sendable, Hashable {
    public var heading: String?
    public var chartKind: ChartKind
    public var series: [ChartSeries]
    public var xLabel: String
    public var yLabel: String
    public var unit: String?
    public var dataKind: DataKind
    public var dataNote: String
    public var caption: String
}

public struct Quote: Codable, Sendable, Hashable {
    public var text: String
    public var speaker: String
    public var work: String
    public var year: String
    public var translator: String?
    public var publicDomain: Bool
}

public struct Check: Codable, Sendable, Hashable {
    public var questions: [Question]
}

public struct Recap: Codable, Sendable, Hashable {
    public var bullets: [String]
}
