// PrefixParserTests.swift
// Exercises the quick-add grammar: folder/due/effort/impact/priority tokens, the
// title reconstruction, effort unit conversion, and the date expression forms.

import Testing
import Foundation
@testable import Prioritiser

private let clock = TaskClock(
    now: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 23))! // a Saturday
)

@Suite("PrefixParser")
struct PrefixParserTests {
    @Test("Parses a full quick-add string into title + fields")
    func fullParse() {
        let parsed = PrefixParser.parse("#prioritiser Ship beta due:tomorrow t:1h i:h p:h", clock: clock)
        #expect(parsed.title == "Ship beta")
        #expect(parsed.folderSlug == "prioritiser")
        #expect(parsed.effortMinutes == 60)
        #expect(parsed.impact == .high)
        #expect(parsed.priority == .high)
        #expect(parsed.due == clock.addingDays(1, to: clock.today))
    }

    @Test("Effort units convert to minutes")
    func effortUnits() {
        #expect(PrefixParser.parseEffort("10m") == 10)
        #expect(PrefixParser.parseEffort("1h") == 60)
        #expect(PrefixParser.parseEffort("1.5h") == 90)
        #expect(PrefixParser.parseEffort("3d") == 1440) // 3 × 8h
        #expect(PrefixParser.parseEffort("nope") == nil)
    }

    @Test("Date expressions resolve to the right day")
    func dateForms() {
        #expect(PrefixParser.parseDate("today", clock: clock) == clock.today)
        #expect(PrefixParser.parseDate("2026-05-15", clock: clock)
                == clock.startOfDay(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 15))!))
        #expect(PrefixParser.parseDate("15 May", clock: clock)
                == clock.startOfDay(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 15))!))
        #expect(PrefixParser.parseDate("banana", clock: clock) == nil)
    }

    @Test("A same-day weekday jumps to next week")
    func weekdayNextWeek() {
        // Reference day is Saturday; "saturday" should be 7 days out, not 0.
        #expect(PrefixParser.parseDate("saturday", clock: clock) == clock.addingDays(7, to: clock.today))
    }

    @Test("Plain text has no tokens")
    func plainText() {
        let parsed = PrefixParser.parse("Just a normal task", clock: clock)
        #expect(parsed.title == "Just a normal task")
        #expect(parsed.tokens.isEmpty)
        #expect(parsed.folderSlug == nil)
    }

    @Test("Detects the in-progress trailing #tag for autocomplete")
    func activeHashtag() {
        #expect(PrefixParser.activeHashtagQuery(in: "Ship beta #pri") == "pri")
        #expect(PrefixParser.activeHashtagQuery(in: "Ship beta #") == "")        // just typed '#'
        #expect(PrefixParser.activeHashtagQuery(in: "Ship beta #work ") == nil)  // committed (trailing space)
        #expect(PrefixParser.activeHashtagQuery(in: "no hashtag here") == nil)
    }

    @Test("Completing a hashtag replaces the partial with the slug + space")
    func completeHashtag() {
        #expect(PrefixParser.completeHashtag(in: "Ship beta #pri", with: "prioritiser") == "Ship beta #prioritiser ")
        #expect(PrefixParser.completeHashtag(in: "Fix bug #", with: "design") == "Fix bug #design ")
    }

    @Test("Detects the in-progress trailing i:/p: token for value suggestions")
    func activeLevelPrefix() {
        #expect(PrefixParser.activeLevelPrefix(in: "Task p:") == .priority)
        #expect(PrefixParser.activeLevelPrefix(in: "Task i:") == .impact)
        #expect(PrefixParser.activeLevelPrefix(in: "Task p:1") == .priority)  // invalid value still detected
        #expect(PrefixParser.activeLevelPrefix(in: "p:") == .priority)        // at string start
        #expect(PrefixParser.activeLevelPrefix(in: "Task p:h ") == nil)       // committed (trailing space)
        #expect(PrefixParser.activeLevelPrefix(in: "tip:") == nil)            // not a word-boundary token
        #expect(PrefixParser.activeLevelPrefix(in: "no prefix") == nil)
    }

    @Test("Completing an i:/p: token inserts the level letter + space and parses")
    func completeLevel() {
        #expect(PrefixParser.completeLevel(in: "Ship it p:", with: .high) == "Ship it p:h ")
        #expect(PrefixParser.completeLevel(in: "Ship it i:1", with: .low) == "Ship it i:l ") // replaces bad value
        #expect(PrefixParser.completeLevel(in: "p:", with: .medium) == "p:m ")

        let completed = PrefixParser.completeLevel(in: "Ship it p:", with: .high)
        let parsed = PrefixParser.parse(completed)
        #expect(parsed.priority == .high)
        #expect(parsed.title == "Ship it")
    }

    @Test("Resolves the typed i:/p: value so the picker can pre-highlight it")
    func activeLevelValue() {
        #expect(PrefixParser.activeLevelValue(in: "Task i:l") == .low)
        #expect(PrefixParser.activeLevelValue(in: "Task p:h") == .high)
        #expect(PrefixParser.activeLevelValue(in: "Task p:") == nil)   // nothing typed yet
        #expect(PrefixParser.activeLevelValue(in: "Task p:1") == nil)  // invalid value
    }
}
