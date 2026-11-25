import SwiftUI
import LessonKit

// MARK: - Icon array ("37 out of 100")

struct IconArrayView: View {
    let array: IconArray
    let shown: Int
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: max(1, array.columns)), spacing: 4) {
                ForEach(0..<array.total, id: \.self) { i in
                    let group = groupIndex(of: i)
                    let lit = group.map { $0 < shown } ?? false
                    Image(systemName: array.symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(lit ? theme.color(array.groups[group!].color) : Color.rule)
                        .frame(maxHeight: 26)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(array.groups.enumerated()), id: \.offset) { i, g in
                    HStack(spacing: 8) {
                        Image(systemName: array.symbol).foregroundStyle(theme.color(g.color))
                        Text("\(g.count)").font(.label.monospacedDigit()).foregroundStyle(Color.ink)
                        md(g.label).font(.callout).foregroundStyle(Color.inkMuted)
                    }
                    .appears(i < shown)
                }
            }
        }
    }

    /// Which group icon `i` belongs to (groups fill the grid in order), or nil if it's in none.
    private func groupIndex(of i: Int) -> Int? {
        var start = 0
        for (g, group) in array.groups.enumerated() {
            if i < start + group.count { return g }
            start += group.count
        }
        return nil
    }
}

// MARK: - Formula with labeled parts

struct FormulaView: View {
    let formula: Formula
    let shown: Int
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 34

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontal
            vertical
        }
    }

    private var horizontal: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(Array(formula.parts.enumerated()), id: \.offset) { i, part in
                VStack(spacing: 6) {
                    Text(part.text)
                        .font(.system(size: size, weight: .semibold, design: .serif))
                        .foregroundStyle(color(part))
                        .fixedSize()
                    if let label = part.label {
                        Rectangle().fill(theme.topic).frame(width: 2, height: 10)
                        Text(label).font(.caption).foregroundStyle(Color.inkMuted).fixedSize()
                    }
                }
                .appears(i < shown)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Accessibility sizes: the whole formula on one line, then each labeled part underneath.
    private var vertical: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(formula.parts.map(\.text).joined())
                .font(.system(size: size, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            ForEach(Array(formula.parts.enumerated()).filter { $0.element.label != nil }, id: \.offset) { i, part in
                HStack(alignment: .firstTextBaseline) {
                    Text(part.text.trimmingCharacters(in: .whitespaces)).font(.headline.monospaced()).foregroundStyle(color(part))
                    Text("= \(part.label!)").font(.body).foregroundStyle(Color.inkMuted)
                }
                .appears(i < shown)
            }
        }
    }

    private func color(_ part: FormulaPart) -> Color {
        if let c = part.color { return theme.color(c) }
        return part.label != nil ? theme.topicInk : .ink
    }
}

// MARK: - Big number (counts up)

struct BigNumberView: View {
    let number: BigNumber
    let shown: Int
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 64

    var body: some View {
        let target = number.value
        let counting = number.countUp == true && !reduceMotion
        VStack(alignment: .leading, spacing: 6) {
            CountingText(value: shown > 0 || !counting ? target : 0, format: { number.formatted($0) })
                .font(.system(size: size, weight: .bold, design: .serif).monospacedDigit())
                .foregroundStyle(theme.topicInk)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .animation(counting ? .easeOut(duration: 1.4) : nil, value: shown)
            md(number.label)
                .font(.title3)
                .foregroundStyle(Color.ink)
            if let note = number.dataNote, number.dataKind == .computed || number.dataKind == .illustrative {
                Label { Text(note) } icon: { Image(systemName: "function") }
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appears(shown > 0)
    }
}

/// Text that animates between numbers (SwiftUI interpolates `animatableData`).
struct CountingText: View, Animatable {
    var value: Double
    let format: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { Text(format(value)) }
}

// MARK: - Layers (a stack of labeled bands)

struct LayersView: View {
    let layers: Layers
    let shown: Int
    @Environment(\.theme) private var theme

    var body: some View {
        // "up": the first layer is the bottom of the stack and the stack builds upward.
        let up = (layers.direction ?? .up) == .up
        let ordered = Array(layers.layers.enumerated())
        VStack(spacing: 6) {
            ForEach(up ? ordered.reversed() : ordered, id: \.offset) { i, layer in
                HStack(spacing: 12) {
                    if let symbol = layer.symbol {
                        Image(systemName: symbol).font(.title3).foregroundStyle(theme.topicInk).frame(width: 30)
                    }
                    md(layer.label).font(.headline).foregroundStyle(Color.ink)
                    Spacer(minLength: 8)
                    if let detail = layer.detail {
                        md(detail).font(.callout).foregroundStyle(Color.inkMuted).multilineTextAlignment(.trailing)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(i.isMultiple(of: 2) ? theme.topicSoft : Color.card)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(theme.topic, lineWidth: 1.5))
                )
                .offset(y: i < shown ? 0 : (up ? -16 : 16))
                .opacity(i < shown ? 1 : 0)
            }
        }
    }
}

// MARK: - Symbol hero

struct SymbolHeroView: View {
    let symbol: SymbolVisual
    let shown: Int
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 96

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol.name)
                .font(.system(size: size, weight: .light))
                .foregroundStyle(theme.topic)
                .symbolEffect(.bounce, value: shown)
            if let caption = symbol.caption {
                md(caption).font(.label).foregroundStyle(Color.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .appears(shown > 0)
    }
}
