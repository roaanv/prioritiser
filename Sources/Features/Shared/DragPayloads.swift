// DragPayloads.swift
// Drag identifiers for SwiftUI drag/drop. macOS List/sidebar drops are more
// reliable with String payloads than app-private Transferable-only payloads, so
// these structs own prefixed string encoding while retaining typed intent.

import SwiftUI
import UniformTypeIdentifiers

struct DraggedTaskPayload: Codable, Hashable, Transferable {
    let taskID: String

    var dragString: String { Self.prefix + taskID }

    static func taskID(from dragString: String) -> String? {
        guard dragString.hasPrefix(prefix) else { return nil }
        let id = String(dragString.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .prioritiserTaskDragPayload)
        ProxyRepresentation(exporting: \.dragString)
    }

    private static let prefix = "io.0112.Prioritiser.drag.task:"
}

struct DraggedFolderPayload: Codable, Hashable, Transferable {
    let folderID: String

    var dragString: String { Self.prefix + folderID }

    static func folderID(from dragString: String) -> String? {
        guard dragString.hasPrefix(prefix) else { return nil }
        let id = String(dragString.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .prioritiserFolderDragPayload)
        ProxyRepresentation(exporting: \.dragString)
    }

    private static let prefix = "io.0112.Prioritiser.drag.folder:"
}

private extension UTType {
    static let prioritiserTaskDragPayload = UTType(exportedAs: "io.0112.Prioritiser.drag.task")
    static let prioritiserFolderDragPayload = UTType(exportedAs: "io.0112.Prioritiser.drag.folder")
}
