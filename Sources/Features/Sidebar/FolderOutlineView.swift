// FolderOutlineView.swift
// AppKit-backed folder tree. NSOutlineView gives the sidebar normal macOS tree
// behavior: independent disclosure, selection, context menus, and drag/drop.

import AppKit
import SwiftUI

struct FolderOutlineView: NSViewRepresentable {
    var model: AppModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let column = NSTableColumn(identifier: .folderOutlineColumn)
        column.resizingMask = .autoresizingMask

        let outlineView = NSOutlineView()
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowHeight = 22
        outlineView.indentationPerLevel = 14
        outlineView.intercellSpacing = NSSize(width: 0, height: 1)
        outlineView.style = .sourceList
        outlineView.backgroundColor = .clear
        outlineView.allowsEmptySelection = true
        outlineView.allowsMultipleSelection = false
        outlineView.autoresizesOutlineColumn = true
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator
        outlineView.registerForDraggedTypes([.string])
        outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
        outlineView.setDraggingSourceOperationMask(.move, forLocal: false)

        let menu = NSMenu()
        menu.delegate = context.coordinator
        outlineView.menu = menu

        context.coordinator.outlineView = outlineView

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = outlineView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let outlineView = scrollView.documentView as? NSOutlineView else { return }
        context.coordinator.model = model
        context.coordinator.reload(outlineView)
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let folderOutlineColumn = NSUserInterfaceItemIdentifier("FolderOutlineColumn")
    static let folderCell = NSUserInterfaceItemIdentifier("FolderCell")
}

private final class OutlineFolderNode: NSObject {
    let folder: Folder
    var children: [OutlineFolderNode] = []

    init(folder: Folder) {
        self.folder = folder
    }
}

private final class FolderCellView: NSTableCellView {
    private let stack = NSStackView()
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let badgeField = NSTextField(labelWithString: "")

    var folderID: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = .folderCell

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        nameField.lineBreakMode = .byTruncatingTail
        nameField.isEditable = true
        nameField.isSelectable = true
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.focusRingType = .none
        nameField.usesSingleLineMode = true
        nameField.cell?.isScrollable = true
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        badgeField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        badgeField.textColor = .secondaryLabelColor
        badgeField.alignment = .right
        badgeField.setContentHuggingPriority(.required, for: .horizontal)

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(badgeField)
        addSubview(stack)

        textField = nameField
        imageView = iconView

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(folder: Folder, count: Int, delegate: NSTextFieldDelegate) {
        folderID = folder.id
        nameField.stringValue = folder.name
        nameField.delegate = delegate
        nameField.identifier = NSUserInterfaceItemIdentifier(folder.id)
        iconView.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        iconView.contentTintColor = folder.color.nsColor
        badgeField.stringValue = count > 0 ? String(count) : ""
    }
}

@MainActor
final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate, NSTextFieldDelegate {
    var model: AppModel
    weak var outlineView: NSOutlineView?

    private var roots: [OutlineFolderNode] = []
    private var nodesByID: [String: OutlineFolderNode] = [:]
    private var contextFolderID: String?
    private var isApplyingModel = false
    /// Last folder-edit request we acted on, so a single request begins editing
    /// once even though `reload` runs on every model change.
    private var lastFolderEditToken = 0

    init(model: AppModel) {
        self.model = model
        super.init()
        rebuildTree()
    }

    func reload(_ outlineView: NSOutlineView) {
        isApplyingModel = true
        rebuildTree()
        outlineView.reloadData()

        for id in model.expandedFolders {
            if let node = nodesByID[id] {
                outlineView.expandItem(node, expandChildren: false)
            }
        }

        if case .folder(let selectedID) = model.selection,
           let node = nodesByID[selectedID] {
            let row = outlineView.row(forItem: node)
            if row >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            } else {
                outlineView.deselectAll(nil)
            }
        } else {
            outlineView.deselectAll(nil)
        }

        // A new folder (or "Rename") asked for inline editing. The tree has just
        // been rebuilt and any parent expanded, so the target row now exists.
        if model.folderEditToken != lastFolderEditToken {
            lastFolderEditToken = model.folderEditToken
            if let id = model.pendingFolderEdit {
                beginEditing(folderID: id, in: outlineView)
            }
        }
        isApplyingModel = false
    }

    private func rebuildTree() {
        roots.removeAll(keepingCapacity: true)
        nodesByID.removeAll(keepingCapacity: true)

        for folder in model.folders {
            nodesByID[folder.id] = OutlineFolderNode(folder: folder)
        }

        for folder in model.folders {
            guard let node = nodesByID[folder.id] else { continue }
            if let parentID = folder.parentId, let parent = nodesByID[parentID] {
                parent.children.append(node)
            } else {
                roots.append(node)
            }
        }
    }

    private func node(from item: Any?) -> OutlineFolderNode? {
        item as? OutlineFolderNode
    }

    private func children(of item: Any?) -> [OutlineFolderNode] {
        node(from: item)?.children ?? roots
    }

    private func pasteboardString(_ pasteboard: NSPasteboard) -> String? {
        if let string = pasteboard.string(forType: .string) {
            return string
        }
        return pasteboard.pasteboardItems?.lazy.compactMap { $0.string(forType: .string) }.first
    }

    // MARK: - Data source

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        children(of: item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        children(of: item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !children(of: item).isEmpty
    }

    // MARK: - Rows

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = node(from: item) else { return nil }
        let cell = outlineView.makeView(withIdentifier: .folderCell, owner: self) as? FolderCellView ?? FolderCellView()
        let count = TaskFilter.folderCount(node.folder.id, tasks: model.tasks, folders: model.folders)
        cell.configure(folder: node.folder, count: count, delegate: self)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingModel,
              let outlineView = notification.object as? NSOutlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? OutlineFolderNode else { return }
        model.selection = .folder(node.folder.id)
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !isApplyingModel,
              let node = notification.userInfo?["NSObject"] as? OutlineFolderNode else { return }
        model.expandedFolders.insert(node.folder.id)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !isApplyingModel,
              let node = notification.userInfo?["NSObject"] as? OutlineFolderNode else { return }
        model.expandedFolders.remove(node.folder.id)
    }

    // MARK: - Editing

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              let folderID = field.identifier?.rawValue else { return }
        model.renameFolder(id: folderID, to: field.stringValue)
    }

    @objc private func addSubfolderToContextFolder() {
        guard let folderID = contextFolderID else { return }
        let id = model.addFolder(name: "New Folder", parentId: folderID)
        model.selection = .folder(id)
        model.requestFolderEdit(id: id)
    }

    /// Begin inline-editing a newly created folder's name. Deferred one run-loop
    /// turn so it runs after the SwiftUI reload that adding the folder schedules,
    /// by which point the row exists and is stable.
    ///
    /// This mirrors the one gesture that reliably edits — selecting a row and
    /// pressing Return: the *outline view* must be first responder, then editing
    /// starts through `editColumn`, the same entry point Return uses internally.
    /// (Focusing the cell's text field directly bypasses the table's field-editor
    /// setup and silently fails to engage.) The row is left selected and the
    /// outline view focused, so even if editing doesn't auto-start, pressing
    /// Return immediately renames.
    private func beginEditing(folderID: String, in outlineView: NSOutlineView) {
        Task { @MainActor in
            guard let node = nodesByID[folderID] else { return }
            let row = outlineView.row(forItem: node)
            guard row >= 0 else { return }
            outlineView.scrollRowToVisible(row)
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.window?.makeFirstResponder(outlineView)
            outlineView.editColumn(0, row: row, with: nil, select: true)
        }
    }

    @objc private func moveContextFolderToRoot() {
        guard let folderID = contextFolderID else { return }
        model.reparentFolder(folderID, under: nil)
    }

    @objc private func deleteContextFolder() {
        guard let folderID = contextFolderID else { return }
        model.deleteFolder(id: folderID)
    }

    // MARK: - Context menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let outlineView else { return }

        let row = outlineView.clickedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? OutlineFolderNode else {
            contextFolderID = nil
            return
        }

        contextFolderID = node.folder.id
        outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        model.selection = .folder(node.folder.id)

        menu.addItem(NSMenuItem(title: "New Subfolder", action: #selector(addSubfolderToContextFolder), keyEquivalent: ""))

        if !node.folder.isSystem && node.folder.parentId != nil {
            menu.addItem(NSMenuItem(title: "Move to Top Level", action: #selector(moveContextFolderToRoot), keyEquivalent: ""))
        }
        if !node.folder.isSystem {
            menu.addItem(.separator())
            let delete = NSMenuItem(title: "Delete", action: #selector(deleteContextFolder), keyEquivalent: "")
            delete.attributedTitle = NSAttributedString(string: "Delete", attributes: [.foregroundColor: NSColor.systemRed])
            menu.addItem(delete)
        }

        for item in menu.items {
            item.target = self
        }
    }

    // MARK: - Drag and drop

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let node = node(from: item), !node.folder.isSystem else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(DraggedFolderPayload(folderID: node.folder.id).dragString, forType: .string)
        return pasteboardItem
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        validateDrop info: NSDraggingInfo,
        proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        guard let raw = pasteboardString(info.draggingPasteboard) else { return [] }

        if DraggedTaskPayload.taskID(from: raw) != nil {
            guard item is OutlineFolderNode else { return [] }
            outlineView.setDropItem(item, dropChildIndex: NSOutlineViewDropOnItemIndex)
            return .move
        }

        guard let draggedFolderID = DraggedFolderPayload.folderID(from: raw),
              let dragged = model.folder(id: draggedFolderID),
              !dragged.isSystem else { return [] }

        if let target = node(from: item), target.folder.id == draggedFolderID {
            return []
        }
        return .move
    }

    func outlineView(
        _ outlineView: NSOutlineView,
        acceptDrop info: NSDraggingInfo,
        item: Any?,
        childIndex index: Int
    ) -> Bool {
        guard let raw = pasteboardString(info.draggingPasteboard) else { return false }

        if let taskID = DraggedTaskPayload.taskID(from: raw),
           let target = node(from: item) {
            let ids = model.taskIDsToMove(forDraggedTaskID: taskID)
            model.moveTasks(ids, toFolder: target.folder.id)
            return true
        }

        guard let draggedFolderID = DraggedFolderPayload.folderID(from: raw) else { return false }

        if index == NSOutlineViewDropOnItemIndex {
            guard let target = node(from: item) else { return false }
            model.reparentFolder(draggedFolderID, under: target.folder.id)
            return true
        }

        let parentID = node(from: item)?.folder.id
        let siblings = children(of: item)
        if index >= 0 && index < siblings.count {
            model.moveFolder(draggedFolderID, before: siblings[index].folder.id)
        } else {
            model.reparentFolder(draggedFolderID, under: parentID)
        }
        return true
    }
}

private extension OKLCH {
    var nsColor: NSColor {
        let components = srgb
        return NSColor(
            srgbRed: CGFloat(components.r),
            green: CGFloat(components.g),
            blue: CGFloat(components.b),
            alpha: 1
        )
    }
}
