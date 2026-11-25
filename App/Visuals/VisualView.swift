import SwiftUI
import LessonKit

/// Draws any visual from lesson JSON, building it step by step when its section scrolls into view.
/// VoiceOver reads the visual's required `accessibilityLabel` as a single image.
struct VisualView: View {
    let visual: Visual
    /// Unique per visual within the lesson (section id + slot), used to remember finished builds.
    let id: String

    var body: some View {
        Staged(id: id, total: visual.stepCount) { shown in
            content(shown)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(visual.accessibilityLabel))
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private func content(_ shown: Int) -> some View {
        switch visual.body {
        case .diagram(let d): VisualCanvas { DiagramView(diagram: d, shown: shown) }
        case .shapes(let s): VisualCanvas { ShapesView(visual: s, shown: shown) }
        case .iconArray(let a): VisualCanvas { IconArrayView(array: a, shown: shown) }
        case .formula(let f): VisualCanvas { FormulaView(formula: f, shown: shown) }
        case .layers(let l): VisualCanvas { LayersView(layers: l, shown: shown) }
        case .bigNumber(let b): BigNumberView(number: b, shown: shown)
        case .symbol(let s): SymbolHeroView(symbol: s, shown: shown)
        }
    }
}
