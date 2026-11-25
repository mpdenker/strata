import SwiftUI
import LessonKit

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformColor = NSColor
#endif

// The "field notebook" look (SPEC.md §2). Colors are defined once in LessonKit.Palette
// (so they can be contrast-tested) and turned into light/dark-adaptive SwiftUI colors here.

extension PlatformColor {
    convenience init(_ rgb: RGB) {
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
    }

    /// A color that switches with light/dark mode.
    static func adaptive(_ pair: Palette.Pair) -> PlatformColor {
        #if canImport(UIKit)
        return UIColor { $0.userInterfaceStyle == .dark ? UIColor(pair.dark) : UIColor(pair.light) }
        #else
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(pair.dark) : NSColor(pair.light)
        }
        #endif
    }
}

extension Color {
    init(_ pair: Palette.Pair) {
        #if canImport(UIKit)
        self.init(uiColor: .adaptive(pair))
        #else
        self.init(nsColor: .adaptive(pair))
        #endif
    }

    static let paper = Color(Palette.paper)
    static let card = Color(Palette.card)
    static let ink = Color(Palette.ink)
    static let inkMuted = Color(Palette.inkMuted)
    static let rule = Color(Palette.rule)
    static let correct = Color(Palette.correct)
    static let wrong = Color(Palette.wrong)
}

/// The colors for one topic, derived from its topics.json entry.
struct Theme: Equatable {
    let topic: Color        // graphics and fills (≥ 3:1 on paper)
    let topicSoft: Color    // pale fills behind ink text
    let topicInk: Color     // topic-colored text (≥ 4.5:1)
    let symbol: String

    init(topic: Topic) {
        let light = RGB(hex: topic.color.light) ?? RGB(r: 0.07, g: 0.49, b: 0.48)
        let dark = RGB(hex: topic.color.dark) ?? light
        self.topic = Color(Palette.Pair(light: light, dark: dark))
        self.topicSoft = Color(Palette.Pair(light: Palette.topicSoft(light, dark: false), dark: Palette.topicSoft(dark, dark: true)))
        self.topicInk = Color(Palette.Pair(light: Palette.topicInk(light, dark: false), dark: Palette.topicInk(dark, dark: true)))
        self.symbol = topic.symbol
    }

    /// Used before content loads, and in previews.
    static let fallback = Theme(topic: Topic(id: "science", name: "Science", symbol: "atom", order: 0,
                                             color: HexPair(light: "#127C7A", dark: "#3BB8B2")))

    func color(_ token: ColorToken) -> Color {
        switch token {
        case .topic: topic
        case .topicSoft: topicSoft
        case .ink: .ink
        case .muted: .inkMuted
        case .paper: .paper
        case .correct: .correct
        case .wrong: .wrong
        case .none: .clear
        }
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.fallback
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Type

extension Font {
    /// New York (the system serif) for headings; SF Pro for body.
    static let displayXL = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let display = Font.system(.title, design: .serif).weight(.semibold)
    static let displayMedium = Font.system(.title2, design: .serif).weight(.semibold)
    static let displaySmall = Font.system(.title3, design: .serif).weight(.semibold)
    static let lessonBody = Font.system(.body)
    static let label = Font.system(.subheadline).weight(.medium)
    static let caption2Strong = Font.system(.caption).weight(.semibold)
}

// MARK: - Metrics

enum Metrics {
    static let readingWidth: CGFloat = 600
    static let sectionSpacing: CGFloat = 56
    static let gutter: CGFloat = 20
    static let corner: CGFloat = 16
    static let stroke: CGFloat = 2
}

// MARK: - Dot grid (decorative, hidden from VoiceOver)

struct DotGrid: View {
    var spacing: CGFloat = 16
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(.rule))
                    x += spacing
                }
                y += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

/// The canvas a visual sits on: card color, faint dot grid, rounded corners.
struct VisualCanvas<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                    .fill(Color.card)
                    .overlay(DotGrid().clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).strokeBorder(Color.rule, lineWidth: 1))
            }
    }
}
