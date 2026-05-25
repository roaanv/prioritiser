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
