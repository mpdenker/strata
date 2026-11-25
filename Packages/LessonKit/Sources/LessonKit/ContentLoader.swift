import Foundation

/// The result of loading one lesson file.
public struct FileReport: Sendable {
    public var file: String            // path relative to the content root
    public var lesson: Lesson?         // nil if the file had errors
    public var issues: [ContentIssue]

    public var errors: [ContentIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [ContentIssue] { issues.filter { $0.severity == .warning } }
}

/// Everything the app needs from the Content folder, plus every problem found.
public struct LoadReport: Sendable {
    public var topics: [Topic]
    /// Lessons that loaded with no errors, sorted by topic order, then lesson order.
    public var lessons: [Lesson]
    public var topicsIssues: [ContentIssue]
    public var files: [FileReport]

    public init(topics: [Topic], lessons: [Lesson], topicsIssues: [ContentIssue], files: [FileReport]) {
        self.topics = topics
        self.lessons = lessons
        self.topicsIssues = topicsIssues
        self.files = files
    }

    public var failedFiles: [FileReport] { files.filter { !$0.errors.isEmpty } }
    public var errorCount: Int { topicsIssues.filter { $0.severity == .error }.count + files.reduce(0) { $0 + $1.errors.count } }
    public var warningCount: Int { files.reduce(0) { $0 + $1.warnings.count } }

    public func lessons(in topicID: String) -> [Lesson] { lessons.filter { $0.topic == topicID } }
    public func lesson(id: String) -> Lesson? { lessons.first { $0.id == id } }
    public func topic(id: String) -> Topic? { topics.first { $0.id == id } }
}

public enum ContentLoader {
    /// Loads `topics.json` and every `*.json` under `Lessons/` (recursively).
    /// Bad files are reported and skipped; good files always load.
    public static func load(contentRoot: URL) -> LoadReport {
        let (topics, topicsIssues) = loadTopics(at: contentRoot.appendingPathComponent("topics.json"))
        let topicIDs = Set(topics.map(\.id))

        let lessonsDir = contentRoot.appendingPathComponent("Lessons")
        var reports: [FileReport] = []
        for url in jsonFiles(under: lessonsDir) {
            let relative = relativePath(of: url, to: contentRoot)
            do {
                let data = try Data(contentsOf: url)
                reports.append(loadLesson(data: data, file: relative, topicIDs: topicIDs))
            } catch {
                reports.append(FileReport(file: relative, lesson: nil,
                                          issues: [ContentIssue(.error, "", "can't read file: \(error.localizedDescription)")]))
            }
        }

        // Cross-file rules: lesson IDs unique; one lesson per (topic, order).
        var seenIDs: [String: String] = [:]
        var seenSlots: [String: String] = [:]
        for i in reports.indices {
            guard let lesson = reports[i].lesson else { continue }
            if let other = seenIDs[lesson.id] {
                reports[i].issues.append(ContentIssue(.error, "id", "lesson id '\(lesson.id)' is already used by \(other)"))
            } else {
                seenIDs[lesson.id] = reports[i].file
            }
            let slot = "\(lesson.topic)#\(lesson.order)"
            if let other = seenSlots[slot] {
                reports[i].issues.append(ContentIssue(.error, "order",
                    "topic '\(lesson.topic)' already has a lesson with order \(lesson.order) (\(other))"))
            } else {
                seenSlots[slot] = reports[i].file
            }
            if !reports[i].errors.isEmpty { reports[i].lesson = nil }
        }

        let topicOrder = Dictionary(uniqueKeysWithValues: topics.map { ($0.id, $0.order) })
        let lessons = reports.compactMap(\.lesson).sorted {
            (topicOrder[$0.topic] ?? .max, $0.order) < (topicOrder[$1.topic] ?? .max, $1.order)
        }
        return LoadReport(topics: topics.sorted { $0.order < $1.order }, lessons: lessons,
                          topicsIssues: topicsIssues, files: reports)
    }

    // MARK: Topics

    static func loadTopics(at url: URL) -> ([Topic], [ContentIssue]) {
        guard let data = try? Data(contentsOf: url) else {
            return ([], [ContentIssue(.error, "", "topics.json is missing from the content folder")])
        }
        let raw: Any
        do { raw = try JSONSerialization.jsonObject(with: data) } catch {
            return ([], [ContentIssue(.error, "", "topics.json is not valid JSON: \(jsonSyntaxMessage(error))")])
        }
        do {
            let file = try JSONDecoder().decode(TopicsFile.self, from: data)
            var issues = unknownKeyIssues(original: raw, decoded: file)
            var seen = Set<String>()
            for (i, t) in file.topics.enumerated() where !seen.insert(t.id).inserted {
                issues.append(ContentIssue(.error, "topics[\(i)].id", "duplicate topic id '\(t.id)'"))
            }
            for (i, t) in file.topics.enumerated() {
                for (mode, hex) in [("light", t.color.light), ("dark", t.color.dark)] where RGB(hex: hex) == nil {
                    issues.append(ContentIssue(.error, "topics[\(i)].color.\(mode)", "'\(hex)' is not a #RRGGBB color"))
                }
            }
            return issues.contains { $0.severity == .error } ? ([], issues) : (file.topics, issues)
        } catch let error as DecodingError {
            return ([], [describe(error, raw: raw)])
        } catch {
            return ([], [ContentIssue(.error, "", error.localizedDescription)])
        }
    }

    // MARK: Lessons

    /// Decode + check one lesson file. Public so tests and the CLI can feed it data directly.
    public static func loadLesson(data: Data, file: String, topicIDs: Set<String>) -> FileReport {
        let raw: Any
        do { raw = try JSONSerialization.jsonObject(with: data) } catch {
            return FileReport(file: file, lesson: nil,
                              issues: [ContentIssue(.error, "", "not valid JSON: \(jsonSyntaxMessage(error))")])
        }
        let lesson: Lesson
        do {
            lesson = try JSONDecoder().decode(Lesson.self, from: data)
        } catch let error as DecodingError {
            return FileReport(file: file, lesson: nil, issues: [describe(error, raw: raw)])
        } catch {
            return FileReport(file: file, lesson: nil, issues: [ContentIssue(.error, "", error.localizedDescription)])
        }

        var issues = unknownKeyIssues(original: raw, decoded: lesson)
        issues += LessonValidator.validate(lesson, topicIDs: topicIDs).map { found in
            ContentIssue(found.severity, JSONPath.describe(found.path, raw: raw), found.message)
        }
        let hasErrors = issues.contains { $0.severity == .error }
        return FileReport(file: file, lesson: hasErrors ? nil : lesson, issues: issues)
    }

    // MARK: Unknown keys

    /// Typos like "headlin" or keys from another section type are errors, not silently ignored.
    /// Trick: re-encode what we decoded; any key in the file that didn't survive the round trip is unknown.
    static func unknownKeyIssues<T: Encodable>(original: Any, decoded: T) -> [ContentIssue] {
        guard let data = try? JSONEncoder().encode(decoded),
              let canonical = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var issues: [ContentIssue] = []
        walk(original, canonical, path: [], raw: original, into: &issues)
        return issues
    }

    private static func walk(_ o: Any, _ c: Any, path: [PathComponent], raw: Any, into issues: inout [ContentIssue]) {
        if let od = o as? [String: Any], let cd = c as? [String: Any] {
            for key in od.keys.sorted() {
                if let cv = cd[key] {
                    walk(od[key]!, cv, path: path + key, raw: raw, into: &issues)
                } else if od[key] is NSNull {
                    issues.append(ContentIssue(.error, JSONPath.describe(path + key, raw: raw),
                                        "is null; remove the key or give it a value"))
                } else {
                    let allowed = "unknown key '\(key)'"
                    issues.append(ContentIssue(.error, JSONPath.describe(path, raw: raw).nonEmpty(or: "top level"),
                                        allowed + suggestion(for: key, near: Array(cd.keys))))
                }
            }
        } else if let oa = o as? [Any], let ca = c as? [Any] {
            for (i, pair) in zip(oa, ca).enumerated() {
                walk(pair.0, pair.1, path: path + i, raw: raw, into: &issues)
            }
        }
    }

    /// " (did you mean 'headline'?)" when a known key is a near-miss.
    private static func suggestion(for key: String, near known: [String]) -> String {
        let best = known.map { ($0, editDistance(key.lowercased(), $0.lowercased())) }.min { $0.1 < $1.1 }
        if let best, best.1 <= 2 { return " (did you mean '\(best.0)'?)" }
        return ""
    }

    // MARK: Decoding errors → readable messages

    static func describe(_ error: DecodingError, raw: Any) -> ContentIssue {
        switch error {
        case .keyNotFound(let key, let ctx):
            let path = JSONPath.components(from: ctx.codingPath)
            var message = "missing required key '\(key.stringValue)'"
            // Point at a likely typo sitting in the same object.
            if let object = JSONPath.value(at: path, in: raw) as? [String: Any] {
                let near = object.keys.filter { editDistance($0.lowercased(), key.stringValue.lowercased()) <= 2 }
                if let typo = near.first { message += " (found '\(typo)': a typo?)" }
            }
            return ContentIssue(.error, JSONPath.describe(path, raw: raw).nonEmpty(or: "top level"), message)

        case .typeMismatch(let type, let ctx):
            let path = JSONPath.components(from: ctx.codingPath)
            let found = JSONPath.value(at: path, in: raw).map(jsonTypeName) ?? "something else"
            return ContentIssue(.error, JSONPath.describe(path, raw: raw),
                         "wrong type: expected \(swiftTypeName(type)), found \(found)")

        case .valueNotFound(let type, let ctx):
            let path = JSONPath.components(from: ctx.codingPath)
            return ContentIssue(.error, JSONPath.describe(path, raw: raw),
                         "is null; expected \(swiftTypeName(type))")

        case .dataCorrupted(let ctx):
            let path = JSONPath.components(from: ctx.codingPath)
            return ContentIssue(.error, JSONPath.describe(path, raw: raw), friendlyCorruption(ctx.debugDescription, path: path, raw: raw))

        @unknown default:
            return ContentIssue(.error, "", String(describing: error))
        }
    }

    /// Turns "Cannot initialize DiagramLayout from invalid String value rows" into
    /// "invalid value 'rows'. Expected one of: row, column, cycle, grid, free".
    private static func friendlyCorruption(_ message: String, path: [PathComponent], raw: Any) -> String {
        guard message.hasPrefix("Cannot initialize") else { return message }
        let typeName = message.split(separator: " ").dropFirst(2).first.map(String.init) ?? ""
        let value = JSONPath.value(at: path, in: raw).map { "\($0)" } ?? "?"
        if let allowed = allowedValues[typeName] {
            return "invalid value '\(value)'. Expected one of: \(allowed.joined(separator: ", "))"
        }
        return "invalid value '\(value)'"
    }

    private static let allowedValues: [String: [String]] = {
        func names<E: CaseIterable & RawRepresentable>(_ e: E.Type) -> (String, [String]) where E.RawValue == String {
            (String(describing: e), e.allCases.map(\.rawValue))
        }
        return Dictionary(uniqueKeysWithValues: [
            names(SourceKind.self), names(QuestionKind.self), names(SectionType.self), names(TextVisualLayout.self),
            names(TimelineScale.self), names(StepsStyle.self), names(ChartKind.self), names(DataKind.self),
            names(ColorToken.self), names(VisualKind.self), names(DiagramLayout.self), names(NodeStyle.self),
            names(EdgeStyle.self), names(ShapeKind.self), names(TextSize.self), names(LayersDirection.self),
        ])
    }()

    private static func swiftTypeName(_ type: Any.Type) -> String {
        switch type {
        case is String.Type: return "text (a string)"
        case is Int.Type: return "a whole number"
        case is Double.Type: return "a number"
        case is Bool.Type: return "true/false"
        default:
            let name = String(describing: type)
            if name.hasPrefix("Array") { return "a list [ … ]" }
            if name.hasPrefix("Dictionary") { return "an object { … }" }
            return name
        }
    }

    private static func jsonTypeName(_ value: Any) -> String {
        switch value {
        case is String: "text \"\(value)\""
        case let n as NSNumber: CFGetTypeID(n) == CFBooleanGetTypeID() ? "true/false" : "the number \(n)"
        case is [Any]: "a list"
        case is [String: Any]: "an object"
        case is NSNull: "null"
        default: "\(type(of: value))"
        }
    }

    private static func jsonSyntaxMessage(_ error: Error) -> String {
        let ns = error as NSError
        return (ns.userInfo["NSDebugDescription"] as? String) ?? ns.localizedDescription
    }

    // MARK: Files

    static func jsonFiles(under dir: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.path < $1.path }
    }

    private static func relativePath(of url: URL, to root: URL) -> String {
        let r = root.standardizedFileURL.resolvingSymlinksInPath().path
        let p = url.standardizedFileURL.resolvingSymlinksInPath().path
        return p.hasPrefix(r + "/") ? String(p.dropFirst(r.count + 1)) : url.lastPathComponent
    }
}

// MARK: - Helpers

extension String {
    func nonEmpty(or fallback: String) -> String { isEmpty ? fallback : self }
}

/// Levenshtein distance, for "did you mean" hints. Strings here are short keys.
func editDistance(_ a: String, _ b: String) -> Int {
    let a = Array(a), b = Array(b)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }
    var prev = Array(0...b.count)
    for i in 1...a.count {
        var cur = [i] + Array(repeating: 0, count: b.count)
        for j in 1...b.count {
            cur[j] = Swift.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
        }
        prev = cur
    }
    return prev[b.count]
}
