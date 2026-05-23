// PrefixParser.swift
// Parses a quick-add string into a title plus structured fields, recognizing the
// prefix grammar from the design:
//   #folder        → folder slug
//   due:<expr>     → due date (today, tomorrow, weekday, "15 May 2026", 2026-05-15)
//   t:<n><m|h|d>   → effort (10m, 1h, 3d; a day = 8h)
//   i:<h|m|l>      → impact
//   p:<h|m|l>      → priority
// Everything else becomes the title (whitespace collapsed). Pure and
// clock-injectable; folder-slug resolution is the caller's job.

import Foundation

/// A recognized prefix token, in the kind/value shape used for preview chips.
enum PrefixToken: Equatable {
    case folder(slug: String)
    case due(Date)
    case effort(minutes: Int)
    case impact(Level)
    case priority(Level)
}

/// The result of parsing a quick-add string.
struct ParsedQuickAdd: Equatable {
    var title: String = ""
    var folderSlug: String?
    var due: Date?
    var effortMinutes: Int?
    var impact: Level?
    var priority: Level?
    /// Tokens in the order they appeared, for rendering preview chips.
    var tokens: [PrefixToken] = []

    var isEmpty: Bool {
        title.isEmpty && tokens.isEmpty
    }
}

enum PrefixParser {
    // Matches a token at a word boundary. Based on the prototype regex, with a
    // `(?!:)` lookahead on the due-date continuation words so a `due:` argument
    // can't swallow the head of a following prefix token (e.g. the "t" of "t:1h").
    // NSRegularExpression is Sendable, so this shared instance is concurrency-safe.
    private static let regex = try! NSRegularExpression(
        pattern: #"(^|\s)(?:#([a-zA-Z0-9_-]+)|(due):(?:"([^"]+)"|([^\s][^\s]*(?:\s+[a-zA-Z0-9]+(?!:)){0,2}))|(t):(\d+(?:\.\d+)?[mhd])|([ip]):([hml]))"#,
        options: [.caseInsensitive]
    )

    static func parse(_ text: String, clock: TaskClock = TaskClock()) -> ParsedQuickAdd {
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))

        var result = ParsedQuickAdd()
        var removalRanges: [NSRange] = []

        for m in matches {
            let leadLen = m.range(at: 1).length
            let tokenRange = NSRange(
                location: m.range.location + leadLen,
                length: m.range.length - leadLen
            )

            if m.range(at: 2).location != NSNotFound {
                // #folder
                let slug = ns.substring(with: m.range(at: 2))
                result.folderSlug = slug
                result.tokens.append(.folder(slug: slug))
                removalRanges.append(tokenRange)
            } else if m.range(at: 3).location != NSNotFound {
                // due:<expr> — only counts if the date actually parses.
                let argRange = m.range(at: 4).location != NSNotFound ? m.range(at: 4) : m.range(at: 5)
                let arg = ns.substring(with: argRange)
                if let date = parseDate(arg, clock: clock) {
                    result.due = date
                    result.tokens.append(.due(date))
                    removalRanges.append(tokenRange)
                }
            } else if m.range(at: 6).location != NSNotFound {
                // t:<effort>
                if let minutes = parseEffort(ns.substring(with: m.range(at: 7))) {
                    result.effortMinutes = minutes
                    result.tokens.append(.effort(minutes: minutes))
                    removalRanges.append(tokenRange)
                }
            } else if m.range(at: 8).location != NSNotFound {
                // i:/p:<level>
                let kind = ns.substring(with: m.range(at: 8)).lowercased()
                if let level = Level(token: ns.substring(with: m.range(at: 9))) {
                    if kind == "i" {
                        result.impact = level
                        result.tokens.append(.impact(level))
                    } else {
                        result.priority = level
                        result.tokens.append(.priority(level))
                    }
                    removalRanges.append(tokenRange)
                }
            }
        }

        result.title = titleByRemoving(removalRanges, from: ns)
        return result
    }

    /// Reconstruct the title by removing token ranges, then collapsing whitespace.
    private static func titleByRemoving(_ ranges: [NSRange], from ns: NSString) -> String {
        var pieces: [String] = []
        var cursor = 0
        for range in ranges {
            if range.location > cursor {
                pieces.append(ns.substring(with: NSRange(location: cursor, length: range.location - cursor)))
            }
            cursor = range.location + range.length
        }
        if cursor < ns.length {
            pieces.append(ns.substring(from: cursor))
        }
        let joined = pieces.joined()
        return joined
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Effort

    /// "10m" → 10, "1h" → 60, "1.5h" → 90, "3d" → 1440 (8h workday). Nil if invalid.
    static func parseEffort(_ token: String) -> Int? {
        let lower = token.lowercased()
        guard let unit = lower.last, "mhd".contains(unit) else { return nil }
        guard let value = Double(lower.dropLast()) else { return nil }
        switch unit {
        case "m": return Int(value.rounded())
        case "h": return Int((value * 60).rounded())
        default: return Int((value * 60 * 8).rounded()) // "d"
        }
    }

    // MARK: - Dates

    private static let weekdayNames = ["sunday", "monday", "tuesday", "wednesday",
                                       "thursday", "friday", "saturday"]
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun",
                                 "jul", "aug", "sep", "oct", "nov", "dec"]

    /// Parse the argument of a `due:` token. Returns midnight of the matched day.
    static func parseDate(_ raw: String, clock: TaskClock = TaskClock()) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if s.isEmpty { return nil }

        if s == "today" { return clock.today }
        if s == "tomorrow" || s == "tmrw" { return clock.addingDays(1, to: clock.today) }

        // Weekday name → next occurrence (a same-day match jumps to next week).
        if let wd = weekdayIndex(s) {
            let current = (clock.calendar.component(.weekday, from: clock.today) - 1 + 7) % 7
            let delta = ((wd - current + 7) % 7)
            return clock.addingDays(delta == 0 ? 7 : delta, to: clock.today)
        }

        // ISO 2026-05-15
        if let iso = matchISO(s, clock: clock) { return iso }

        // "15 May [2026]" or "May 15 [2026]"
        if let named = matchNamedDate(s, clock: clock) { return named }

        return nil
    }

    /// Map a weekday word to 0=Sunday...6=Saturday. Accepts full names and
    /// 3+ letter prefixes ("sat", "saturday"), plus common irregular short forms.
    private static func weekdayIndex(_ s: String) -> Int? {
        guard s.count >= 3 else { return nil }
        let aliases: [String: Int] = ["tues": 2, "thur": 4, "thurs": 4, "weds": 3]
        if let index = aliases[s] { return index }
        return weekdayNames.firstIndex { $0.hasPrefix(s) }
    }

    private static func makeDate(year: Int, month: Int, day: Int, clock: TaskClock) -> Date? {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        guard let date = clock.calendar.date(from: comps) else { return nil }
        return clock.startOfDay(date)
    }

    private static func matchISO(_ s: String, clock: TaskClock) -> Date? {
        let parts = s.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), parts[0].count == 4,
              let mo = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(mo), (1...31).contains(d) else { return nil }
        return makeDate(year: y, month: mo, day: d, clock: clock)
    }

    private static func matchNamedDate(_ s: String, clock: TaskClock) -> Date? {
        let words = s.split(separator: " ").map(String.init)
        guard words.count == 2 || words.count == 3 else { return nil }

        let defaultYear = clock.calendar.component(.year, from: clock.now)

        // "15 May [2026]"
        if let day = Int(words[0]), let month = monthIndex(words[1]) {
            let year = words.count == 3 ? Int(words[2]) ?? defaultYear : defaultYear
            return makeDate(year: year, month: month + 1, day: day, clock: clock)
        }
        // "May 15 [2026]"
        if let month = monthIndex(words[0]), let day = Int(words[1]) {
            let year = words.count == 3 ? Int(words[2]) ?? defaultYear : defaultYear
            return makeDate(year: year, month: month + 1, day: day, clock: clock)
        }
        return nil
    }

    private static func monthIndex(_ word: String) -> Int? {
        guard word.count >= 3 else { return nil }
        return months.firstIndex { word.hasPrefix($0) }
    }
}
