// DragPayloadTests.swift
// Regression coverage for custom Transferable payload UTTypes. macOS drag/drop
// expects custom UTTypes to be exported by the app bundle, not just declared in code.

import Foundation
import Testing
@testable import Prioritiser

@Suite("DragPayloads")
struct DragPayloadTests {
    @Test func customDragPayloadTypesAreDeclaredInAppBundle() throws {
        let declarations = try #require(
            Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations") as? [[String: Any]]
        )

        let taskDeclaration = declaration("io.0112.Prioritiser.drag.task", in: declarations)
        let folderDeclaration = declaration("io.0112.Prioritiser.drag.folder", in: declarations)

        #expect(taskDeclaration != nil)
        #expect(folderDeclaration != nil)
        #expect(conformsToPublicData(taskDeclaration))
        #expect(conformsToPublicData(folderDeclaration))
    }

    private func declaration(_ identifier: String, in declarations: [[String: Any]]) -> [String: Any]? {
        declarations.first { $0["UTTypeIdentifier"] as? String == identifier }
    }

    private func conformsToPublicData(_ declaration: [String: Any]?) -> Bool {
        guard let conformsTo = declaration?["UTTypeConformsTo"] as? [String] else { return false }
        return conformsTo.contains("public.data")
    }
}
