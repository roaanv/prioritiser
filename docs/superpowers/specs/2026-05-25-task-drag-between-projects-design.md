# Task drag-and-drop between projects — design

## Summary

Add drag-and-drop refiling of tasks from the task list onto projects in the sidebar. A user can select multiple live tasks, drag any selected row, and drop onto a project or Inbox to move the whole selected set there. The app stays on the current view after the drop; moved tasks may disappear if they no longer match that view.

## Scope

Included:
- Drag live task rows from task list layouts onto sidebar folders/projects.
- Move the whole current task selection when the dragged task is selected.
- Move only the dragged task when it is not selected.
- Allow Inbox as a destination.
- Preserve task order and `sort_order`; the operation only changes `folderId`.
- Log existing folder-change activity using the normal task update path.

Excluded:
- Dragging completed tasks.
- Dropping tasks on smart views.
- Dropping tasks on the sidebar `Folders` header.
- Reordering tasks within a destination project as part of the project move.
- Confirmation dialogs for moving tasks.

## User interaction

Task rows are draggable in all live task list contexts, including project views, smart views, search results, filtered lists, Top Priorities, and Schedule. Completed view rows are not draggable.

Sidebar folder rows accept task drops. Dropping task payloads on a folder row moves the resolved task set into that folder and keeps the current sidebar selection unchanged. Native SwiftUI drag behavior provides the initial affordance; if testing shows the target is too subtle, the sidebar row hover highlight can be refined without changing the model design.

Existing folder drag behavior remains unchanged:
- Drop folder on row body: move folder into that folder.
- Drop folder on top-edge strip: reorder before that folder.
- Drop folder on `Folders` header: move folder to top level.

Task drops are ignored by folder insertion strips and the `Folders` header because there is no meaningful task operation for those targets.

## Architecture

Introduce typed drag payloads instead of reusing raw `String` IDs:
- `DraggedTaskPayload`, carrying a task ID.
- `DraggedFolderPayload`, carrying a folder ID.

Typed payloads avoid collisions between task IDs and folder IDs and make sidebar drop destinations explicit. Task list rows emit task payloads. Sidebar folder rows emit and accept folder payloads for existing folder operations, and separately accept task payloads for task refiling.

## Model changes

Add an `AppModel` helper to resolve the effective task move set:

- `taskIDsToMove(forDraggedTaskID:) -> Set<String>`
  - If the dragged task ID is in `selectedTaskIDs`, return selected IDs that still exist.
  - Otherwise return the dragged ID if it exists.
  - Return an empty set for stale or unknown IDs.

Add the mutation:

- `moveTasks(_ ids: Set<String>, toFolder folderID: String)`
  - Validate that the destination folder exists.
  - Ignore empty move sets.
  - For each existing task whose folder differs, set `folderId` and persist through `update(_:)`.
  - Rely on existing `logChanges(from:to:)` to write `.folderChanged` activity.
  - Do not change the `tasks` array order or persisted sort order.
  - Do not change `selection` or navigate to the destination folder.
  - Keep task selection stable; stale IDs may be pruned by the resolver.

## Data flow

1. User starts dragging a task row.
2. The row provides `DraggedTaskPayload(taskID: task.id)`.
3. User drops on a sidebar folder row.
4. Sidebar resolves selected-vs-single move semantics through `AppModel.taskIDsToMove(forDraggedTaskID:)`.
5. Sidebar calls `AppModel.moveTasks(_:toFolder:)`.
6. `visibleTasks` recomputes from the current view/search/filter. If moved tasks no longer match the current view, they disappear from the list.

## Error handling and edge cases

- Unknown task ID: no-op.
- Unknown destination folder ID: no-op.
- Dropping a task onto its current folder: no-op for that task.
- Mixed selected tasks from multiple folders: all selected existing live tasks move to the destination.
- Completed view: rows are not draggable, so completed tasks are not moved through this interaction.
- Folder and task drag payloads are handled separately, so folder reparenting cannot accidentally move a task and task drops cannot accidentally reorder folders.

## Tests

Add model tests covering:
- Dragging a selected task moves the whole selected set to the target folder.
- Dragging an unselected task moves only that task.
- Moving tasks preserves `tasks` array order.
- Moving tasks logs folder-change activity.
- Moving to an unknown folder is a no-op.

UI behavior should be manually checked after implementation:
- Drag selected task set from a project view to another project.
- Drag selected task set from a smart view/search result to a project.
- Drop onto Inbox.
- Verify Completed rows do not drag.
- Verify folder drag/reparent/reorder still works.
