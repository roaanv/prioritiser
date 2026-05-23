// SeedData.swift
// First-run sample content, ported from the prototype's FOLDERS and TASKS so a
// fresh install shows a meaningful, demo-able board. Due dates are computed
// relative to "today" (not hardcoded), so the demo always looks current.

import Foundation

enum SeedData {
    /// Sample folders, in display order. Colors carry the prototype's OKLCH hues.
    static let folders: [Folder] = [
        Folder(id: "inbox",       name: "Inbox",         parentId: nil,         color: OKLCH(0.72, 0.04, 250), isSystem: true),
        Folder(id: "work",        name: "Work",          parentId: nil,         color: OKLCH(0.68, 0.13, 250)),
        Folder(id: "prioritiser", name: "Prioritiser",   parentId: "work",      color: OKLCH(0.68, 0.13, 32)),
        Folder(id: "design",      name: "Design Review", parentId: "work",      color: OKLCH(0.68, 0.13, 320)),
        Folder(id: "ops",         name: "Operations",    parentId: "work",      color: OKLCH(0.68, 0.13, 140)),
        Folder(id: "personal",    name: "Personal",      parentId: nil,         color: OKLCH(0.68, 0.13, 80)),
        Folder(id: "home",        name: "Home",          parentId: "personal",  color: OKLCH(0.68, 0.13, 120)),
        Folder(id: "reading",     name: "Reading",       parentId: nil,         color: OKLCH(0.68, 0.13, 200)),
    ]

    /// Sample tasks. `offset` is days from today for the due date (nil = none).
    static func tasks(clock: TaskClock = TaskClock()) -> [TaskItem] {
        let today = clock.today
        let created = clock.addingDays(-3, to: today)
        func due(_ offset: Int?) -> Date? { offset.map { clock.addingDays($0, to: today) } }

        let specs: [(id: String, title: String, folder: String, due: Int?, effort: Int?, impact: Level, priority: Level, state: TaskState, notes: String?, snooze: Int?)] = [
            ("t1",  "Ship beta to first 5 users",           "prioritiser", 2,  180, .high,   .high,   .inProgress, "Whitelist the 5 invitees, freeze the bug list at 14, send the welcome email Tuesday night so they wake to it.", nil),
            ("t2",  "Fix sidebar drag-reorder bug",         "prioritiser", 1,  30,  .medium, .high,   .open,       "Drag handle event swallows the click on touch trackpads — reproduced on M2 Air, not M1 Pro.", nil),
            ("t3",  "Draft Q3 OKRs",                        "work",        5,  120, .high,   .medium, .open,       nil, nil),
            ("t4",  "Schedule plumber for kitchen leak",    "home",        -2, 10,  .medium, .high,   .open,       "Two referrals from neighbours — Mendez and ABS. Mendez voicemail full.", nil),
            ("t5",  "Read Shape Up — chapter 4",            "reading",     nil, 45,  .low,    .low,    .open,       nil, nil),
            ("t6",  "Send investor update for May",         "work",        0,  60,  .high,   .high,   .open,       "Cover: MRR delta, churn, two reference hires, one anti-highlight.", nil),
            ("t7",  "Call mom — birthday plans",            "personal",    3,  20,  .medium, .medium, .open,       nil, nil),
            ("t8",  "Reply to user feedback emails",        "prioritiser", nil, 30,  .medium, .medium, .open,       nil, nil),
            ("t9",  "Order replacement lightbulbs",         "home",        nil, 5,   .low,    .low,    .open,       nil, nil),
            ("t10", "Prepare onboarding deck for new hire", "prioritiser", 7,  240, .high,   .medium, .open,       nil, nil),
            ("t11", "Brainstorm v2 features",               "prioritiser", nil, 60,  .medium, .low,    .open,       nil, nil),
            ("t12", "Book annual physical",                 "personal",    -1, 10,  .medium, .high,   .open,       nil, nil),
            ("t13", "Review design crit doc",               "design",      1,  30,  .medium, .medium, .open,       nil, nil),
            ("t14", "Plan team offsite agenda",             "work",        4,  60,  .medium, .medium, .open,       nil, nil),
            ("t15", "Renew driver\u{2019}s license",        "personal",    28, 60,  .high,   .medium, .open,       nil, nil),
            ("t16", "Clean up Downloads folder",            "inbox",       nil, 15,  .low,    .low,    .open,       nil, nil),
            ("t17", "Waiting on Maya for press kit",        "work",        6,  20,  .medium, .medium, .waiting,    "Pinged Mon May 18 — chase Wednesday if no reply.", nil),
            ("t18", "Refactor scoring function",            "prioritiser", nil, 90,  .medium, .low,    .snoozed,    nil, 7),
            ("t19", "Audit subscription receipts",          "ops",         10, 60,  .medium, .low,    .open,       nil, nil),
            ("t20", "Buy birthday gift for Sam",            "personal",    9,  30,  .medium, .medium, .open,       nil, nil),
        ]

        return specs.map { spec in
            TaskItem(
                id: spec.id,
                title: spec.title,
                folderId: spec.folder,
                due: due(spec.due),
                effortMinutes: spec.effort,
                impact: spec.impact,
                priority: spec.priority,
                state: spec.state,
                notes: spec.notes,
                snoozedUntil: due(spec.snooze),
                createdAt: created
            )
        }
    }
}
