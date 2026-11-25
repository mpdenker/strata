import Foundation

/// An sRGB color parsed from "#RRGGBB".
public struct RGB: Sendable, Hashable {
    public var r: Double, g: Double, b: Double   // 0…1

    public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        r = Double((v >> 16) & 0xFF) / 255
        g = Double((v >> 8) & 0xFF) / 255
        b = Double(v & 0xFF) / 255
    }

    /// WCAG 2.x relative luminance.
    public var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// WCAG contrast ratio, 1…21. Text needs ≥ 4.5, large text and graphics ≥ 3.
    public func contrast(with other: RGB) -> Double {
        let (hi, lo) = luminance > other.luminance ? (luminance, other.luminance) : (other.luminance, luminance)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// Mix toward another color: 0 = self, 1 = other.
    public func mixed(with other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }
}

/// The app's fixed colors (SPEC.md §2.2). Topic colors come from topics.json.
/// Kept here (not in the app) so the contrast tests can run with `swift test`.
public enum Palette {
    public struct Pair: Sendable, Hashable {
        public let light: RGB
        public let dark: RGB
        public init(light: RGB, dark: RGB) { self.light = light; self.dark = dark }
    }

    private static func pair(_ l: String, _ d: String) -> Pair { Pair(light: RGB(hex: l)!, dark: RGB(hex: d)!) }

    public static let paper    = pair("#F6F1E7", "#14161C")
    public static let card     = pair("#FFFDF8", "#1E2129")
    public static let ink      = pair("#1F2430", "#ECE7DC")
    public static let inkMuted = pair("#555A68", "#A3A7B3")
    public static let rule     = pair("#E2DACB", "#2C303A")
    public static let correct  = pair("#2A7247", "#5CC48A")
    public static let wrong    = pair("#B3261E", "#F2766E")

    /// A darker (light mode) / lighter (dark mode) version of a topic color, for topic-colored *text*.
    /// Steps toward ink until it reaches 4.5:1 (with a little margin) on both paper and card.
    public static func topicInk(_ topic: RGB, dark: Bool) -> RGB {
        let target = dark ? ink.dark : ink.light
        let backgrounds = dark ? [card.dark, paper.dark] : [card.light, paper.light]
        var t = 0.0
        var c = topic
        while backgrounds.contains(where: { c.contrast(with: $0) < 4.6 }) && t < 1 {
            t += 0.05
            c = topic.mixed(with: target, t)
        }
        return c
    }

    /// A pale tint of a topic color for large fills behind ink text (callouts, nodes).
    public static func topicSoft(_ topic: RGB, dark: Bool) -> RGB {
        topic.mixed(with: dark ? card.dark : card.light, dark ? 0.72 : 0.82)
    }
}
