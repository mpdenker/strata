import Foundation

/// Rules a lesson must follow beyond "the JSON decodes" (SPEC.md §6.8).
/// Errors reject the file; warnings are printed but the lesson still loads.
public enum LessonValidator {
    public struct Finding: Sendable, Hashable {
        public var severity: ContentIssue.Severity
        public var path: [PathComponent]
        public var message: String
    }

    public static let sectionRange = 15...25
    public static let minutesRange = 10...15
    public static let sourcesRange = 2...4
    public static let finalQuizCount = 5
    public static let checkQuestionsRange = 1...2
    public static let maxNonPublicDomainQuoteWords = 25
    public static let bodyWordsWarning = 80

    public static func validate(_ lesson: Lesson, topicIDs: Set<String>) -> [Finding] {
        var f = Findings()
        let root: [PathComponent] = []

        // Top level
        if lesson.schemaVersion != 1 { f.error(root + "schemaVersion", "must be 1 (found \(lesson.schemaVersion))") }
        if lesson.id.range(of: #"^[a-z0-9]+(-[a-z0-9]+)*$"#, options: .regularExpression) == nil {
            f.error(root + "id", "'\(lesson.id)' must be kebab-case: lowercase letters, digits and hyphens")
        }
        if !topicIDs.contains(lesson.topic) {
            f.error(root + "topic", "'\(lesson.topic)' isn't in topics.json. Expected one of: \(topicIDs.sorted().joined(separator: ", "))")
        }
        if lesson.order < 1 { f.error(root + "order", "must be 1 or more") }
        if lesson.title.isBlank || lesson.title.count > 50 { f.error(root + "title", "must be 1–50 characters (has \(lesson.title.count))") }
        if lesson.goal.isBlank || lesson.goal.count > 120 { f.error(root + "goal", "must be 1–120 characters (has \(lesson.goal.count))") }
        if !minutesRange.contains(lesson.minutes) { f.error(root + "minutes", "must be \(minutesRange.lowerBound)–\(minutesRange.upperBound) (found \(lesson.minutes))") }
        if let fc = lesson.factCheck {
            if !fc.checkedOn.isISODate { f.error(root + "factCheck" + "checkedOn", "'\(fc.checkedOn)' must be YYYY-MM-DD") }
        } else {
            f.warning(root + "factCheck", "missing: add it after the accuracy pass")
        }

        // Sources
        let sourceIDs = Set(lesson.sources.map(\.id))
        if !sourcesRange.contains(lesson.sources.count) {
            f.error(root + "sources", "has \(lesson.sources.count) sources, needs \(sourcesRange.lowerBound)–\(sourcesRange.upperBound)")
        }
        f.checkUnique(lesson.sources.map(\.id), at: root + "sources", what: "source id")
        for (i, s) in lesson.sources.enumerated() {
            if s.title.isBlank { f.error(root + "sources" + i + "title", "is empty") }
            if let url = s.url, URL(string: url)?.scheme?.hasPrefix("http") != true {
                f.error(root + "sources" + i + "url", "'\(url)' must be an http(s) URL")
            }
            if let a = s.accessed, !a.isISODate { f.error(root + "sources" + i + "accessed", "'\(a)' must be YYYY-MM-DD") }
        }

        // Sections
        let sections = lesson.sections
        if !sectionRange.contains(sections.count) {
            f.error(root + "sections", "has \(sections.count) sections, needs \(sectionRange.lowerBound)–\(sectionRange.upperBound)")
        }
        if let first = sections.first, first.type != .hook { f.error(root + "sections" + 0, "the first section must be a hook (found \(first.type.rawValue))") }
        if let last = sections.last, last.type != .recap { f.error(root + "sections" + (sections.count - 1), "the last section must be a recap (found \(last.type.rawValue))") }
        if !sections.contains(where: { $0.type == .check }) { f.error(root + "sections", "needs at least one check section") }
        f.checkUnique(sections.map(\.id), at: root + "sections", what: "section id")

        var questionIDs: [String] = []
        for (i, section) in sections.enumerated() {
            let p = root + "sections" + i
            f.checkRefs(section.sourceRefs, known: sourceIDs, at: p + "sourceRefs")
            if let c = section.contested, c.note.isBlank { f.error(p + "contested" + "note", "is empty") }
            validateBody(section, at: p, findings: &f, questionIDs: &questionIDs, sourceIDs: sourceIDs)
        }

        // Final quiz
        if lesson.finalQuiz.count != finalQuizCount {
            f.error(root + "finalQuiz", "has \(lesson.finalQuiz.count) questions, needs exactly \(finalQuizCount)")
        }
        for (i, q) in lesson.finalQuiz.enumerated() {
            validateQuestion(q, at: root + "finalQuiz" + i, findings: &f, sourceIDs: sourceIDs)
            questionIDs.append(q.id)
        }
        f.checkUnique(questionIDs, at: root, what: "question id (checks + finalQuiz)")

        return f.items
    }

    // MARK: Section bodies

    private static func validateBody(_ section: LessonSection, at p: [PathComponent], findings f: inout Findings,
                                     questionIDs: inout [String], sourceIDs: Set<String>) {
        let cited = !(section.sourceRefs ?? []).isEmpty
        var texts: [String] = []           // visible text, scanned for unsourced numbers

        switch section.body {
        case .hook(let h):
            f.notBlank(h.headline, p + "headline"); f.notBlank(h.body, p + "body")
            f.wordWarning(h.body, p + "body")
            texts += [h.headline, h.body]
            if let v = h.visual { texts += validateVisual(v, at: p + "visual", findings: &f) }

        case .textVisual(let t):
            f.notBlank(t.body, p + "body")
            f.wordWarning(t.body, p + "body")
            texts += [t.heading ?? "", t.body]
            texts += validateVisual(t.visual, at: p + "visual", findings: &f)

        case .keyIdea(let k):
            f.notBlank(k.statement, p + "statement")
            if let b = k.body { f.wordWarning(b, p + "body") }
            texts += [k.statement, k.body ?? ""]

        case .comparison(let c):
            if !(2...3).contains(c.columns.count) { f.error(p + "columns", "needs 2–3 columns (found \(c.columns.count))") }
            if c.rows.isEmpty { f.error(p + "rows", "needs at least one row") }
            for (i, row) in c.rows.enumerated() where row.values.count != c.columns.count {
                f.error(p + "rows" + i + "values", "has \(row.values.count) values but there are \(c.columns.count) columns")
            }
            texts += c.rows.flatMap { [$0.label] + $0.values } + [c.takeaway ?? ""]

        case .timeline(let t):
            if t.events.count < 2 { f.error(p + "events", "needs at least 2 events") }
            if !cited { f.warning(p, "timeline has dates but no sourceRefs") }

        case .steps(let s):
            if s.steps.count < 2 { f.error(p + "steps", "needs at least 2 steps") }
            if s.style == .cycle && s.steps.count > 8 { f.warning(p + "steps", "cycles with more than 8 steps get cramped") }
            texts += s.steps.flatMap { [$0.title, $0.body ?? ""] }

        case .chart(let c):
            if c.series.isEmpty { f.error(p + "series", "needs at least one series") }
            for (i, s) in c.series.enumerated() where s.points.isEmpty {
                f.error(p + "series" + i + "points", "is empty")
            }
            if c.dataKind == .sourced && !cited { f.error(p + "sourceRefs", "a chart with dataKind 'sourced' must cite its source") }
            f.notBlank(c.dataNote, p + "dataNote")
            f.notBlank(c.caption, p + "caption")

        case .quote(let q):
            f.notBlank(q.text, p + "text")
            if !cited { f.error(p + "sourceRefs", "quotes must cite a source") }
            let words = q.text.wordCount
            if !q.publicDomain && words > maxNonPublicDomainQuoteWords {
                f.error(p + "text", "not public domain and \(words) words (max \(maxNonPublicDomainQuoteWords))")
            }

        case .check(let c):
            if !checkQuestionsRange.contains(c.questions.count) {
                f.error(p + "questions", "has \(c.questions.count) questions, needs \(checkQuestionsRange.lowerBound)–\(checkQuestionsRange.upperBound)")
            }
            for (i, q) in c.questions.enumerated() {
                validateQuestion(q, at: p + "questions" + i, findings: &f, sourceIDs: sourceIDs)
                questionIDs.append(q.id)
            }

        case .recap(let r):
            if r.bullets.count != 3 { f.error(p + "bullets", "needs exactly 3 bullets (found \(r.bullets.count))") }
            for (i, b) in r.bullets.enumerated() { f.notBlank(b, p + "bullets" + i) }
        }

        if let c = section.computed, c.isBlank { f.error(p + "computed", "is empty") }
        if !cited && section.computed == nil && texts.contains(where: \.hasDigit) {
            f.warning(p, "contains numbers but no sourceRefs (cite a source, or add \"computed\" if they are worked math)")
        }
    }

    // MARK: Visuals

    /// Returns visible text that should be backed by a source if it has numbers.
    private static func validateVisual(_ v: Visual, at p: [PathComponent], findings f: inout Findings) -> [String] {
        f.notBlank(v.accessibilityLabel, p + "accessibilityLabel")
        switch v.body {
        case .diagram(let d):
            if d.nodes.isEmpty { f.error(p + "nodes", "needs at least one node") }
            f.checkUnique(d.nodes.map(\.id), at: p + "nodes", what: "node id")
            let ids = Set(d.nodes.map(\.id))
            for (i, e) in (d.edges ?? []).enumerated() {
                if !ids.contains(e.from) { f.error(p + "edges" + i + "from", "'\(e.from)' isn't a node id") }
                if !ids.contains(e.to) { f.error(p + "edges" + i + "to", "'\(e.to)' isn't a node id") }
            }
            if d.layout == .free {
                for (i, n) in d.nodes.enumerated() {
                    guard let x = n.x, let y = n.y, (0...1).contains(x), (0...1).contains(y) else {
                        f.error(p + "nodes" + i, "layout 'free' needs x and y between 0 and 1"); continue
                    }
                }
            }
            return d.nodes.flatMap { [$0.label, $0.detail ?? ""] } + (d.edges ?? []).compactMap(\.label)

        case .shapes(let s):
            if s.aspectRatio <= 0 { f.error(p + "aspectRatio", "must be greater than 0") }
            for (i, item) in s.items.enumerated() {
                let ip = p + "items" + i
                let need: [String]
                switch item.shape {
                case .rect: need = ["x", "y", "w", "h"]
                case .circle: need = ["x", "y", "r"]
                case .polygon, .line: need = ["points"]
                case .text: need = ["x", "y", "text"]
                case .symbol: need = ["x", "y", "name"]
                }
                let have: [String: Bool] = [
                    "x": item.x != nil, "y": item.y != nil, "w": item.w != nil, "h": item.h != nil,
                    "r": item.r != nil, "points": item.points != nil, "text": item.text != nil, "name": item.name != nil,
                ]
                for key in need where have[key] != true { f.error(ip, "\(item.shape.rawValue) needs '\(key)'") }
                if let pts = item.points {
                    if pts.count < 2 { f.error(ip + "points", "needs at least 2 points") }
                    for (j, pt) in pts.enumerated() where pt.count != 2 {
                        f.error(ip + "points" + j, "each point is [x, y]")
                    }
                }
                let coords = [item.x, item.y, item.w, item.h].compactMap { $0 } + (item.points ?? []).flatMap { $0 }
                if coords.contains(where: { $0 < -0.05 || $0 > 1.05 }) {
                    f.error(ip, "coordinates must be between 0 and 1 (fractions of the canvas)")
                }
            }
            return s.items.compactMap(\.text)

        case .iconArray(let a):
            if a.total < 1 || a.total > 200 { f.error(p + "total", "must be 1–200") }
            if a.columns < 1 { f.error(p + "columns", "must be 1 or more") }
            let sum = a.groups.reduce(0) { $0 + $1.count }
            if sum > a.total { f.error(p + "groups", "group counts add up to \(sum), more than total \(a.total)") }
            return a.groups.map(\.label) + ["\(a.total)"]

        case .formula(let fm):
            if fm.parts.isEmpty { f.error(p + "parts", "needs at least one part") }
            return []   // formulas are math, not claims

        case .bigNumber(let b):
            if (b.dataKind == .computed || b.dataKind == .illustrative) && (b.dataNote ?? "").isBlank {
                f.error(p + "dataNote", "a \(b.dataKind!.rawValue) number must explain itself in dataNote")
            }
            return b.dataKind == nil || b.dataKind == .sourced ? [b.formatted(), b.label] : []

        case .layers(let l):
            if l.layers.count < 2 { f.error(p + "layers", "needs at least 2 layers") }
            return l.layers.flatMap { [$0.label, $0.detail ?? ""] }

        case .symbol(let s):
            f.notBlank(s.name, p + "name")
            return [s.caption ?? ""]
        }
    }

    // MARK: Questions

    private static func validateQuestion(_ q: Question, at p: [PathComponent], findings f: inout Findings, sourceIDs: Set<String>) {
        f.notBlank(q.prompt, p + "prompt")
        f.notBlank(q.explanation, p + "explanation")
        f.checkRefs(q.sourceRefs, known: sourceIDs, at: p + "sourceRefs")
        switch (q.kind, q.answer) {
        case (.multipleChoice, .index(let i)):
            let choices = q.choices ?? []
            if !(2...4).contains(choices.count) { f.error(p + "choices", "multiple choice needs 2–4 choices (found \(choices.count))") }
            if !choices.indices.contains(i) { f.error(p + "answer", "\(i) is not a valid choice index (0–\(max(0, choices.count - 1)))") }
            if Set(choices).count != choices.count { f.error(p + "choices", "choices must be different from each other") }
            for (j, c) in choices.enumerated() { f.notBlank(c, p + "choices" + j) }
        case (.multipleChoice, .bool):
            f.error(p + "answer", "multiple choice needs a choice index, not true/false")
        case (.trueFalse, .bool):
            if q.choices != nil { f.error(p + "choices", "true/false questions don't take choices") }
        case (.trueFalse, .index):
            f.error(p + "answer", "true/false questions need answer true or false")
        }
    }
}

// MARK: - Helpers

private struct Findings {
    var items: [LessonValidator.Finding] = []

    mutating func error(_ path: [PathComponent], _ message: String) { items.append(.init(severity: .error, path: path, message: message)) }
    mutating func warning(_ path: [PathComponent], _ message: String) { items.append(.init(severity: .warning, path: path, message: message)) }

    mutating func notBlank(_ s: String, _ path: [PathComponent]) { if s.isBlank { error(path, "is empty") } }

    mutating func wordWarning(_ s: String, _ path: [PathComponent]) {
        let n = s.wordCount
        if n > LessonValidator.bodyWordsWarning { warning(path, "is \(n) words (aim for 60 or fewer)") }
    }

    mutating func checkUnique(_ ids: [String], at path: [PathComponent], what: String) {
        var seen = Set<String>()
        for id in ids where !seen.insert(id).inserted { error(path, "duplicate \(what) '\(id)'") }
    }

    mutating func checkRefs(_ refs: [String]?, known: Set<String>, at path: [PathComponent]) {
        for r in refs ?? [] where !known.contains(r) {
            error(path, "'\(r)' doesn't match any source id (\(known.sorted().joined(separator: ", ")))")
        }
    }
}

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var wordCount: Int { split { $0.isWhitespace }.count }
    var hasDigit: Bool { contains { $0.isNumber } }
    var isISODate: Bool { range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil }
}
