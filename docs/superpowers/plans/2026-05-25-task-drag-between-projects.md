# Task Drag Between Projects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to drag live tasks from the task list onto sidebar projects/Inbox to re-file the dragged task or selected task set without navigating away.

**Architecture:** Use typed SwiftUI `Transferable` drag payloads so task drags and folder drags are not ambiguous raw strings. Add `AppModel` helpers for resolving selected-vs-single task moves and persisting folder changes through the existing `update(_:)` path. Wire task rows to emit task payloads in live views, and sidebar folder rows to accept task payloads separately from folder reparent/reorder payloads.

**Tech Stack:** Swift 6, SwiftUI/macOS drag and drop, Observation, Swift Testing, SQLite-backed `TaskStore`.

---

## File structure

- Create `Sources/Features/Shared/DragPayloads.swift`
  - Defines `DraggedTaskPayload` and `DraggedFolderPayload` as lightweight `Codable`, `Hashable`, `Transferable` structs.
- Modify `Sources/App/AppModel.swift`
  - Adds `taskIDsToMove(forDraggedTaskID:)` and `moveTasks(_:toFolder:)`.
- Modify `Sources/Features/TaskList/TaskListView.swift`
  - Emits `DraggedTaskPayload` from live task rows.
  - Keeps Completed rows non-draggable.
  - Keeps manual task reorder available only in the existing reorderable context.
- Modify `Sources/Features/Sidebar/SidebarView.swift`
  - Converts existing folder drag/drop to `DraggedFolderPayload`.
  - Adds task drop handling on folder row bodies only.
  - Keeps task payloads ignored by insertion strips and the `Folders` header.
- Modify `Tests/PrioritiserTests/AppModelTests.swift`
  - Adds model-level coverage for move-set resolution, project refiling, order preservation, activity logging, and unknown destination no-op.

---

### Task 1: Add typed drag payloads

**Files:**
- Create: `Sources/Features/Shared/DragPayloads.swift`

- [ ] **Step 1: Create the drag payload file**

Create `Sources/Features/Shared/DragPayloads.swift` with this content:

```swift
// DragPayloads.swift
// Typed SwiftUI drag payloads. Keep task and folder drags distinct so a raw ID
// collision can never make a task drop look like a folder drop, or vice versa.

import SwiftUI
import UniformTypeIdentifiers

struct DraggedTaskPayload: Codable, Hashable, Transferable {
    let taskID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .prioritiserTaskDragPayload)
    }
}

struct DraggedFolderPayload: Codable, Hashable, Transferable {
    let folderID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .prioritiserFolderDragPayload)
    }
}

private extension UTType {
    static let prioritiserTaskDragPayload = UTType(exportedAs: "io.0112.Prioritiser.drag.task")
    static let prioritiserFolderDragPayload = UTType(exportedAs: "io.0112.Prioritiser.drag.folder")
}
```

- [ ] **Step 2: Compile to verify the new types are valid**

Run:

```bash
make build
```

Expected: build succeeds. If Xcode reports a `Transferable` or `CodableRepresentation` import error, keep `import SwiftUI` and `import UniformTypeIdentifiers`; do not replace typed payloads with `String`.

- [ ] **Step 3: Commit**

```bash
git add Sources/Features/Shared/DragPayloads.swift
git commit -m "feat: add typed drag payloads"
```

---

### Task 2: Add model helpers for moving task selections between projects

**Files:**
- Modify: `Sources/App/AppModel.swift`
- Test: `Tests/PrioritiserTests/AppModelTests.swift`

- [ ] **Step 1: Write failing tests for task move semantics**

In `Tests/PrioritiserTests/AppModelTests.swift`, after `moveTaskReordersAndPersists()`, add these tests:

```swift
    @Test func taskIDsToMoveUsesWholeSelectionWhenDraggingSelectedTask() throws {
        let model = try makeModel()
        model.selectedTaskIDs = ["t6", "t7", "missing"]

        #expect(model.taskIDsToMove(forDraggedTaskID: "t6") == ["t6", "t7"])
    }

    @Test func taskIDsToMoveUsesOnlyDraggedTaskWhenDraggingUnselectedTask() throws {
        let model = try makeModel()
        model.selectedTaskIDs = ["t6", "t7"]

        #expect(model.taskIDsToMove(forDraggedTaskID: "t8") == ["t8"])
    }

    @Test func moveTasksToFolderMovesSelectedTasksAndPreservesOrder() throws {
        let model = try makeModel()
        let originalOrder = model.tasks.map(\.id)
        let moving: Set<String> = ["t6", "t7"]

        model.moveTasks(moving, toFolder: "reading")

        #expect(model.tasks.map(\.id) == originalOrder)
        #expect(model.tasks.first { $0.id == "t6" }?.folderId == "reading")
        #expect(model.tasks.first { $0.id == "t7" }?.folderId == "reading")
    }

    @Test func moveTasksToFolderLogsFolderChangedActivity() throws {
        let model = try makeModel()

        model.moveTasks(["t6"], toFolder: "reading")

        #expect(model.activity(for: "t6").contains { event in
            event.kind == .folderChanged && event.detail == "Reading"
        })
    }

    @Test func moveTasksToUnknownFolderDoesNothing() throws {
        let model = try makeModel()
        let before = model.tasks

        model.moveTasks(["t6"], toFolder: "not-a-folder")

        #expect(model.tasks == before)
    }
```

- [ ] **Step 2: Run tests to verify they fail for missing API**

Run:

```bash
make test TEST_FILTER=AppModel
```

Expected: fails to compile because `AppModel` has no `taskIDsToMove(forDraggedTaskID:)` or `moveTasks(_:toFolder:)` yet.

- [ ] **Step 3: Implement model helpers**

In `Sources/App/AppModel.swift`, insert this block immediately after `moveTask(_ draggedID: String, before targetID: String)`:

```swift
    /// Resolve the effective task set for a drag that started from `draggedTaskID`.
    /// Dragging any selected row moves the whole selected set; dragging an
    /// unselected row moves just that row. Stale IDs are ignored.
    func taskIDsToMove(forDraggedTaskID draggedTaskID: String) -> Set<String> {
        let existing = Set(tasks.map(\.id))
        guard existing.contains(draggedTaskID) else { return [] }
        if selectedTaskIDs.contains(draggedTaskID) {
            return selectedTaskIDs.intersection(existing)
        }
        return [draggedTaskID]
    }

    /// Move existing tasks into `folderID` without changing task order or sidebar
    /// selection. Persistence flows through `update(_:)` so folder-change activity
    /// is logged consistently with detail-pane edits.
    func moveTasks(_ ids: Set<String>, toFolder folderID: String) {
        guard !ids.isEmpty, folder(id: folderID) != nil else { return }
        for id in ids {
            guard let task = tasks.first(where: { $0.id == id }), task.folderId != folderID else { continue }
            var moved = task
            moved.folderId = folderID
            update(moved)
        }
    }
```

- [ ] **Step 4: Run AppModel tests**

Run:

```bash
make test TEST_FILTER=AppModel
```

Expected: AppModel tests pass, including the five new tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/App/AppModel.swift Tests/PrioritiserTests/AppModelTests.swift
git commit -m "feat: move tasks between projects in model"
```

---

### Task 3: Emit task drag payloads from live task rows

**Files:**
- Modify: `Sources/Features/TaskList/TaskListView.swift`

- [ ] **Step 1: Keep manual reorder and add live task dragging**

In `Sources/Features/TaskList/TaskListView.swift`, replace the existing `row(_ task: TaskItem, vizMode: PriorityVizMode, reorderable: Bool)` function with:

```swift
    @ViewBuilder
    private func row(_ task: TaskItem, vizMode: PriorityVizMode, reorderable: Bool) -> some View {
        let base = TaskRowView(task: task, vizMode: vizMode)
            .draggable(DraggedTaskPayload(taskID: task.id))
        if reorderable {
            base
                .dropDestination(for: DraggedTaskPayload.self) { items, _ in
                    if let dragged = items.first { model.moveTask(dragged.taskID, before: task.id) }
                    return true
                }
        } else {
            base
        }
    }
```

- [ ] **Step 2: Make Top Priorities rows draggable too**

In `topContent`, replace this row block:

```swift
                TaskRowView(task: task, rank: vizMode == .cards ? index + 1 : nil, vizMode: vizMode)
                    .id(task.id)
```

with:

```swift
                TaskRowView(task: task, rank: vizMode == .cards ? index + 1 : nil, vizMode: vizMode)
                    .draggable(DraggedTaskPayload(taskID: task.id))
                    .id(task.id)
```

Completed view remains non-draggable because `completedContent` calls `flatRows(..., reorderable: false)` but this task intentionally makes `flatRows` live-drag-capable. That means one more change is required in the next step.

- [ ] **Step 3: Prevent Completed rows from becoming draggable**

Change the `flatRows` signature from:

```swift
    private func flatRows(_ tasks: [TaskItem], vizMode: PriorityVizMode, reorderable: Bool) -> some View {
```

To:

```swift
    private func flatRows(_ tasks: [TaskItem], vizMode: PriorityVizMode, reorderable: Bool, taskDraggable: Bool = true) -> some View {
```

Inside `flatRows`, replace:

```swift
                row(task, vizMode: vizMode, reorderable: reorderable)
                    .id(task.id)
```

with:

```swift
                row(task, vizMode: vizMode, reorderable: reorderable, taskDraggable: taskDraggable)
                    .id(task.id)
```

Then replace the `row` function from Step 1 with this final version:

```swift
    @ViewBuilder
    private func row(_ task: TaskItem, vizMode: PriorityVizMode, reorderable: Bool, taskDraggable: Bool) -> some View {
        if taskDraggable {
            let base = TaskRowView(task: task, vizMode: vizMode)
                .draggable(DraggedTaskPayload(taskID: task.id))
            if reorderable {
                base
                    .dropDestination(for: DraggedTaskPayload.self) { items, _ in
                        if let dragged = items.first { model.moveTask(dragged.taskID, before: task.id) }
                        return true
                    }
            } else {
                base
            }
        } else {
            TaskRowView(task: task, vizMode: vizMode)
        }
    }
```

Finally, in `completedContent`, replace:

```swift
                flatRows(group.tasks, vizMode: .cards, reorderable: false)
```

with:

```swift
                flatRows(group.tasks, vizMode: .cards, reorderable: false, taskDraggable: false)
```

- [ ] **Step 4: Compile**

Run:

```bash
make build
```

Expected: build succeeds. Manual reorder still compiles because the row drop destination now accepts `DraggedTaskPayload` instead of `String`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Features/TaskList/TaskListView.swift
git commit -m "feat: enable task drag payloads from list"
```

---

### Task 4: Accept task drops on sidebar projects while preserving folder drag behavior

**Files:**
- Modify: `Sources/Features/Sidebar/SidebarView.swift`

- [ ] **Step 1: Convert the Folders header to folder-only payloads**

In `foldersHeader`, replace:

```swift
        .dropDestination(for: String.self) { items, _ in
            if let dragged = items.first { model.reparentFolder(dragged, under: nil) }
            rootTargeted = false
            return true
        } isTargeted: { rootTargeted = $0 }
```

with:

```swift
        .dropDestination(for: DraggedFolderPayload.self) { items, _ in
            if let dragged = items.first { model.reparentFolder(dragged.folderID, under: nil) }
            rootTargeted = false
            return true
        } isTargeted: { rootTargeted = $0 }
```

- [ ] **Step 2: Convert folder row drag/reparent to folder payloads**

In `folderRow(_:)`, replace:

```swift
        .draggable(folder.id)
        // Drop another folder here to move it into this one (re-parent).
        .dropDestination(for: String.self) { items, _ in
            if let dragged = items.first { model.reparentFolder(dragged, under: folder.id) }
            dropTargetID = nil
            return true
        } isTargeted: { targeted in
            dropTargetID = targeted ? folder.id : (dropTargetID == folder.id ? nil : dropTargetID)
        }
```

with:

```swift
        .draggable(DraggedFolderPayload(folderID: folder.id))
        // Drop another folder here to move it into this one (re-parent).
        .dropDestination(for: DraggedFolderPayload.self) { items, _ in
            if let dragged = items.first { model.reparentFolder(dragged.folderID, under: folder.id) }
            dropTargetID = nil
            return true
        } isTargeted: { targeted in
            dropTargetID = targeted ? folder.id : (dropTargetID == folder.id ? nil : dropTargetID)
        }
        // Drop task rows here to file them into this folder/project.
        .dropDestination(for: DraggedTaskPayload.self) { items, _ in
            if let dragged = items.first {
                let ids = model.taskIDsToMove(forDraggedTaskID: dragged.taskID)
                model.moveTasks(ids, toFolder: folder.id)
            }
            dropTargetID = nil
            return true
        } isTargeted: { targeted in
            dropTargetID = targeted ? folder.id : (dropTargetID == folder.id ? nil : dropTargetID)
        }
```

- [ ] **Step 3: Convert insertion strips to folder-only payloads**

In `insertionStrip(before:depth:)`, replace:

```swift
            .dropDestination(for: String.self) { items, _ in
                if let dragged = items.first { model.moveFolder(dragged, before: folderID) }
                insertTargetID = nil
                return true
            } isTargeted: { targeted in
```

with:

```swift
            .dropDestination(for: DraggedFolderPayload.self) { items, _ in
                if let dragged = items.first { model.moveFolder(dragged.folderID, before: folderID) }
                insertTargetID = nil
                return true
            } isTargeted: { targeted in
```

- [ ] **Step 4: Compile**

Run:

```bash
make build
```

Expected: build succeeds. There should be no remaining `.dropDestination(for: String.self)` or `.draggable(folder.id)` for folder/task drag behavior.

- [ ] **Step 5: Check drag payload grep**

Run:

```bash
rg -n "dropDestination\(for: String\.self\)|draggable\(folder\.id\)|draggable\(task\.id\)" Sources
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add Sources/Features/Sidebar/SidebarView.swift
git commit -m "feat: drop tasks onto sidebar projects"
```

---

### Task 5: Final verification and manual smoke pass

**Files:**
- Modify only if verification exposes issues in files from Tasks 1-4.

- [ ] **Step 1: Run full test suite**

Run:

```bash
make test
```

Expected: all tests pass.

- [ ] **Step 2: Run full build**

Run:

```bash
make build
```

Expected: build succeeds.

- [ ] **Step 3: Launch app for manual drag smoke test**

Run:

```bash
make run
```

Expected: app launches.

Manual checks:
1. Select two live tasks in a project using existing multi-select.
2. Drag one selected task onto another sidebar project.
3. Confirm both selected tasks move there and the sidebar selection stays where it was.
4. Drag an unselected live task onto Inbox and confirm only that task moves.
5. Try dragging a task from Top Priorities or Schedule onto a project and confirm it moves.
6. Open Completed and confirm completed rows do not initiate task drags.
7. Drag/reparent/reorder folders in the sidebar and confirm existing folder behavior still works.

- [ ] **Step 4: Update changelog**

At the top of `changelog.md`, add an entry under the current unreleased section or create this section if none exists:

```markdown
## Unreleased

### Added — task drag-and-drop between projects
- Live tasks can now be dragged from the task list onto sidebar projects, including Inbox, to re-file them without leaving the current view.
- Dragging one selected task moves the whole selected set; dragging an unselected task moves only that task. Completed tasks are not draggable.
```

- [ ] **Step 5: Run final verification after changelog edit**

Run:

```bash
make test
make build
```

Expected: both pass.

- [ ] **Step 6: Commit final docs/verification change**

```bash
git add changelog.md
git commit -m "docs: note task project drag and drop"
```

---

## Self-review

Spec coverage:
- Drag live task rows to sidebar projects: Task 3 and Task 4.
- Whole selected set semantics: Task 2 model helper and Task 4 drop handler.
- Stay on current view: Task 2 `moveTasks` avoids changing `selection`.
- All live views except Completed: Task 3 adds task drags to normal/top/schedule rows and disables Completed via `taskDraggable: false`.
- Preserve order: Task 2 test and implementation do not touch sort order.
- Inbox allowed: Task 2 validates any folder, including system Inbox.
- Existing folder drag semantics: Task 4 converts folder behavior to typed payloads without changing called model methods.

Placeholder scan: no `TBD`, unresolved implementation notes, or missing code snippets remain.

Type consistency: plan consistently uses `DraggedTaskPayload.taskID`, `DraggedFolderPayload.folderID`, `AppModel.taskIDsToMove(forDraggedTaskID:)`, and `AppModel.moveTasks(_:toFolder:)`.
