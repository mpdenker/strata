import Foundation
import LessonKit

// Usage: swift run --package-path Packages/LessonKit validate-lessons Content [--strict]
// Checks topics.json and every lesson under Content/Lessons. Exit code 1 if any file has errors
// (or, with --strict, any warnings).

let args = Array(CommandLine.arguments.dropFirst())
let strict = args.contains("--strict")
guard let rootArg = args.first(where: { !$0.hasPrefix("--") }) else {
    print("usage: validate-lessons <ContentFolder> [--strict]")
    exit(2)
}
let root = URL(fileURLWithPath: rootArg)
let report = ContentLoader.load(contentRoot: root)

if !report.topicsIssues.isEmpty {
    print(report.topicsIssues.contains { $0.severity == .error } ? "✗ topics.json" : "⚠ topics.json")
    for issue in report.topicsIssues { print("  \(issue)") }
}

for file in report.files {
    if file.issues.isEmpty {
        let lesson = file.lesson!
        print("✓ \(file.file)  (\(lesson.sections.count) sections, \(lesson.allQuestions.count) questions, \(lesson.sources.count) sources)")
        continue
    }
    print(file.errors.isEmpty ? "⚠ \(file.file)" : "✗ \(file.file)")
    for issue in file.issues.sorted(by: { ($0.severity == .error ? 0 : 1) < ($1.severity == .error ? 0 : 1) }) {
        print("  \(issue)")
    }
}

let failed = report.failedFiles.count
let passed = report.files.count - failed
print("\(failed) file\(failed == 1 ? "" : "s") failed · \(passed) passed · \(report.warningCount) warning\(report.warningCount == 1 ? "" : "s")")

// Per-topic summary, so it's obvious when a topic is short of lessons.
for topic in report.topics {
    print("  \(topic.name): \(report.lessons(in: topic.id).count) lesson(s)")
}

let hasErrors = report.errorCount > 0
exit(hasErrors || (strict && report.warningCount > 0) ? 1 : 0)
