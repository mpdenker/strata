import SwiftUI
import LessonKit

/// S3: one long vertical page. Sticky progress bar on top; sections build as they scroll in.
struct LessonView: View {
    let lesson: Lesson

    @Environment(ContentStore.self) private var content
    @Environment(\.dismiss) private var dismiss

    @State private var reveal = RevealState()
    @State private var progress: Double = 0
    @State private var topSectionID: String?
    @State private var viewport: CGFloat = 800

    var body: some View {
        let theme = content.theme(for: lesson)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                LessonHeader(lesson: lesson, topic: content.topic(for: lesson))
                ForEach(lesson.sections) { section in
                    SectionView(section: section, lesson: lesson)
                }
                SourcesListView(lesson: lesson)
                LessonEndPlaceholder()
            }
            .scrollTargetLayout()
            .frame(maxWidth: Metrics.readingWidth)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .padding(.bottom, 80)
            .frame(maxWidth: .infinity)
        }
        .coordinateSpace(.named(LessonScroll.space))
        .scrollPosition(id: $topSectionID, anchor: .top)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { viewport = $0 }
        .modifier(ScrollProgressTracker(progress: $progress, fallback: fallbackProgress))
        .safeAreaInset(edge: .top, spacing: 0) {
            LessonTopBar(progress: progress, minutes: lesson.minutes) { dismiss() }
        }
        .background(Color.paper.ignoresSafeArea())
        .environment(reveal)
        .environment(\.theme, theme)
        .environment(\.viewportHeight, viewport)
        .tint(theme.topicInk)
    }

    /// iOS 17: progress from which section is at the top (moves in section-sized steps).
    private var fallbackProgress: Double {
        guard let id = topSectionID, let i = lesson.sections.firstIndex(where: { $0.id == id }),
              lesson.sections.count > 1 else { return 0 }
        return Double(i) / Double(lesson.sections.count - 1)
    }
}

/// iOS 18+: exact, smooth progress from the scroll geometry. iOS 17: the section-based fallback.
private struct ScrollProgressTracker: ViewModifier {
    @Binding var progress: Double
    let fallback: Double

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: Double.self) { g in
                let maxOffset = g.contentSize.height - g.containerSize.height + g.contentInsets.top + g.contentInsets.bottom
                guard maxOffset > 0 else { return 0 }
                return min(1, max(0, (g.contentOffset.y + g.contentInsets.top) / maxOffset))
            } action: { _, new in
                progress = new
            }
        } else {
            content.onChange(of: fallback, initial: true) { _, new in progress = new }
        }
    }
}

// MARK: - Top bar

struct LessonTopBar: View {
    let progress: Double
    let minutes: Int
    let onClose: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.card))
                    .overlay(Circle().strokeBorder(Color.rule))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close lesson")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.rule)
                    Capsule().fill(theme.topic).frame(width: max(8, geo.size.width * progress))
                }
            }
            .frame(height: 8)
            .accessibilityElement()
            .accessibilityLabel("Lesson progress")
            .accessibilityValue("\(Int((progress * 100).rounded())) percent")

            Text(minutesLeft)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.inkMuted)
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var minutesLeft: String {
        let left = Int((Double(minutes) * (1 - progress)).rounded(.up))
        return left <= 0 ? "Done" : "\(left) min left"
    }
}

// MARK: - Header, sources, end

struct LessonHeader: View {
    let lesson: Lesson
    let topic: Topic?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let topic {
                Label(topic.name, systemImage: topic.symbol)
                    .font(.caption2Strong)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.topicInk)
            }
            Text(lesson.title)
                .font(.display)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text(lesson.goal)
                .font(.callout)
                .foregroundStyle(Color.inkMuted)
            if let note = topic?.note {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
            Label("\(lesson.minutes) min · \(lesson.sections.count) sections", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.rule).frame(height: 1).offset(y: 24) }
    }
}

struct SourcesListView: View {
    let lesson: Lesson
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sources")
                .font(.displaySmall)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(lesson.sources.enumerated()), id: \.offset) { i, source in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(i + 1).").font(.callout.monospacedDigit()).foregroundStyle(Color.inkMuted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.citation).font(.callout).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                        // Opens in Safari. The app itself never fetches anything.
                        if let s = source.url, let url = URL(string: s) {
                            Link(destination: url) {
                                Text(url.host() ?? s).font(.caption).underline()
                            }
                            .foregroundStyle(theme.topicInk)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if let fc = lesson.factCheck {
                Label("Fact-checked against these sources on \(fc.checkedOn).", systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }
}

/// The final quiz and "Lesson complete" arrive in Step 2.
struct LessonEndPlaceholder: View {
    var body: some View {
        Label("End of lesson. The final quiz arrives in Step 2.", systemImage: "flag.checkered")
            .font(.callout)
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}
