import Foundation

// Visuals (SPEC.md §6.4). Drawn by SwiftUI from this data; no image files.
// JSON: { "kind": "diagram", "accessibilityLabel": "…", …kind-specific fields… }

/// Semantic colors. Never hex in lesson files, so themes and dark mode work everywhere.
public enum ColorToken: String, Codable, Sendable, Hashable, CaseIterable {
    case topic, topicSoft, ink, muted, paper, correct, wrong, none
}

public enum VisualKind: String, Codable, Sendable, Hashable, CaseIterable {
    case diagram, shapes, iconArray, formula, bigNumber, layers, symbol
}

public struct Visual: Codable, Sendable, Hashable {
    public var accessibilityLabel: String
    public var body: VisualBody

    public var kind: VisualKind { body.kind }

    private enum CommonKeys: String, CodingKey { case kind, accessibilityLabel }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CommonKeys.self)
        accessibilityLabel = try c.decode(String.self, forKey: .accessibilityLabel)
        let raw = try c.decode(String.self, forKey: .kind)
        guard let kind = VisualKind(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "unknown visual kind '\(raw)'. Expected one of: "
                    + VisualKind.allCases.map(\.rawValue).joined(separator: ", "))
        }
        switch kind {
        case .diagram: body = .diagram(try Diagram(from: decoder))
        case .shapes: body = .shapes(try ShapesVisual(from: decoder))
        case .iconArray: body = .iconArray(try IconArray(from: decoder))
        case .formula: body = .formula(try Formula(from: decoder))
        case .bigNumber: body = .bigNumber(try BigNumber(from: decoder))
        case .layers: body = .layers(try Layers(from: decoder))
        case .symbol: body = .symbol(try SymbolVisual(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CommonKeys.self)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encode(accessibilityLabel, forKey: .accessibilityLabel)
        switch body {
        case .diagram(let v): try v.encode(to: encoder)
        case .shapes(let v): try v.encode(to: encoder)
        case .iconArray(let v): try v.encode(to: encoder)
        case .formula(let v): try v.encode(to: encoder)
        case .bigNumber(let v): try v.encode(to: encoder)
        case .layers(let v): try v.encode(to: encoder)
        case .symbol(let v): try v.encode(to: encoder)
        }
    }

    /// How many build steps the visual animates through (at least 1).
    public var stepCount: Int {
        let steps: [Int?]
        switch body {
        case .diagram(let d): steps = d.nodes.map(\.step) + (d.edges ?? []).map(\.step)
        case .shapes(let s): steps = s.items.map(\.step)
        case .iconArray(let a): return max(1, a.groups.count)
        case .formula(let f): return max(1, f.parts.count)
        case .layers(let l): return max(1, l.layers.count)
        case .bigNumber, .symbol: return 1
        }
        return max(1, steps.compactMap { $0 }.max() ?? 1)
    }
}

public enum VisualBody: Sendable, Hashable {
    case diagram(Diagram)
    case shapes(ShapesVisual)
    case iconArray(IconArray)
    case formula(Formula)
    case bigNumber(BigNumber)
    case layers(Layers)
    case symbol(SymbolVisual)

    public var kind: VisualKind {
        switch self {
        case .diagram: .diagram
        case .shapes: .shapes
        case .iconArray: .iconArray
        case .formula: .formula
        case .bigNumber: .bigNumber
        case .layers: .layers
        case .symbol: .symbol
        }
    }
}

// MARK: - diagram

public enum DiagramLayout: String, Codable, Sendable, Hashable, CaseIterable { case row, column, cycle, grid, free }
public enum NodeStyle: String, Codable, Sendable, Hashable, CaseIterable { case filled, outline, muted }
public enum EdgeStyle: String, Codable, Sendable, Hashable, CaseIterable { case arrow, line, dashed }

public struct DiagramNode: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var detail: String?
    public var symbol: String?
    public var x: Double?              // 0…1, only for layout "free"
    public var y: Double?
    public var style: NodeStyle?
    public var step: Int?

    public init(id: String, label: String, detail: String? = nil, symbol: String? = nil, x: Double? = nil,
                y: Double? = nil, style: NodeStyle? = nil, step: Int? = nil) {
        self.id = id; self.label = label; self.detail = detail; self.symbol = symbol
        self.x = x; self.y = y; self.style = style; self.step = step
    }
}

public struct DiagramEdge: Codable, Sendable, Hashable {
    public var from: String
    public var to: String
    public var label: String?
    public var style: EdgeStyle?
    public var step: Int?

    public init(from: String, to: String, label: String? = nil, style: EdgeStyle? = nil, step: Int? = nil) {
        self.from = from; self.to = to; self.label = label; self.style = style; self.step = step
    }
}

public struct Diagram: Codable, Sendable, Hashable {
    public var layout: DiagramLayout
    public var nodes: [DiagramNode]
    public var edges: [DiagramEdge]?
    public var aspectRatio: Double?    // width / height, for layout "free" (default 1.4)

    public init(layout: DiagramLayout, nodes: [DiagramNode], edges: [DiagramEdge]? = nil, aspectRatio: Double? = nil) {
        self.layout = layout; self.nodes = nodes; self.edges = edges; self.aspectRatio = aspectRatio
    }
}

// MARK: - shapes

public enum ShapeKind: String, Codable, Sendable, Hashable, CaseIterable { case rect, circle, polygon, line, text, symbol }
public enum TextSize: String, Codable, Sendable, Hashable, CaseIterable { case caption, body, headline, title }

/// One primitive on a 0…1 canvas (x across, y down, both as fractions of the canvas).
/// rect: x,y = top-left, w,h · circle: x,y = center, r = radius (fraction of width)
/// polygon / line: points [[x,y], …] · text / symbol: x,y = center.
public struct ShapeItem: Codable, Sendable, Hashable {
    public var shape: ShapeKind
    public var x: Double?
    public var y: Double?
    public var w: Double?
    public var h: Double?
    public var r: Double?
    public var corner: Double?
    public var points: [[Double]]?
    public var arrow: Bool?
    public var dashed: Bool?
    public var text: String?
    public var textSize: TextSize?
    public var name: String?           // SF Symbol, for shape "symbol"
    public var size: Double?           // symbol size, fraction of canvas width
    public var fill: ColorToken?
    public var stroke: ColorToken?
    public var step: Int?
}

public struct ShapesVisual: Codable, Sendable, Hashable {
    public var aspectRatio: Double     // width / height
    public var items: [ShapeItem]
}

// MARK: - iconArray

public struct IconGroup: Codable, Sendable, Hashable {
    public var count: Int
    public var color: ColorToken
    public var label: String
}

public struct IconArray: Codable, Sendable, Hashable {
    public var total: Int
    public var columns: Int
    public var symbol: String
    public var groups: [IconGroup]
}

// MARK: - formula

public struct FormulaPart: Codable, Sendable, Hashable {
    public var text: String
    public var label: String?
    public var color: ColorToken?
}

public struct Formula: Codable, Sendable, Hashable {
    public var parts: [FormulaPart]
}

// MARK: - bigNumber

public struct BigNumber: Codable, Sendable, Hashable {
    public var value: Double
    public var decimals: Int?
    public var prefix: String?
    public var suffix: String?
    public var label: String
    public var countUp: Bool?
    /// Like charts: `computed` numbers (e.g. 1000 × 1.07^40) don't need a source; show the formula in `dataNote`.
    public var dataKind: DataKind?
    public var dataNote: String?

    /// "$14,974" style text, using grouping separators.
    public func formatted(_ v: Double? = nil) -> String {
        let n = v ?? value
        let digits = decimals ?? 0
        let text = n.formatted(.number.precision(.fractionLength(digits)).grouping(.automatic))
        return (prefix ?? "") + text + (suffix ?? "")
    }
}

// MARK: - layers

public enum LayersDirection: String, Codable, Sendable, Hashable, CaseIterable { case up, down }

public struct LayerItem: Codable, Sendable, Hashable {
    public var label: String
    public var detail: String?
    public var symbol: String?
}

public struct Layers: Codable, Sendable, Hashable {
    public var layers: [LayerItem]
    public var direction: LayersDirection?
}

// MARK: - symbol

public struct SymbolVisual: Codable, Sendable, Hashable {
    public var name: String
    public var caption: String?
}
