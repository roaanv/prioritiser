# Changelog

All notable changes to Prioritiser are documented here. The format loosely
follows [Keep a Changelog](https://keepachangelog.com/) and semantic versioning.

## [Unreleased]

### Added — task drag-and-drop between projects
- Live tasks can now be dragged from the task list onto sidebar projects, including Inbox, to re-file them without leaving the current view.
- Dragging one selected task moves the whole selected set; dragging an unselected task moves only that task. Completed tasks are not draggable.

### Added — Completed view
- A new **Completed** sidebar view lists done tasks **grouped by the day you completed
  them** (Today / Yesterday / date), most recent first. Checking a task off files it here;
  toggling its checkbox **reopens** it (and it leaves the list).
- Tasks now store a **`completedAt`** timestamp (**migration v3**), set when a task becomes
  done and cleared when reopened — enforced as an invariant in `AppModel.update`, so it's
  correct whether you complete via the checkbox or the detail-pane state control. Existing
  done tasks are **backfilled** from their `.completed` activity events, so historical
  completion dates survive the upgrade.
- `SmartView.completed` + `TaskFilter` completed set (no count badge); the view hides the
  layout/sort/filter controls since it's a day-grouped log. (**78 tests**.)

### Added — `make install` (local install)
- `make install` builds a Release app for this Mac's architecture (ad-hoc signed, so
  it launches locally without Gatekeeper friction) and copies it to `~/Applications` —
  a fast way to use the latest build without the tagged GitHub release pipeline.

### Added — Focus ("Today") mode
- A slimmed-down second operating mode showing only **today's and overdue** tasks as
  collapsible cards. Each card edits the **title** and **description** inline, lets you
  check the task off, and expands/collapses its description; a minimal quick-add at the
  top files new tasks as **due today**. No sidebar / detail / matrix / chrome — just the
  day's list, ranked by priority, to keep a Today focus without distraction.
- Toggle between Focus and the full app from the toolbar (moon icon), the **View menu**,
  or **⌘⇧F**. The chosen mode is **persisted**, so the app reopens in the mode you left.
- **Overdue cards show their due date** (a red calendar chip) so you know how stale they are.
- **Read-only attributes** on each card — priority **Score**, **Impact**, **Priority**, and
  **Effort** — for guidance on what to tackle first (the list is already score-ranked).
- **Focus and Full have independent, remembered window frames — position *and* size.**
  Focus can live top-left while Full sits bottom-right; switching restores each mode's own
  frame. Focus is capped narrow with a lower minimum (stays slim, can't be dragged below
  it); Full keeps the wide minimum and is freely resizable (`WindowConfigurator`).
- New `FocusModeView` + `WindowConfigurator`; `AppModel.isFocusMode` (persisted) /
  `focusTasks` / `createTodayTask`; `TaskFilter.todayAndOverdue`. Tests (**74 tests**).

### Added — value picker for i:/p: in quick-add
- Typing `i:` or `p:` now shows a **High / Medium / Low** dropdown (the only valid
  values) — ↑/↓ + Enter/Tab or click fills it in (e.g. → `p:h`), so an invalid entry
  like `p:1` (which used to be silently swallowed into the title) is no longer easy to
  make. Works in the inline quick-add bar, the ⌘N Spotlight, and the global capture box.
- The dropdown **pre-highlights the value already typed** — e.g. `i:l` highlights Low,
  not the top row — so what you typed and what Enter will accept stay in sync.
- Pure detection/completion (`PrefixParser.activeLevelPrefix` / `activeLevelValue` /
  `completeLevel`, `Level.token` / `pickerOrder`) is unit-tested (**70 tests**).

### Added — editable task title
- The task title in the detail pane is now an inline editable field (it was static
  text). Edits persist as you type, mirroring the notes editor; empty input is ignored
  so a task always keeps a title, and the change reflects live in the task list.

### Added — global quick-capture hotkey + menu-bar item
- A **system-wide, configurable** hotkey (default **⌃⌥⌘T**) pops a floating capture
  box from any app — type a task (the full `#project due: t: i: p:` grammar works),
  Enter saves it, Esc/the hotkey again dismisses. Registered via Carbon
  `RegisterEventHotKey`, so it needs no Accessibility permission. Set/rebind it in
  **Settings → Quick Capture** with a click-to-record control (Reset restores default).
- A **menu-bar item** (checklist icon) offers Quick Capture (showing the shortcut),
  Open Prioritiser, and Quit — so capture is available even with the window closed.
- New: `CaptureShortcut` (Codable, persisted), `GlobalHotKey` (Carbon wrapper),
  `CaptureController` (owns the hotkey + floating `NSPanel`), `QuickCaptureView`,
  `ShortcutRecorder`. Pure-logic tests for the shortcut (**66 tests** total).

### Added — arrow-key list navigation
- **↑ / ↓** move the selection up and down the visible task list (matching the on-screen
  order, including the schedule buckets and top-priority bands) and scroll the selected
  row into view. With nothing selected, ↓ picks the first row and ↑ the last. Navigation
  is scoped to the list via focus, so arrows still move the text cursor while editing
  notes or the quick-add field.

### Added — task deletion (single + multi-select)
- Tasks can now be deleted: **right-click** a row for a **Delete** item, or press
  **⌘⌫** while the list is focused. Deleting two or more tasks asks for confirmation
  first; a single delete is immediate. A bare Backspace never deletes.
- **Multi-select** in the task list: ⌘-click toggles a row in/out of the selection,
  ⇧-click selects a contiguous range. The row highlight reflects the whole selection,
  while the primary (last-clicked) task still drives the detail pane. After a delete,
  the primary moves to a surviving neighbor.
- Deletion is a hard delete that also removes the task's activity history (no orphaned
  rows in the `activity` table). Covered by AppModel tests (**61 tests** total).

### Removed — placeholder user footer
- Dropped the hardcoded "Alex" user chip from the bottom of the sidebar (leftover
  prototype chrome). Prioritiser is a single-user app, so there's no account to show.

### Added — one-step release bump targets
- `make release-patch` / `make release-minor` bump `MARKETING_VERSION` in
  `project.yml`, commit (`release: vX.Y.Z`), tag, and push from `main` — triggering
  the release workflow. They guard against a dirty tree, a non-`main` branch, and an
  existing tag, and push the branch + tag atomically. Logic lives in
  `scripts/bump-release.sh`.

## [0.1.0] - 2026-05-24

First signed + notarized public release — a universal (arm64 + x86_64) `.dmg` and
`.zip`, published to `roaanv/prioritiser` and `roaanv/releases`. Everything below
shipped in 0.1.0.

### Added — signed/notarized release pipeline (GitHub Actions)
- A tag-driven (`v*`) workflow (`.github/workflows/release.yml`) runs the tests,
  then builds a **universal (arm64 + x86_64)** Release binary, **Developer ID**-signs
  it with the hardened runtime, **notarizes + staples** the `.app`, packages it as a
  `.dmg` (also notarized/stapled) and a `.zip`, and publishes both to this repo's
  Releases **and** to the shared `roaanv/releases` repo (tagged `prioritiser-v*`).
- New `make` targets back the pipeline (and run locally): `release`, `sign`,
  `notarize-app`, `dmg`, `notarize-dmg`, `archive`, plus `gh-secrets` to push the
  six required secrets from the macOS Keychain. The local Debug build stays ad-hoc;
  Developer ID + hardened runtime are applied at sign time, so `project.yml` is
  unchanged. Added a minimal `Prioritiser.entitlements` and a `scripts/` helper.
- Documented the credential/secret setup and release steps in `RELEASE.md`.

### Added — project priority matrix (Eisenhower 2×2)
- A "Priority Matrix" panel pinned below the detail pane shows per-quadrant task
  counts for the sidebar-selected project. Axes map onto our data: **Important** =
  high impact, **Urgent** = overdue or due within 2 days (no due date = not urgent).
  Quadrants: Do Now / Plan / Quick Decisions / Backlog. Each cell's fill is a
  count-driven **temperature heat** (OKLCH cool-blue → warm-red, relative to the
  busiest quadrant; empty = no tint); selection is conveyed solely by the accent
  ring, so heat and selection never use the same signal. Counts render in primary.
- A **Sub-projects** toggle (shown only when the folder has children) scopes between
  this folder only and the whole subtree.
- The matrix also shows for the **whole-set smart views** — Top Priorities, All Tasks,
  Inbox — and clicking a quadrant filters those too. It stays hidden for the
  axis-defined views (Today / Overdue / Next 7 / Quick Wins), where a 2×2 would be
  degenerate or redundant (`SmartView.supportsMatrix`).
- Pure, tested `Eisenhower` classifier + `TaskFilter.directTasks`.
- **Click a quadrant to filter the task list** to it (click again, or the heading
  chip's ✕, to clear; changing selection clears it too).
- The Sub-projects scope is one shared `includeSubprojects` setting driving **both**
  the list and the matrix, so a quadrant's count always matches the filtered list. Its
  single toggle lives in the **task-list header** (shown when a parent folder is
  selected); the matrix just reflects the scope ("incl. sub-projects" / "this project").
  (53 tests total.)

### Added — create-on-commit projects + folder re-parenting
- **Unknown `#project` prompts to create.** When a task is committed (Enter), if its
  `#slug` doesn't match an existing folder, a confirmation asks "Create project …?".
  Create → makes a top-level folder and files the task into it; Cancel → returns to
  editing with the text intact. This fires at commit time, not while typing/completing.
- **Drag-and-drop folder reordering AND re-parenting.** Each row has a thin top-edge
  strip (the gap above it): dropping there **reorders** the folder to that position
  (shown by an accent insertion line), re-parenting if the gap is under a different
  parent. Dropping on a row **body** moves the folder *into* that folder; dropping on
  the "Folders" header (or the "Move to Top Level" context item) moves it to the top
  level. Guards against cycles (no dropping into a descendant) and the system Inbox.
- Tests: reparent into/out, cycle + system-folder guards, and create-folder-and-task
  (**43 tests total**).

### Added — `#project` autocomplete (Todoist-style)
- Typing `#` (then partial text) in the inline quick-add bar or the ⌘N Spotlight now
  shows a live dropdown of matching folders: **↑/↓** to move, **Enter/Tab** or click to
  complete, **Esc** to dismiss (in Spotlight, a second Esc closes the sheet).
- Matching ranks prefix hits first, then substring; each row shows the folder color
  and its parent path for disambiguation. Completing inserts the folder slug
  (`#design`) so the grammar parses cleanly; the preview chip shows the friendly name.
- Pure helpers `PrefixParser.activeHashtagQuery` / `completeHashtag` and
  `FolderTree.search`, shared by both inputs and covered by tests.
- Completion inserts a **name-derived slug** (`Folder.nameSlug`: lowercased,
  alphanumerics only) rather than the stored id — so "#Ope" → "#operations" (not
  the surprising abbreviation "#ops"). The resolver matches by id *or* name slug, so
  a literal `#ops` still works. (**40 tests**.)

### Added — App icon
- Generated a native macOS app icon (blue-gradient squircle with a descending
  "ranked bars" priorities motif) via `tools/make_icon.swift` + CoreGraphics, with
  all required sizes (16–1024) in `Assets.xcassets/AppIcon.appiconset`.
- Wired `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`; verified it compiles into
  `Assets.car` with `CFBundleIconName` set. Regenerate with `make icon`.

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

[Unreleased]: https://github.com/roaanv/prioritiser/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/roaanv/prioritiser/releases/tag/v0.1.0
