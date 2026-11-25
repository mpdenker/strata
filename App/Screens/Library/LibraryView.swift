import SwiftUI
import LessonKit

/// Step 1's simple entry screen: every lesson grouped by topic. The real Home (Continue, Due for review,
/// topic shelves) replaces it in Step 4.
struct LibraryView: View {
    @Environment(ContentStore.self) private var content
    @State private var openLesson: Lesson?

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                if content.hasProblems {
                    NavigationLink {
                        ContentProblemsView()
                    } label: {
                        Label("\(content.report.failedFiles.count + (content.report.topicsIssues.isEmpty ? 0 : 1)) content file(s) failed to load",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.wrong)
                    }
                }
                #endif
                ForEach(content.topics) { topic in
                    let theme = Theme(topic: topic)
                    Section {
                        ForEach(content.lessons(in: topic)) { lesson in
                            Button { openLesson = lesson } label: { LessonRow(lesson: lesson, theme: theme) }
                                .buttonStyle(.plain)
                        }
                        if content.lessons(in: topic).isEmpty {
                            Text("No lessons yet").foregroundStyle(Color.inkMuted)
                        }
                    } header: {
                        Label(topic.name, systemImage: topic.symbol)
                            .font(.headline)
                            .foregroundStyle(theme.topicInk)
                            .textCase(nil)
                    }
                    .listRowBackground(Color.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle(AppInfo.name)
        }
        #if os(iOS)
        .fullScreenCover(item: $openLesson) { lesson in
            LessonView(lesson: lesson)
                .interactiveDismissDisabled()
        }
        #else
        .sheet(item: $openLesson) { LessonView(lesson: $0) }
        #endif
    }
}

struct LessonRow: View {
    let lesson: Lesson
    let theme: Theme

    var body: some View {
        HStack(spacing: 14) {
            Text("\(lesson.order)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.topicSoft))
                .overlay(Circle().strokeBorder(theme.topic, lineWidth: 1.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title).font(.headline).foregroundStyle(Color.ink)
                Text(lesson.goal).font(.caption).foregroundStyle(Color.inkMuted).lineLimit(2)
            }
            Spacer(minLength: 4)
            Text("\(lesson.minutes) min").font(.caption.monospacedDigit()).foregroundStyle(Color.inkMuted)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the lesson")
    }
}

/// S10 (Debug builds): which content files failed and exactly why.
struct ContentProblemsView: View {
    @Environment(ContentStore.self) private var content

    var body: some View {
        List {
            if !content.report.topicsIssues.isEmpty {
                Section("topics.json") {
                    ForEach(content.report.topicsIssues, id: \.self) { IssueRow(issue: $0) }
                }
            }
            ForEach(content.report.files.filter { !$0.issues.isEmpty }, id: \.file) { file in
                Section {
                    ForEach(file.issues, id: \.self) { IssueRow(issue: $0) }
                } header: {
                    Text(file.file).textCase(nil).font(.caption.monospaced())
                } footer: {
                    Text(file.errors.isEmpty ? "Loaded, with warnings." : "Not loaded. Fix the errors, then rebuild.")
                }
            }
        }
        .navigationTitle("Content problems")
    }
}

private struct IssueRow: View {
    let issue: ContentIssue
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(issue.severity == .error ? "Error" : "Warning",
                  systemImage: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle")
                .font(.caption2Strong)
                .foregroundStyle(issue.severity == .error ? Color.wrong : Color.inkMuted)
            if !issue.location.isEmpty {
                Text(issue.location).font(.caption.monospaced()).foregroundStyle(Color.inkMuted)
            }
            Text(issue.message).font(.callout)
        }
        .padding(.vertical, 2)
    }
}

enum AppInfo {
    /// The display name set in Config/App.xcconfig (APP_DISPLAY_NAME). Rename the app there.
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Strata"
    }
}
