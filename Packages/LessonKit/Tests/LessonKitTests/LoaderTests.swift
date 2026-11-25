import Foundation
import Testing
@testable import LessonKit

// Sections in the fixture, by index:
// 0 hook · 1 diagram · 2 shapes · 3 icons · 4 formula · 5 layers · 6 symbol · 7 key · 8 compare
// 9 timeline · 10 steps · 11 chart · 12 quote · 13 check1 · 14 recap

let topicIDs: Set<String> = ["psychology", "science", "finance", "history", "philosophy"]

func fixtureData() throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "valid-lesson", withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

/// Load the fixture, apply a change to its JSON, and run it through the loader.
func load(_ change: (NSMutableDictionary) -> Void = { _ in }) throws -> FileReport {
    let root = try JSONSerialization.jsonObject(with: fixtureData(), options: .mutableContainers) as! NSMutableDictionary
    change(root)
    let data = try JSONSerialization.data(withJSONObject: root)
    return ContentLoader.loadLesson(data: data, file: "fixture.json", topicIDs: topicIDs)
}

func section(_ root: NSMutableDictionary, _ i: Int) -> NSMutableDictionary {
    (root["sections"] as! NSMutableArray)[i] as! NSMutableDictionary
}

func visual(_ root: NSMutableDictionary, _ i: Int) -> NSMutableDictionary {
    section(root, i)["visual"] as! NSMutableDictionary
}

/// The single error the report should contain.
func onlyError(_ r: FileReport, sourceLocation: SourceLocation = #_sourceLocation) throws -> ContentIssue {
    #expect(r.lesson == nil, "a file with errors must not load", sourceLocation: sourceLocation)
    return try #require(r.errors.first, sourceLocation: sourceLocation)
}

@Suite("Loading a valid lesson")
struct ValidLessonTests {
    @Test func loadsWithNoIssues() throws {
        let r = try load()
        #expect(r.issues.isEmpty, "\(r.issues)")
        let lesson = try #require(r.lesson)
        #expect(lesson.sections.count == 15)
        #expect(lesson.allQuestions.count == 7)
        #expect(lesson.allQuestions.first?.globalID == "test-every-type.c1q1")
    }

    @Test func fixtureCoversEverySectionAndVisualKind() throws {
        let lesson = try #require(try load().lesson)
        #expect(Set(lesson.sections.map(\.type)) == Set(SectionType.allCases))
        var kinds = Set<VisualKind>()
        for s in lesson.sections {
            switch s.body {
            case .hook(let h): if let v = h.visual { kinds.insert(v.kind) }
            case .textVisual(let t): kinds.insert(t.visual.kind)
            default: break
            }
        }
        #expect(kinds == Set(VisualKind.allCases))
    }

    @Test func encodeDecodeRoundTripIsLossless() throws {
        let lesson = try #require(try load().lesson)
        let again = try JSONDecoder().decode(Lesson.self, from: JSONEncoder().encode(lesson))
        #expect(again == lesson)
    }

    @Test func answersDecodeAsIndexOrBool() throws {
        let lesson = try #require(try load().lesson)
        guard case .check(let check) = lesson.sections[13].body else { Issue.record("expected check"); return }
        #expect(check.questions[0].answer == .bool(false))
        #expect(check.questions[1].answer == .index(2))
        #expect(check.questions[1].correctChoiceText == "Retrieval")
        #expect(check.questions[0].isCorrect(choiceText: "False"))
    }

    @Test func chartXAcceptsNumbersAndLabels() throws {
        let data = Data(#"[{"x": 1928, "y": 1}, {"x": "1932", "y": 2}]"#.utf8)
        let pts = try JSONDecoder().decode([ChartPoint].self, from: data)
        #expect(pts[0].x == .number(1928))
        #expect(pts[1].x == .label("1932"))
    }

    @Test func citationReadsNaturally() throws {
        let lesson = try #require(try load().lesson)
        #expect(lesson.sources[0].citation == "Spielman, R. M., et al., Psychology 2e (OpenStax, 2020), Ch. 8.")
    }
}

@Suite("Clear errors for bad JSON")
struct BadJSONTests {
    @Test func malformedJSON() {
        let r = ContentLoader.loadLesson(data: Data(#"{ "id": "x" "#.utf8), file: "bad.json", topicIDs: topicIDs)
        #expect(r.lesson == nil)
        #expect(r.errors.first?.message.hasPrefix("not valid JSON") == true)
    }

    @Test func missingKeyNamesTheSection() throws {
        let e = try onlyError(try load { section($0, 9).removeObject(forKey: "events") })
        #expect(e.location == #"sections[9] (timeline "timeline")"#)
        #expect(e.message == "missing required key 'events'")
    }

    @Test func typoInKeyIsPointedOut() throws {
        let e = try onlyError(try load {
            let s = section($0, 0); s["headlin"] = s["headline"]; s.removeObject(forKey: "headline")
        })
        #expect(e.message.contains("missing required key 'headline'"))
        #expect(e.message.contains("'headlin'"))
    }

    @Test func extraUnknownKeyIsAnError() throws {
        let e = try onlyError(try load { section($0, 7)["colour"] = "red" })
        #expect(e.location == #"sections[7] (keyIdea "key")"#)
        #expect(e.message.contains("unknown key 'colour'"))
    }

    @Test func unknownKeyGetsDidYouMean() throws {
        let e = try onlyError(try load { section($0, 9)["scales"] = "even" })
        #expect(e.message.contains("did you mean 'scale'"))
    }

    @Test func unknownSectionTypeListsAllowedTypes() throws {
        let e = try onlyError(try load { section($0, 11)["type"] = "chrat" })
        #expect(e.location.hasPrefix("sections[11]"))
        #expect(e.message.contains("unknown section type 'chrat'"))
        #expect(e.message.contains("timeline"))
    }

    @Test func invalidEnumValueListsAllowedValues() throws {
        let e = try onlyError(try load { visual($0, 1)["layout"] = "rows" })
        #expect(e.location.contains("visual.layout"))
        #expect(e.message.contains("'rows'"))
        #expect(e.message.contains("row, column, cycle, grid, free"))
    }

    @Test func wrongTypeSaysWhatWasExpected() throws {
        let e = try onlyError(try load { $0["minutes"] = "ten" })
        #expect(e.location == "minutes")
        #expect(e.message.contains("expected a whole number"))
        #expect(e.message.contains("\"ten\""))
    }

    @Test func nullValueIsRejected() throws {
        let e = try onlyError(try load { section($0, 7)["body"] = NSNull() })
        #expect(e.message.contains("null"))
    }
}

@Suite("Lesson rules")
struct RuleTests {
    @Test func finalQuizNeedsFive() throws {
        let e = try onlyError(try load { ($0["finalQuiz"] as! NSMutableArray).removeLastObject() })
        #expect(e.message == "has 4 questions, needs exactly 5")
    }

    @Test func sectionCountRange() throws {
        let e = try onlyError(try load { ($0["sections"] as! NSMutableArray).removeObject(at: 8) })
        #expect(e.message.contains("has 14 sections, needs 15–25"))
    }

    @Test func mustStartWithHookAndEndWithRecap() throws {
        let r = try load { root in
            let arr = root["sections"] as! NSMutableArray
            arr.exchangeObject(at: 0, withObjectAt: 7)
        }
        #expect(r.errors.contains { $0.message.contains("first section must be a hook") })
    }

    @Test func sourceRefsMustResolve() throws {
        let e = try onlyError(try load { section($0, 1)["sourceRefs"] = ["s9"] })
        #expect(e.message.contains("'s9' doesn't match any source id"))
    }

    @Test func edgesMustPointAtNodes() throws {
        let e = try onlyError(try load {
            ((visual($0, 1)["edges"] as! NSMutableArray)[0] as! NSMutableDictionary)["to"] = "zzz"
        })
        #expect(e.location.hasSuffix("visual.edges[0].to"))
    }

    @Test func answerIndexInRange() throws {
        let e = try onlyError(try load {
            ((section($0, 13)["questions"] as! NSMutableArray)[1] as! NSMutableDictionary)["answer"] = 7
        })
        #expect(e.message.contains("not a valid choice index"))
    }

    @Test func trueFalseNeedsBool() throws {
        let e = try onlyError(try load {
            ((section($0, 13)["questions"] as! NSMutableArray)[0] as! NSMutableDictionary)["answer"] = 1
        })
        #expect(e.message.contains("true or false"))
    }

    @Test func longCopyrightedQuoteRejected() throws {
        let e = try onlyError(try load {
            let q = section($0, 12)
            q["publicDomain"] = false
            q["text"] = Array(repeating: "word", count: 31).joined(separator: " ")
        })
        #expect(e.message == "not public domain and 31 words (max 25)")
    }

    @Test func recapNeedsThreeBullets() throws {
        let e = try onlyError(try load { ($0["sections"] as! NSMutableArray)[14] = ["id": "recap", "type": "recap", "bullets": ["a", "b"]] })
        #expect(e.message.contains("exactly 3 bullets"))
    }

    @Test func checkNeedsOneOrTwoQuestions() throws {
        let e = try onlyError(try load { section($0, 13)["questions"] = [] as [Any] })
        #expect(e.message.contains("needs 1–2"))
    }

    @Test func duplicateQuestionIDs() throws {
        let e = try onlyError(try load {
            (($0["finalQuiz"] as! NSMutableArray)[0] as! NSMutableDictionary)["id"] = "c1q1"
        })
        #expect(e.message.contains("duplicate question id"))
    }

    @Test func sourcedChartNeedsSource() throws {
        let e = try onlyError(try load { section($0, 11).removeObject(forKey: "sourceRefs") })
        #expect(e.message.contains("must cite its source"))
    }

    @Test func unknownTopic() throws {
        let e = try onlyError(try load { $0["topic"] = "cooking" })
        #expect(e.message.contains("isn't in topics.json"))
    }

    @Test func unsourcedNumbersAreAWarningNotAnError() throws {
        let r = try load { section($0, 7)["statement"] = "About 86 billion neurons." }
        #expect(r.lesson != nil)
        #expect(r.errors.isEmpty)
        #expect(r.warnings.count == 1)
        #expect(r.warnings.first?.message.hasPrefix("contains numbers but no sourceRefs") == true)
    }

    @Test func computedSectionsMayHaveNumbersWithoutSources() throws {
        let r = try load { s in
            let k = section(s, 7)
            k["statement"] = "1,000 dollars at 7% for 40 years."
            k["computed"] = "1,000 × 1.07^40"
        }
        #expect(r.issues.isEmpty, "\(r.issues)")
    }

    @Test func longBodyIsAWarning() throws {
        let r = try load { section($0, 1)["body"] = Array(repeating: "word", count: 90).joined(separator: " ") }
        #expect(r.lesson != nil)
        #expect(r.warnings.first?.message == "is 90 words (aim for 60 or fewer)")
    }
}

@Suite("Loading a folder")
struct FolderTests {
    @Test func badFilesAreSkippedGoodFilesLoad() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let lessons = dir.appendingPathComponent("Lessons/science")
        try FileManager.default.createDirectory(at: lessons, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try FileManager.default.copyItem(at: repoRoot.appendingPathComponent("Content/topics.json"),
                                         to: dir.appendingPathComponent("topics.json"))
        try fixtureData().write(to: lessons.appendingPathComponent("a.json"))
        try fixtureData().write(to: lessons.appendingPathComponent("b-duplicate.json"))   // same id + order
        try Data("not json".utf8).write(to: lessons.appendingPathComponent("c-broken.json"))

        let report = ContentLoader.load(contentRoot: dir)
        #expect(report.topics.count == 5)
        #expect(report.lessons.map(\.id) == ["test-every-type"])
        #expect(report.failedFiles.map(\.file) == ["Lessons/science/b-duplicate.json", "Lessons/science/c-broken.json"])
        let dup = report.failedFiles[0].errors.map(\.message)
        #expect(dup.contains { $0.contains("already used by Lessons/science/a.json") })
        #expect(dup.contains { $0.contains("already has a lesson with order 99") })
    }

    @Test func missingTopicsFileIsReported() {
        let report = ContentLoader.load(contentRoot: URL(fileURLWithPath: "/nonexistent-\(UUID())"))
        #expect(report.topicsIssues.first?.message.contains("topics.json is missing") == true)
    }
}
