import Foundation
import SwiftData

private let backupEntryName = "backup.json"

private let backupJSONEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

private let backupJSONDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

/// Snapshots the current tree and writes it as a `.tar.gz` to `url`.
///
/// Writes directly to `url` with `Data`'s own atomic-write option, rather
/// than manually staging a sibling temp file and renaming it into place: a
/// save panel's App Sandbox grant covers only the exact file the user
/// picked, not the rest of its containing folder, so a hand-rolled temp
/// file living next to it fails with a sandbox permission error even though
/// `url` itself is perfectly writable. `.atomic` still avoids ever leaving
/// a partial file at the destination.
func performBackup(context: ModelContext, to url: URL) throws {
    let document = buildBackupDocument(context: context)
    let json = try backupJSONEncoder.encode(document)
    let archive = try makeTarGz(jsonData: json, entryName: backupEntryName)
    try archive.write(to: url, options: .atomic)
}

/// Reads and validates a `.tar.gz` at `url` as a QuickText backup, without
/// touching the current tree. Call this before `performRestore` so an
/// invalid file is rejected without deleting anything.
func validateBackup(at url: URL) throws -> BackupDocument {
    let archive = try Data(contentsOf: url)
    let json = try extractJSON(fromTarGz: archive)
    return try backupJSONDecoder.decode(BackupDocument.self, from: json)
}

/// Replaces the entire current tree with `document`'s contents.
func performRestore(_ document: BackupDocument, context: ModelContext) {
    applyBackupDocument(document, context: context)
}
