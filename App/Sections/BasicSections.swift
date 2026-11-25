import SwiftUI
import LessonKit

struct HookView: View {
    let hook: Hook
    let sectionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            md(hook.headline)
                .font(.displayXL)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let visual = hook.visual {
                VisualView(visual: visual, id: sectionID + ".visual")
            }
            md(hook.body)
                .font(.title3)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TextVisualView: View {
    let item: TextVisual
    let sectionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(text: item.heading)
            if item.layout == .textFirst {
                BodyText(text: item.body)
                VisualView(visual: item.visual, id: sectionID + ".visual")
            } else {
                VisualView(visual: item.visual, id: sectionID + ".visual")
                BodyText(text: item.body)
            }
        }
    }
}

struct KeyIdeaView: View {
    let idea: KeyIdea
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: idea.symbol ?? "key.horizontal")
                Text("Key idea").textCase(.uppercase)
            }
            .font(.caption2Strong)
            .foregroundStyle(theme.topicInk)
            .accessibilityHidden(true)

            md(idea.statement)
                .font(.displayMedium)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text("Key idea: ") + Text(plain(idea.statement)))
            if let body = idea.body {
                BodyText(text: body)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .fill(theme.topicSoft)
        )
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: Metrics.corner, bottomLeadingRadius: Metrics.corner, style: .continuous)
                .fill(theme.topic)
                .frame(width: 6)
                .accessibilityHidden(true)
        }
    }
}

struct QuoteView: View {
    let quote: Quote
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\u{201C}")
                .font(.system(size: 72, weight: .bold, design: .serif))
                .foregroundStyle(theme.topic)
                .frame(height: 40, alignment: .top)
                .accessibilityHidden(true)
            md(quote.text)
                .font(.system(.title3, design: .serif).italic())
                .foregroundStyle(Color.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("— \(quote.speaker)").font(.label).foregroundStyle(Color.ink)
                Text(attribution).font(.caption).foregroundStyle(Color.inkMuted)
            }
        }
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
    }

    private var attribution: String {
        var s = "\(quote.work), \(quote.year)"
        if let t = quote.translator { s += " · trans. \(t)" }
        return s
    }
}

struct RecapView: View {
    let recap: Recap
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Recap", systemImage: "list.number")
                .font(.caption2Strong)
                .textCase(.uppercase)
                .foregroundStyle(theme.topicInk)
            ForEach(Array(recap.bullets.enumerated()), id: \.offset) { i, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(i + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Color.ink)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(theme.topicSoft))
                        .overlay(Circle().strokeBorder(theme.topic, lineWidth: 1.5))
                        .accessibilityHidden(true)
                    md(bullet)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Color.card))
        .overlay(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).strokeBorder(Color.rule))
    }
}
