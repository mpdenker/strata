import Foundation

/// One problem found in a content file.
public struct ContentIssue: Sendable, Hashable, CustomStringConvertible {
    public enum Severity: String, Sendable, Hashable { case error, warning }

    public var severity: Severity
    /// Where in the file, e.g. `sections[7] (timeline "arms-race") → events[2].sortKey`. Empty = whole file.
    public var location: String
    public var message: String

    public init(_ severity: Severity, _ location: String, _ message: String) {
        self.severity = severity
        self.location = location
        self.message = message
    }

    public var description: String {
        let mark = severity == .error ? "✗" : "⚠"
        return location.isEmpty ? "\(mark) \(message)" : "\(mark) \(location): \(message)"
    }
}

/// A step in a path through a JSON document.
public enum PathComponent: Sendable, Hashable {
    case key(String)
    case index(Int)
}

extension Array where Element == PathComponent {
    static func + (lhs: [PathComponent], rhs: String) -> [PathComponent] { lhs + [.key(rhs)] }
    static func + (lhs: [PathComponent], rhs: Int) -> [PathComponent] { lhs + [.index(rhs)] }
}

enum JSONPath {
    static func components(from codingPath: [any CodingKey]) -> [PathComponent] {
        codingPath.map { key in
            if let i = key.intValue { .index(i) } else { .key(key.stringValue) }
        }
    }

    /// Plain path: `sections[7].events[2].sortKey`.
    static func plain(_ path: some Collection<PathComponent>) -> String {
        var out = ""
        for c in path {
            switch c {
            case .key(let k): out += out.isEmpty ? k : ".\(k)"
            case .index(let i): out += "[\(i)]"
            }
        }
        return out
    }

    /// Human path: names the section so you can find it in the file:
    /// `sections[7] (timeline "arms-race") → events[2].sortKey`.
    static func describe(_ path: [PathComponent], raw: Any?) -> String {
        guard path.count >= 2, case .key("sections") = path[0], case .index(let i) = path[1] else {
            return plain(path)
        }
        var head = "sections[\(i)]"
        if let root = raw as? [String: Any],
           let sections = root["sections"] as? [Any], sections.indices.contains(i),
           let section = sections[i] as? [String: Any] {
            let type = section["type"] as? String
            let id = section["id"] as? String
            switch (type, id) {
            case let (t?, d?): head += " (\(t) \"\(d)\")"
            case let (t?, nil): head += " (type \"\(t)\")"
            case let (nil, d?): head += " (\"\(d)\")"
            default: break
            }
        }
        let rest = path.dropFirst(2)
        return rest.isEmpty ? head : head + " → " + plain(rest)
    }

    /// The JSON value at `path`, if it exists.
    static func value(at path: [PathComponent], in raw: Any?) -> Any? {
        var current = raw
        for c in path {
            switch c {
            case .key(let k): current = (current as? [String: Any])?[k]
            case .index(let i):
                guard let arr = current as? [Any], arr.indices.contains(i) else { return nil }
                current = arr[i]
            }
        }
        return current
    }
}
