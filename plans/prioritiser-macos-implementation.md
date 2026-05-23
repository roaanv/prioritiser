# Prioritiser — macOS (SwiftUI) Implementation Plan

Recreate the **Prioritiser** design (a Claude Design handoff bundle) as a native
macOS app. The design is a 3-pane, native-feeling todo app that helps decide
*what to do next* via an auto-computed priority score.

## Source of truth
- Design bundle: HTML/CSS/JS React prototype (`Prioritiser.html` + `*.jsx`).
- Target stack (`AGENTS.md`): **SwiftUI + SQLite + Makefile**.
- Job: recreate the prototype's *visual output and behavior* in idiomatic
  SwiftUI — not port the React internals.

## Confirmed scope decisions (from user)
1. **Build incrementally** in vertical slices; review at each checkpoint.
2. **Theming** = native appearance (system light/dark) + accent picker + native
   materials. Drop Graphite + density as separate modes.
3. **Quick-add** = plain text field, parse-as-you-type, resolved chips shown in a
   preview row beneath (no inline contenteditable chip-replacement).
4. **SQLite from the start**, with a versioned migration step, seeded on first run.

## Domain logic to port *exactly* (it's the product's brain)
- **Score** = `0.30·impact + 0.25·priority + 0.30·urgency + 0.15·quickWin`, ×100.
  - impact/priority ∈ {1,2,3} → /3.
  - urgency: no due → 0.25; overdue/today (n≤0) → 1; else `max(0.1, 1 − n/14)`.
  - quickWin from effort minutes: `max(0.05, 1 − log10(1 + eff/10)/2)`; default eff 60.
- **Prefix grammar**: `#folder`, `due:<expr>`, `t:<n><m|h|d>`, `i:<h|m|l>`, `p:<h|m|l>`.
  - effort: m→min, h→×60, d→×60×8 (8h workday).
  - date exprs: today, tomorrow/tmrw, weekday names, `YYYY-MM-DD`, `15 May [2026]`, `May 15 [2026]`.
- **Smart views**: top, today, week (0..7d), overdue (<0), quickwin (≤30m & impact≥2),
  inbox (folder==inbox), all. Live = not done & not snoozed.
- **Effort formatting**: <60→`Nm`; <8h→`Nh`/`N.Nh`; else `Nd`/`N.Nd`.
- **Due labels**: Today / Tomorrow / Yesterday / `Nd overdue` / `in Nd` / `Mon D`.

> Deviation from prototype: "today" is a hardcoded 2026-05-23 in the prototype so
> demo data is stable. In the app, "today" = the real current date. Seed due-dates
> are stored relative to first-run day so the seeded demo still looks sensible.

## Architecture (clean layers)
```
Sources/
  App/        PrioritiserApp, AppModel (@Observable root state)
  Models/     Task, Folder, Level, TaskState, SmartView
  Domain/     PriorityScorer, PrefixParser, TaskFilter, Formatting, TaskClock
  Data/       Database (SQLite3 wrapper), Migrations, TaskStore, SeedData
  Theme/      OKLCH, Theme/Palette, VisualEffectView (NSVisualEffectView bridge)
  Features/   Sidebar/, TaskList/, Detail/, QuickAdd/
Tests/        PrioritiserTests (Swift Testing): scorer, parser, formatting, filters
```
- SQLite via the system `SQLite3` C library (no external deps → reliable `make build`).
- DB file: `~/Library/Application Support/Prioritiser/prioritiser.sqlite`.
- Migrations: `PRAGMA user_version` runner; v1 creates folders+tasks; seed if empty.

## Slices
- **Slice 1 (foundation + runnable skeleton)** ✅ COMPLETE
  - Scaffolding: `project.yml`, `Makefile` (setup/build/run/deploy), `.gitignore`,
    `changelog.md`, `README.md`.
  - Models + Theme (OKLCH, palette).
  - Domain: scorer, parser, formatting, filters (+ unit tests).
  - Data: Database, Migrations, TaskStore, SeedData.
  - App shell + 3 panes rendering seeded data: Sidebar (views + folder tree),
    TaskList (Top-5 band + Next up, rows with chips/pips/score), Detail (score
    card + breakdown + fields). Interactive selection + completion toggle.
  - `make build` green; `make run` shows the app.
- **Slice 2** — Quick-add: live parse + preview chips; ⌘N Spotlight capture. ✅ COMPLETE
- **Slice 3** — Theming UI: appearance (System/Light/Dark); accent picker in
  toolbar popover + Settings; priority-viz modes (cards/bars/heat). ✅ COMPLETE
- **Slice 4** — Detail editing wired to store (notes/due/effort/folder editors),
  folder CRUD (add/rename/delete with data-preserving reassignment), Snoozed
  reachable via "All Tasks", migration + persistence tests. ✅ COMPLETE
- **Slice 5** — Hardening: Swift 6 strict concurrency, accessibility (VoiceOver
  labels/traits, reduce-motion), polish. ✅ COMPLETE
  - Deferred: full Dynamic Type scaling (kept fixed sizes for the dense layout).

## Slice 6 — fill the functional gaps ✅ COMPLETE
- **Search** — sidebar field filters the current view by title/notes; ⌘F focuses it.
- **Schedule view** — List/Schedule tabs toggle; Schedule groups tasks by due bucket
  (Overdue / Today / Tomorrow / This week / Later / No date).
- **Sort / Filter** — toolbar menus: sort (Manual/Score/Due/Title/Effort) and a
  state filter (All/Open/In progress/Waiting).
- **Activity feed** — real, persisted events (migration v2: `activity` table). Logs
  created / completed / reopened / state / due / folder changes; backfills created.
- **Drag-reorder** — manual reordering in All Tasks (manual sort, unfiltered),
  persisted to `sort_order`.
- **Dynamic Type** — text scales via a `.appFont` (`@ScaledMetric`) helper, clamped
  to a sane range to protect the dense layout.

## Slice 7 — snooze scheduling + state persistence ✅ COMPLETE
- Auto-unsnooze on launch + a "Snooze until" date picker in the detail pane.
- Folder drag-reorder (sibling reorder, persisted).
- Persisted sidebar selection / expanded folders / inspected task across launches.

## Beyond the plan (still not built)
- App icon + signed/notarized distribution (the `make deploy` archive is unsigned).

## Verification per slice
- `make build` compiles clean.
- `swift test` (domain tests) green.
- `make run` launches; manually confirm the slice's behavior.
- Update `changelog.md`.
