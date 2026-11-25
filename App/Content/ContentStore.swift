import Foundation
import Observation
import LessonKit

/// Loads every topic and lesson from the bundled `Content` folder once, at launch.
/// No network: the folder ships inside the app.
@Observable
final class ContentStore {
    private(set) var report: LoadReport

    init(contentRoot: URL? = Bundle.main.url(forResource: "Content", withExtension: nil)) {
        if let contentRoot {
            report = ContentLoader.load(contentRoot: contentRoot)
        } else {
            report = LoadReport(topics: [], lessons: [],
                                topicsIssues: [ContentIssue(.error, "", "The Content folder is missing from the app bundle.")],
                                files: [])
        }
        #if DEBUG
        for file in report.files where !file.issues.isEmpty {
            print("[Content] \(file.file)")
            file.issues.forEach { print("  \($0)") }
        }
        #endif
    }

    var topics: [Topic] { report.topics }
    var lessons: [Lesson] { report.lessons }
    var hasProblems: Bool { report.errorCount > 0 }

    func lessons(in topic: Topic) -> [Lesson] { report.lessons(in: topic.id) }
    func topic(for lesson: Lesson) -> Topic? { report.topic(id: lesson.topic) }
    func theme(for lesson: Lesson) -> Theme { topic(for: lesson).map(Theme.init) ?? .fallback }
}
