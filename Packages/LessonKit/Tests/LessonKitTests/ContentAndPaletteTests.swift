import Foundation
import Testing
@testable import LessonKit

/// The repository root (…/Packages/LessonKit/Tests/LessonKitTests/<this file> → up five levels).
let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<5 { url.deleteLastPathComponent() }
    return url
}()

@Suite("Bundled content")
struct BundledContentTests {
    let report = ContentLoader.load(contentRoot: repoRoot.appendingPathComponent("Content"))

    @Test func everyLessonFileIsValid() {
        for file in report.files {
            #expect(file.errors.isEmpty, "\(file.file):\n\(file.errors.map(\.description).joined(separator: "\n"))")
        }
        #expect(report.topicsIssues.isEmpty, "\(report.topicsIssues)")
    }

    @Test func noWarningsInShippedContent() {
        for file in report.files {
            #expect(file.warnings.isEmpty, "\(file.file):\n\(file.warnings.map(\.description).joined(separator: "\n"))")
        }
    }

    @Test func everyTopicHasAtLeastOneLesson() {
        for topic in report.topics {
            #expect(!report.lessons(in: topic.id).isEmpty, "\(topic.name) has no lessons")
        }
    }

    @Test func questionIDsAreGloballyUnique() {
        let ids = report.lessons.flatMap { $0.allQuestions.map(\.globalID) }
        #expect(Set(ids).count == ids.count)
    }
}

@Suite("Palette contrast (WCAG)")
struct PaletteTests {
    let topics = ContentLoader.loadTopics(at: repoRoot.appendingPathComponent("Content/topics.json")).0

    @Test func knownContrastValues() {
        // Sanity-check the formula against known values: black on white is 21:1.
        #expect(abs(RGB(hex: "#000000")!.contrast(with: RGB(hex: "#FFFFFF")!) - 21) < 0.001)
        #expect(abs(RGB(hex: "#777777")!.contrast(with: RGB(hex: "#FFFFFF")!) - 4.48) < 0.01)
    }

    @Test(arguments: [false, true])
    func textColorsReadOnPaperAndCard(dark: Bool) {
        for bg in [Palette.paper, Palette.card] {
            let b = dark ? bg.dark : bg.light
            for (name, fg) in [("ink", Palette.ink), ("inkMuted", Palette.inkMuted), ("correct", Palette.correct), ("wrong", Palette.wrong)] {
                let ratio = (dark ? fg.dark : fg.light).contrast(with: b)
                #expect(ratio >= 4.5, "\(name) on background is \(ratio), needs 4.5 (dark: \(dark))")
            }
        }
    }

    @Test(arguments: [false, true])
    func topicColorsAsGraphicsOnPaper(dark: Bool) throws {
        #expect(topics.count == 5)
        for topic in topics {
            let c = try #require(RGB(hex: dark ? topic.color.dark : topic.color.light))
            let ratio = c.contrast(with: dark ? Palette.paper.dark : Palette.paper.light)
            #expect(ratio >= 3, "\(topic.name) fill on paper is \(ratio), needs 3 (dark: \(dark))")
        }
    }

    @Test(arguments: [false, true])
    func topicInkIsReadableText(dark: Bool) throws {
        for topic in topics {
            let c = try #require(RGB(hex: dark ? topic.color.dark : topic.color.light))
            let ink = Palette.topicInk(c, dark: dark)
            for bg in [Palette.paper, Palette.card] {
                let ratio = ink.contrast(with: dark ? bg.dark : bg.light)
                #expect(ratio >= 4.5, "\(topic.name) text is \(ratio) (dark: \(dark))")
            }
        }
    }

    @Test(arguments: [false, true])
    func inkReadsOnTopicSoftFills(dark: Bool) throws {
        for topic in topics {
            let c = try #require(RGB(hex: dark ? topic.color.dark : topic.color.light))
            let soft = Palette.topicSoft(c, dark: dark)
            let ratio = (dark ? Palette.ink.dark : Palette.ink.light).contrast(with: soft)
            #expect(ratio >= 4.5, "ink on \(topic.name) soft fill is \(ratio) (dark: \(dark))")
        }
    }

    @Test func topicHuesAreDistinct() throws {
        // No two topic colors should be near-identical: compare in plain RGB distance.
        let colors = try topics.map { try #require(RGB(hex: $0.color.light)) }
        for i in colors.indices {
            for j in colors.indices where j > i {
                let d = sqrt(pow(colors[i].r - colors[j].r, 2) + pow(colors[i].g - colors[j].g, 2) + pow(colors[i].b - colors[j].b, 2))
                #expect(d > 0.25, "\(topics[i].name) and \(topics[j].name) are too similar")
            }
        }
    }
}
