# Changelog

All notable changes to Prioritiser are documented here. The format loosely
follows [Keep a Changelog](https://keepachangelog.com/) and semantic versioning.

## [Unreleased]

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
