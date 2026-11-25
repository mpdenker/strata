import SwiftUI

/// Lesson text supports inline Markdown: **bold**, *italic*.
func md(_ string: String) -> Text {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    if let attributed = try? AttributedString(markdown: string, options: options) {
        return Text(attributed)
    }
    return Text(verbatim: string)
}

/// Plain text with Markdown markers removed, for VoiceOver labels and counts.
func plain(_ string: String) -> String {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    if let attributed = try? AttributedString(markdown: string, options: options) {
        return String(attributed.characters)
    }
    return string
}

/// A shuffle that's the same every time for the same seed (Swift's own hashing changes per launch).
/// Used so multiple-choice options don't jump around when a view redraws.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        // FNV-1a hash of the seed string.
        var h: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 { h = (h ^ UInt64(byte)) &* 0x100000001b3 }
        state = h == 0 ? 0x9E3779B97F4A7C15 : h
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }
}

extension Array {
    func stableShuffled(seed: String) -> [Element] {
        var g = SeededGenerator(seed: seed)
        return shuffled(using: &g)
    }
}
