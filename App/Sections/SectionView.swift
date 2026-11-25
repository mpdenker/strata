import SwiftUI
import LessonKit

/// One "layer" of a scroll lesson: the section's content, plus its Contested note and source footnote.
struct SectionView: View {
    let section: LessonSection
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
            if let computed = section.computed {
                Label { Text("Worked example: \(computed)") } icon: { Image(systemName: "function") }
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let contested = section.contested {
                ContestedNote(note: contested.note)
            }
            if let refs = section.sourceRefs, !refs.isEmpty {
                SourceFootnote(sources: refs.compactMap(lesson.source))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.sectionID, section.id)
        .trackFirstVisible(id: section.id)
        .sectionEntrance()
    }

    @ViewBuilder
    private var content: some View {
        switch section.body {
        case .hook(let v): HookView(hook: v, sectionID: section.id)
        case .textVisual(let v): TextVisualView(item: v, sectionID: section.id)
        case .keyIdea(let v): KeyIdeaView(idea: v)
        case .comparison(let v): ComparisonView(comparison: v, sectionID: section.id)
        case .timeline(let v): TimelineView(timeline: v, sectionID: section.id)
        case .steps(let v): StepsView(steps: v, sectionID: section.id)
        case .chart(let v): ChartSectionView(chart: v, sectionID: section.id)
        case .quote(let v): QuoteView(quote: v)
        case .check(let v): CheckView(check: v, lessonID: lesson.id)
        case .recap(let v): RecapView(recap: v)
        }
    }
}

/// Section heading used by several section types.
struct SectionHeading: View {
    let text: String?
    var body: some View {
        if let text, !text.isEmpty {
            md(text)
                .font(.displaySmall)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

struct BodyText: View {
    let text: String
    var body: some View {
        md(text)
            .font(.lessonBody)
            .foregroundStyle(Color.ink)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Contested": shown wherever scholars disagree or a famous finding didn't replicate.
struct ContestedNote: View {
    let note: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(theme.topicInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Contested").font(.caption2Strong).textCase(.uppercase).foregroundStyle(theme.topicInk)
                md(note).font(.callout).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.topic, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
    }
}

/// "Source: Psychology 2e" under a section; the full citations are at the end of the lesson.
struct SourceFootnote: View {
    let sources: [Source]
    var body: some View {
        if !sources.isEmpty {
            Label {
                let titles = sources.map(\.title).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                Text((titles.count == 1 ? "Source: " : "Sources: ") + titles.joined(separator: "; "))
            } icon: {
                Image(systemName: "text.book.closed")
            }
            .font(.caption)
            .foregroundStyle(Color.inkMuted)
            .accessibilityElement(children: .combine)
        }
    }
}
