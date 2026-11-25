import Foundation

// The shapes of the JSON content files. See SPEC.md §6 for the field-by-field rules.
// Everything is a value type and Sendable, so it can be loaded off the main thread and shared freely.

// MARK: - topics.json

public struct TopicsFile: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var topics: [Topic]
}

public struct Topic: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var symbol: String          // SF Symbol name
    public var order: Int
    public var color: HexPair          // light / dark mode fill color, e.g. "#D9573B"
    /// Optional line shown at the top of every lesson in this topic (e.g. "Educational, not financial advice.").
    public var note: String?

    public init(id: String, name: String, symbol: String, order: Int, color: HexPair, note: String? = nil) {
        self.id = id; self.name = name; self.symbol = symbol; self.order = order; self.color = color; self.note = note
    }
}

public struct HexPair: Codable, Sendable, Hashable {
    public var light: String
    public var dark: String
    public init(light: String, dark: String) { self.light = light; self.dark = dark }
}

// MARK: - Lesson file

public struct Lesson: Codable, Sendable, Hashable, Identifiable {
    public var schemaVersion: Int
    public var id: String
    public var topic: String
    public var order: Int
    public var title: String
    public var goal: String
    public var minutes: Int
    public var contentVersion: Int
    public var sections: [LessonSection]
    public var finalQuiz: [Question]
    public var sources: [Source]
    public var factCheck: FactCheck?

    /// Every question in the lesson (inline checks first, then the final quiz), with its global ID.
    public var allQuestions: [(globalID: String, question: Question)] {
        var result: [(String, Question)] = []
        for section in sections {
            if case .check(let check) = section.body {
                result += check.questions.map { (Question.globalID(lessonID: id, localID: $0.id), $0) }
            }
        }
        result += finalQuiz.map { (Question.globalID(lessonID: id, localID: $0.id), $0) }
        return result
    }

    public func source(_ id: String) -> Source? { sources.first { $0.id == id } }
}

public struct FactCheck: Codable, Sendable, Hashable {
    public var checkedOn: String       // YYYY-MM-DD
    public var notes: String
}

public struct Contested: Codable, Sendable, Hashable {
    public var note: String
}

// MARK: - Sources

public enum SourceKind: String, Codable, Sendable, Hashable, CaseIterable {
    case textbook, journal, encyclopedia, university, government, organization, primary, book, standard
}

public struct Source: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var kind: SourceKind
    public var title: String
    public var authors: String?
    public var publisher: String?
    public var year: String?           // a string so "c. 125" or "1776–89" work
    public var locator: String?        // "Ch. 7", "§125", "Book 2"
    public var url: String?
    public var accessed: String?       // YYYY-MM-DD

    /// A one-line citation, e.g. "Spielman et al., Psychology 2e (OpenStax, 2020), Ch. 7."
    public var citation: String {
        var parts: [String] = []
        if let authors, !authors.isEmpty { parts.append(authors + ",") }
        parts.append(title)
        let pubYear = [publisher, year].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        if !pubYear.isEmpty { parts.append("(\(pubYear))") }
        var line = parts.joined(separator: " ")
        if let locator, !locator.isEmpty { line += ", \(locator)" }
        return line + "."
    }
}

// MARK: - Questions

public enum QuestionKind: String, Codable, Sendable, Hashable, CaseIterable {
    case multipleChoice, trueFalse
}

/// The correct answer: a choice index for multiple choice, or true/false.
public enum Answer: Codable, Sendable, Hashable {
    case index(Int)
    case bool(Bool)

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .index(i); return }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "answer must be a choice index (number) or true/false")
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .index(let i): try c.encode(i)
        case .bool(let b): try c.encode(b)
        }
    }
}

public struct Question: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var kind: QuestionKind
    public var prompt: String
    public var choices: [String]?
    public var answer: Answer
    public var explanation: String
    public var sourceRefs: [String]?

    /// The ID review cards are keyed on: "<lessonID>.<questionID>".
    public static func globalID(lessonID: String, localID: String) -> String { "\(lessonID).\(localID)" }

    /// The options to show, in file order. True/false questions get ["True", "False"].
    public var displayChoices: [String] {
        switch kind {
        case .trueFalse: return ["True", "False"]
        case .multipleChoice: return choices ?? []
        }
    }

    /// The text of the correct option (choices are shuffled on screen, so answers are checked by text).
    public var correctChoiceText: String? {
        switch (kind, answer) {
        case (.trueFalse, .bool(let b)): return b ? "True" : "False"
        case (.multipleChoice, .index(let i)):
            guard let choices, choices.indices.contains(i) else { return nil }
            return choices[i]
        default: return nil
        }
    }

    public func isCorrect(choiceText: String) -> Bool { choiceText == correctChoiceText }
}
