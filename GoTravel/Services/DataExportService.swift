import Foundation
import CoreData
import AppleArchive
import System

/// データの書き出し・読み込み（3.0、`docs/設計_3.0.md` 3章）。
///
/// - 書き出し：すべてのデータを1つのファイル（.travory）にまとめる。写真を入れるかは選べる
/// - 読み込み：ID で突き合わせ、端末に無いものを足す。**読み込みで消すことはしない**
///
/// ファイルは Apple Archive で1つにまとめたフォルダ（manifest は data.json の中）
enum DataExportService {

    static let fileExtension = "travory"
    static let dataFileName = "data.json"
    static let imagesFolder = "images"

    enum ExportError: LocalizedError {
        case failed
        case unreadable

        var errorDescription: String? {
            switch self {
            case .failed: return "書き出せませんでした。iPhone の空き容量をご確認のうえ、もう一度お試しください。"
            case .unreadable: return "このファイルは読み込めませんでした。Travory で書き出したファイル（.travory）を選んでください。"
            }
        }
    }

    // MARK: - 集める

    /// 今の人のデータを集める。写真は場所だけを集め、ファイルは書き出すときに入れる
    static func collect(userId: String, context: NSManagedObjectContext) -> TravoryExport {
        var export = TravoryExport()
        export.appVersion = FeedbackService.appVersion
        export.userId = userId

        context.performAndWait {
            let travelEntities = (try? TravelPlanEntity.fetchByUser(userId: userId, context: context)) ?? []
            // 共有で参加した計画も、手元にある分は残す（userId は自分）
            export.travelPlans = travelEntities.map { .init(plan: $0.toTravelPlan(), deletedAt: $0.deletedAt) }
            export.plans = ((try? PlanEntity.fetchByUser(userId: userId, context: context)) ?? []).map { $0.toPlan() }
            export.places = ((try? VisitedPlaceEntity.fetchByUser(userId: userId, context: context)) ?? []).map { $0.toVisitedPlace() }
            export.tags = ((try? PlanTagEntity.fetchByUser(userId: userId, context: context)) ?? []).map { $0.toTag() }
            let categoryRequest = PlanCategoryEntity.fetchRequest()
            categoryRequest.predicate = NSPredicate(format: "userId == %@", userId)
            export.planCategories = ((try? context.fetch(categoryRequest)) ?? []).map { $0.toCategory() }
            export.categories = ((try? PlaceCategoryEntity.fetchByUser(userId: userId, context: context)) ?? []).map { $0.toCategory() }
            export.packingPresets = ((try? PackingPresetEntity.fetchByUser(userId: userId, context: context)) ?? []).compactMap { entity in
                guard let id = entity.id, let name = entity.name, let kind = entity.kind else { return nil }
                return .init(id: id, name: name, kind: kind, order: Int(entity.order), createdAt: entity.createdAt)
            }
            export.tasks = ((try? TaskEntity.fetchByUser(userId: userId, context: context)) ?? []).map { $0.toTaskItem() }
            export.albums = ((try? AlbumEntity.fetchByUser(userId: userId, context: context)) ?? []).map { $0.toAlbum() }
        }
        return export
    }

    /// 入れられる写真（端末にあるものだけ）
    static func imagePaths(for export: TravoryExport) -> [String] {
        var names: [String] = []
        names += export.travelPlans.compactMap(\.plan.localImageFileName).map { "Documents/\($0)" }
        names += export.places.compactMap(\.localPhotoFileName).map { "Documents/\($0)" }
        names += export.plans.compactMap(\.localImageFileName).map { "Documents/\($0)" }
        names += export.albums.flatMap(\.photoFileNames).map { "Albums/\($0)" }
        var seen = Set<String>()
        return names.filter { path in
            guard !seen.contains(path), FileManager.default.fileExists(atPath: localURL(for: path).path) else { return false }
            seen.insert(path)
            return true
        }
    }

    /// 写真のだいたいの大きさ（バイト）
    static func imagesSize(_ paths: [String]) -> Int64 {
        paths.reduce(0) { total, path in
            let size = (try? FileManager.default.attributesOfItem(atPath: localURL(for: path).path)[.size] as? NSNumber)?.int64Value ?? 0
            return total + size
        }
    }

    /// 写真の場所として受け付けるか。ファイルの中身は外から来るので、
    /// "Documents/" か "Albums/" の下の、上の階層へ出ない名前だけを受け付ける
    static func isSafeImagePath(_ path: String) -> Bool {
        guard path.hasPrefix("Documents/") || path.hasPrefix("Albums/") else { return false }
        let parts = path.split(separator: "/")
        return parts.count >= 2 && !parts.contains("..") && !parts.contains(".") && !path.contains("\\")
    }

    /// "Documents/xxx.jpg" → 端末の中の場所
    static func localURL(for path: String) -> URL {
        let documents = FileManager.documentsDirectory()
        if path.hasPrefix("Albums/") {
            return documents.appendingPathComponent(path)
        }
        return documents.appendingPathComponent(String(path.dropFirst("Documents/".count)))
    }

    // MARK: - 書き出す

    /// .travory ファイルを作る。作った場所を返す
    static func writeFile(_ base: TravoryExport, includesImages: Bool, now: Date = Date()) throws -> URL {
        var export = base
        export.exportedAt = now
        export.userId = nil   // ファイルには利用者の ID を入れない
        export.imagePaths = includesImages ? imagePaths(for: export) : []

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("TravoryExport-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: work) }
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let data = try TravoryExport.encoder().encode(export)
        try data.write(to: work.appendingPathComponent(dataFileName))

        for path in export.imagePaths {
            let destination = work.appendingPathComponent(imagesFolder).appendingPathComponent(path)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.copyItem(at: localURL(for: path), to: destination)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let file = fm.temporaryDirectory.appendingPathComponent("Travory_\(formatter.string(from: now)).\(fileExtension)")
        try? fm.removeItem(at: file)
        try archive(directory: work, to: file)
        return file
    }

    // MARK: - 読む

    struct OpenedFile {
        let export: TravoryExport
        /// 中身を広げたフォルダ（写真を取り出すのに使う。使い終わったら消す）
        let folder: URL
    }

    static func open(_ file: URL) throws -> OpenedFile {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("TravoryImport-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }

        do {
            try extract(file, to: folder)
            let data = try Data(contentsOf: folder.appendingPathComponent(dataFileName))
            let export = try TravoryExport.decoder().decode(TravoryExport.self, from: data)
            return OpenedFile(export: export, folder: folder)
        } catch {
            try? fm.removeItem(at: folder)
            throw ExportError.unreadable
        }
    }

    // MARK: - 読み込む

    struct ImportResult: Equatable {
        var added = 0
        var replaced = 0
        var kept = 0
        var images = 0

        var message: String {
            var parts = ["\(added)件を足しました"]
            if replaced > 0 { parts.append("\(replaced)件をファイルの内容にしました") }
            if kept > 0 { parts.append("すでにあった\(kept)件はそのままにしました") }
            if images > 0 { parts.append("写真を\(images)枚戻しました") }
            return parts.joined(separator: "。") + "。"
        }
    }

    /// ID で突き合わせて読み込む。端末に無いものを足し、読み込みで消すことはしない。
    /// 持ち主は今の人に付け替え、共有の情報は外す（`TravoryImportRule`）
    @discardableResult
    static func apply(_ export: TravoryExport, userId: String, context: NSManagedObjectContext,
                      imagesFolder: URL? = nil, mode: TravoryImportRule.Mode = .addMissing,
                      now: Date = Date()) -> ImportResult {
        var result = ImportResult()

        context.performAndWait {
            for record in export.travelPlans {
                guard let id = record.plan.id else { continue }
                let local = try? TravelPlanEntity.fetchById(id: id, context: context)
                if mode == .restore, let local {
                    let current = local.toTravelPlan()
                    let restored = TravoryImportRule.restored(record.plan, over: current, userId: userId, now: now)
                    if TravoryImportRule.isSame(restored, as: current) && local.deletedAt == record.deletedAt {
                        result.kept += 1
                    } else {
                        local.update(from: restored)
                        local.deletedAt = record.deletedAt
                        result.replaced += 1
                    }
                    continue
                }
                let action = TravoryImportRule.travelPlanAction(
                    fileUpdatedAt: record.plan.updatedAt,
                    localUpdatedAt: local.map { $0.updatedAt ?? .distantPast },
                    localIsShared: local?.isShared?.boolValue ?? false)
                switch action {
                case .add:
                    let entity = TravelPlanEntity.create(from: TravoryImportRule.detached(record.plan, userId: userId), context: context)
                    entity.deletedAt = record.deletedAt
                    result.added += 1
                case .replace:
                    local?.update(from: TravoryImportRule.detached(record.plan, userId: userId))
                    local?.deletedAt = record.deletedAt
                    result.replaced += 1
                case .keep:
                    result.kept += 1
                }
            }

            for plan in export.plans {
                if let local = try? PlanEntity.fetchById(id: plan.id, context: context) {
                    if mode == .restore,
                       let restored = TravoryImportRule.restored(plan, over: local.toPlan(), userId: userId, now: now) {
                        local.update(from: restored)
                        result.replaced += 1
                    } else {
                        result.kept += 1
                    }
                    continue
                }
                var copy = plan
                copy.userId = userId
                // カテゴリはそのまま（カテゴリも一緒に戻す。共有の情報はカテゴリの側で外す）
                _ = PlanEntity.create(from: copy, context: context)
                result.added += 1
            }

            for place in export.places {
                if let id = place.id, let local = try? VisitedPlaceEntity.fetchById(id: id, context: context) {
                    if mode == .restore,
                       let restored = TravoryImportRule.restored(place, over: local.toVisitedPlace(), userId: userId) {
                        local.update(from: restored)
                        result.replaced += 1
                    } else {
                        result.kept += 1
                    }
                    continue
                }
                var copy = place
                copy.userId = userId
                _ = VisitedPlaceEntity.create(from: copy, context: context)
                result.added += 1
            }

            // 予定のカテゴリ。共有の情報は外して、自分だけのカテゴリとして戻す
            // （ほかの人の共有を書き換えたり、共有コードを持ち主でない人が引き継いだりしないため）
            for category in export.planCategories where (try? PlanCategoryEntity.fetchById(id: category.id, context: context)) == nil {
                var copy = category
                copy.isShared = false
                copy.shareCode = nil
                copy.ownerId = nil
                copy.sharedWith = []
                PlanCategoryEntity(context: context).update(from: copy, userId: userId)
            }

            // タグ・カテゴリー・持ち物の候補・やること・アルバムは件数に数えない（付随するもの）
            for tag in export.tags where (try? PlanTagEntity.fetchById(id: tag.id, context: context)) == nil {
                _ = PlanTagEntity.create(from: tag, userId: userId, context: context)
            }
            for category in export.categories where !category.isDefault
                && (try? PlaceCategoryEntity.fetchById(id: category.id, context: context)) == nil {
                _ = PlaceCategoryEntity.create(from: category, userId: userId, context: context)
            }

            let existingPresets = ((try? PackingPresetEntity.fetchByUser(userId: userId, context: context)) ?? [])
            let presetKeys = Set(existingPresets.compactMap { entity in entity.name.map { "\(entity.kind ?? ""):\($0)" } })
            let presetIds = Set(existingPresets.compactMap(\.id))
            for preset in export.packingPresets
            where !presetIds.contains(preset.id) && !presetKeys.contains("\(preset.kind):\(preset.name)") {
                let entity = PackingPresetEntity(context: context)
                entity.id = preset.id
                entity.name = preset.name
                entity.kind = preset.kind
                entity.order = Int32(preset.order)
                entity.createdAt = preset.createdAt ?? Date()
                entity.userId = userId
            }

            for task in export.tasks where (try? TaskEntity.fetchById(id: task.id, context: context)) == nil {
                TaskEntity.create(from: task, userId: userId, context: context)
            }

            let localAlbums = ((try? AlbumEntity.fetchByUser(userId: userId, context: context)) ?? [])
            for album in export.albums {
                if let same = localAlbums.first(where: { $0.id == album.id }) ?? defaultAlbum(like: album, in: localAlbums) {
                    // 同じアルバム（または、どの人にも1つずつある既定のアルバム）なら、写真を足すだけにする。
                    // 既定のアルバムを2つ作ると、フォトマップが2つになる
                    var merged = same.toAlbum()
                    let missing = album.photoFileNames.filter { !merged.photoFileNames.contains($0) }
                    if !missing.isEmpty {
                        merged.photoFileNames += missing
                        merged.updatedAt = Date()
                        same.update(from: merged)
                    }
                    continue
                }
                var copy = album
                copy.userId = userId
                _ = AlbumEntity.create(from: copy, context: context)
            }

            if context.hasChanges {
                try? context.save()
            }
        }

        if let imagesFolder {
            result.images = restoreImages(export.imagePaths, from: imagesFolder)
        }
        return result
    }

    private static func defaultAlbum(like album: Album, in locals: [AlbumEntity]) -> AlbumEntity? {
        guard album.isDefaultAlbum || album.type == .japan else { return nil }
        return locals.first { $0.isDefaultAlbum == album.isDefaultAlbum && $0.albumType == album.type.rawValue }
    }

    /// 写真を戻す。端末にもうあるものは触らない
    private static func restoreImages(_ paths: [String], from folder: URL) -> Int {
        let fm = FileManager.default
        var count = 0
        for path in paths where isSafeImagePath(path) {
            let source = folder.appendingPathComponent(imagesFolder).appendingPathComponent(path)
            let destination = localURL(for: path)
            guard fm.fileExists(atPath: source.path), !fm.fileExists(atPath: destination.path) else { continue }
            try? fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? fm.copyItem(at: source, to: destination)) != nil { count += 1 }
        }
        return count
    }

    // MARK: - Apple Archive

    static func archive(directory: URL, to file: URL) throws {
        guard let write = ArchiveByteStream.fileStream(
                path: FilePath(file.path), mode: .writeOnly, options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)) else { throw ExportError.failed }
        defer { try? write.close() }
        guard let compress = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: write) else { throw ExportError.failed }
        defer { try? compress.close() }
        guard let encode = ArchiveStream.encodeStream(writingTo: compress) else { throw ExportError.failed }
        defer { try? encode.close() }
        guard let keys = ArchiveHeader.FieldKeySet("TYP,PAT,DAT,MOD,MTM") else { throw ExportError.failed }
        try encode.writeDirectoryContents(archiveFrom: FilePath(directory.path), keySet: keys)
    }

    static func extract(_ file: URL, to folder: URL) throws {
        guard let read = ArchiveByteStream.fileStream(
                path: FilePath(file.path), mode: .readOnly, options: [],
                permissions: FilePermissions(rawValue: 0o644)) else { throw ExportError.unreadable }
        defer { try? read.close() }
        guard let decompress = ArchiveByteStream.decompressionStream(readingFrom: read) else { throw ExportError.unreadable }
        defer { try? decompress.close() }
        guard let decode = ArchiveStream.decodeStream(readingFrom: decompress) else { throw ExportError.unreadable }
        defer { try? decode.close() }
        guard let extract = ArchiveStream.extractStream(extractingTo: FilePath(folder.path),
                                                        flags: [.ignoreOperationNotPermitted]) else { throw ExportError.unreadable }
        defer { try? extract.close() }
        _ = try ArchiveStream.process(readingFrom: decode, writingTo: extract)
    }
}
