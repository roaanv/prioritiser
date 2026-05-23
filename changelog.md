# Changelog

All notable changes to Prioritiser are documented here. The format loosely
follows [Keep a Changelog](https://keepachangelog.com/) and semantic versioning.

## [Unreleased]

### Added — Slice 7: snooze scheduling + state persistence
- **Auto-unsnooze** — snoozed tasks now return to the open state automatically when
  their snooze date passes (run at launch, like a "scheduled for later" wake-up).
  Marking a task Snoozed in the detail pane reveals a **Snooze until** date picker
  (defaults to a week out); leaving the snoozed state clears the date.
- **Folder drag-reorder** — folders can be dragged to reorder among their siblings;
  the order persists to the folder `sort_order`. Cross-parent drops are ignored.
- **Persisted UI state** — the sidebar selection, expanded folders, and inspected
  task are saved (UserDefaults) and restored on relaunch, with validation that a
  saved folder/task still exists.
- Tests: auto-unsnooze (wakes past-due, keeps future), folder reorder (siblings +
  cross-parent guard), and Selection round-trip — **36 tests total, all passing**.

### Added — Slice 6: search, schedule, sort/filter, activity, reorder, Dynamic Type
- **Search** — the sidebar field now filters the current view by title/notes as you
  type, with a clear button; **⌘F** focuses it; the heading shows the result context.
- **Schedule view** — the List/Schedule tabs are live; Schedule groups tasks into
  Overdue / Today / Tomorrow / This Week / Later / No Date buckets.
- **Sort & Filter menus** — sort by Manual / Priority score / Due date / Title /
  Effort; filter by state (All / Open / In progress / Waiting).
- **Activity feed** — real, persisted events (**migration v2** adds an `activity`
  table and backfills a "created" event per existing task). Logs created, completed,
  reopened, state, due, and folder changes, shown newest-first with relative times.
- **Drag-reorder** — in All Tasks (manual sort, unfiltered, not searching) rows can
  be dragged to reorder; the new order persists to `sort_order`.
- **Dynamic Type** — an `.appFont` (`@ScaledMetric`) helper scales the primary text
  with the system text size; the range is clamped (xSmall…accessibility1) to keep the
  dense 3-pane layout usable. Micro-chrome (badges, key caps) stays fixed by design.
- Tests: due bucketing, sort/filter helpers, and an AppModel integration suite
  (search, activity logging, reorder) — **31 tests total, all passing**.

### Changed — Slice 5: hardening (Swift 6 + accessibility)
- Migrated the project to **Swift 6 language mode** (complete data-race safety /
  strict concurrency). The pure-domain + `@MainActor` UI/store split meant this
  compiled with no concurrency errors; the only touch-ups were a `Task {}` for a
  deferred focus and a comment on the shared (Sendable) `NSRegularExpression`.
- **Accessibility**:
  - Task rows are single VoiceOver elements with a spoken summary (title, folder,
    due, effort, impact, score, state) and the button/selected traits; the
    completion checkbox remains its own labeled control.
  - Icon-only controls (Tweaks, New folder, disclosure chevrons) now have labels;
    the detail breadcrumb reads as a folder path.
  - Decorative, not-yet-wired controls (List/Schedule tabs, Sort/Filter, header
    glyphs) are hidden from the accessibility tree to cut VoiceOver noise.
  - Quick-add overlay animation respects **Reduce Motion**.
- Known limitation: fixed point sizes are kept for the dense desktop layout, so
  full Dynamic Type scaling is not yet adopted (documented for a future pass).

### Added — Slice 4: detail editing + folder management
- Detail pane is now fully editable and persisted:
  - **Notes** — inline editor (saves as you type).
  - **Due date** — date picker with a clear button, or "Add due date" when unset.
  - **Effort** — preset menu (Unestimated, 5m … 3d).
  - **Folder** — reassign via a menu of all folders (shown as full paths).
  - (Impact / priority / state segmented controls already landed in slice 1.)
- **Folder management** in the sidebar: a "+" header button creates a folder, the
  context menu offers Rename (inline) / New Subfolder / Delete, and renaming is in-place.
- Deleting a folder **never loses task data**: its tasks move to the parent (or
  Inbox) and its child folders reparent up one level. System folders (Inbox) are
  protected. New folders get cycling OKLCH accent colors and slug-style ids.
- **"All Tasks" now includes snoozed tasks** (excluding only completed), so snoozing
  a task is no longer a one-way door — you can find and un-snooze it there.
- Tests: migration runner, first-run seeding, insert/update round-trip, folder-delete
  data preservation, system-folder protection, and the snoozed-in-All filter
  (24 tests total, all passing).

### Added — Slice 3: theming UI
- `TweaksView` preferences (shared by a toolbar popover and the Settings ⌘, window):
  - **Appearance** — System / Light / Dark, applied via `preferredColorScheme`.
  - **Accent** — blue / orange / purple / green swatches.
  - **Priority visualization** — Ranked cards / Score bars / Heat tint.
- Priority-viz modes wired through the task list:
  - *cards* — Top-5 ranked, elevated cards with the "NOW" badge (default).
  - *bars* — a thin accent score bar along the bottom of each row.
  - *heat* — each row tinted by score intensity (`(score−55)/45`).
- All preferences persist via `@AppStorage` and stay in sync across surfaces.

### Added — Slice 2: live quick-add + ⌘N Spotlight
- Inline quick-add bar now parses as you type and surfaces recognized prefixes as
  colored preview chips (`#folder`, `due:`, `t:`, `i:`, `p:`) beneath the field.
- ⌘N opens a Spotlight-style floating capture: large input over a dimmed/blurred
  backdrop, a live title + chip preview, and a footer grammar legend. Enter creates
  the task; Escape or a backdrop click cancels.
- `PrefixChip` / `PrefixChipRow` reusable chip views; `FolderTree.folder(forSlug:)`
  shared slug→folder resolver (also used by task creation). Test added.
- Impact/priority/folder chip palettes (OKLCH hues 340 / 30 / accent-tinted).

### Added — Slice 1: foundation + runnable skeleton
- Project scaffolding: `project.yml` (xcodegen), `Makefile` (setup/build/run/test/deploy),
  `.gitignore`, this changelog, README.
- Domain models: `Task`, `Folder`, `Level` (impact/priority), `TaskState`, `SmartView`.
- Theme: OKLCH→sRGB color conversion, folder/chip palette, `NSVisualEffectView` bridge.
- Domain logic (ported faithfully from the design prototype):
  - `PriorityScorer` — weighted impact/priority/urgency/quick-win score (0–100).
  - `PrefixParser` — quick-add grammar (`#folder due: t: i: p:`).
  - `Formatting` — effort + due-date labels.
  - `TaskFilter` — smart views and folder-scoped filtering.
- Data layer: SQLite (`Database` over system SQLite3), versioned `Migrations`,
  `TaskStore` repository, first-run `SeedData`.
- App shell: three-pane layout (Sidebar · Task list · Detail) rendering seeded
  data, with selection and completion toggle.
- Unit tests (Swift Testing) for the scorer, parser, formatting, and filters
  (17 tests, all passing).

### Changed — intentional deviations from the prototype
- "Today" is the real current date (the prototype hardcoded 2026-05-23 so demo
  data stayed stable); seed due-dates are computed relative to first-run day.
- Theming follows the system appearance (light/dark) + an accent picker, instead
  of the prototype's three bespoke CSS aesthetics and density modes.

### Fixed — parser correctness (caught by tests)
- `due:` no longer swallows the head of a following prefix token (e.g. the `t` of
  `t:1h` in `due:tomorrow t:1h`) — added a `(?!:)` lookahead on continuation words.
- Weekday names now parse for all days ("saturday", "tuesday", …); the prototype
  only handled `abbrev` / `abbrev+"day"`, silently failing on most full names.
