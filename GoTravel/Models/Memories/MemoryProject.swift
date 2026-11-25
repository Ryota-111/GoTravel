import Foundation
import CoreGraphics

// MARK: - 旅の思い出をつくる（3.8）
//
// 旅行中に撮った写真から、写真コラージュ（コラージュ）・旅行ポスター・旅行日記の画像を作る。
// 写真はカメラロールの id（localIdentifier）で指すだけで、写しは持たない（容量を増やさない）。
// 作ったものは端末の中の JSON に置く（Core Data に足すと CloudKit の Production へ反映が要るため）。
// 日記は自分だけのもの。共有した旅行でも、同行者には送らない

/// 作るものの種類
enum MemoryKind: String, Codable, CaseIterable, Identifiable {
    case photoDump
    case poster
    case diary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photoDump: return "写真コラージュ"
        case .poster: return "旅行ポスター"
        case .diary: return "旅行日記"
        }
    }

    var subtitle: String {
        switch self {
        case .photoDump: return "旅の写真をおしゃれな1枚に"
        case .poster: return "旅の記念ポスターを1枚に"
        case .diary: return "1日ずつ、写真と一言で振り返る"
        }
    }

    var icon: String {
        switch self {
        case .photoDump: return "square.grid.3x3.square"
        case .poster: return "photo.artframe"
        case .diary: return "book.pages"
        }
    }
}

/// 書き出す画像の比率。Instagram のストーリー・投稿・正方形
enum MemoryAspect: String, Codable, CaseIterable, Identifiable {
    case story
    case feed
    case square

    var id: String { rawValue }

    var label: String {
        switch self {
        case .story: return "ストーリー（9:16）"
        case .feed: return "投稿（4:5）"
        case .square: return "正方形（1:1）"
        }
    }

    /// 組み立てるときの大きさ（pt）。書き出すときは2倍の解像度にする
    var canvasSize: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .feed: return CGSize(width: 1080, height: 1350)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

/// 枠に入れた写真1枚。位置と大きさは、作ったあとに自分で直せる
struct MemoryPhoto: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    /// カメラロールの写真・動画の id（localIdentifier）
    var assetId: String
    /// 枠の中でずらした量（組み立ての pt）。枠からはみ出さない範囲に、描くときに収める
    var offset: CGSize = .zero
    /// 枠いっぱいに敷いた大きさからの拡大（1 以上）
    var scale: CGFloat = 1
    var isVideo = false
    /// 撮った日時（日記の並びと見出しに使う）
    var date: Date?
}

/// 日記の1項目（写真と一言）
struct DiaryEntry: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var time: Date?
    var text: String = ""
    var photo: MemoryPhoto?
}

/// 日記の1ページ（1日）
struct DiaryPage: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var dayNumber: Int
    var date: Date
    /// その日のひとこと（見出しの下）
    var headline: String = ""
    var entries: [DiaryEntry] = []
}

/// 作ったもの1つ。旅行と種類ごとに1つ持ち、開き直すと続きから直せる
struct MemoryProject: Codable, Equatable, Identifiable {
    var id: String { "\(planId)_\(kind.rawValue)" }
    var planId: String
    var kind: MemoryKind
    var templateId: String
    var aspect: MemoryAspect
    var photos: [MemoryPhoto] = []
    /// 題（「Okinawa Trip」「OKINAWA」など）
    var title: String = ""
    /// 期間などの小さな文字
    var subtitle: String = ""
    /// ひとこと（「Good Memories ♡」「A Journey to Remember」など）
    var note: String = ""
    /// ポスターの緯度経度などの添え書き
    var detail: String = ""
    /// 日数などの小見出し（「3 DAYS」）
    var badge: String = ""
    var pages: [DiaryPage] = []
    var updatedAt = Date()
}

/// 作ったものを端末の中に保存する（`Documents/Memories/<旅行の id>_<種類>.json`）
enum MemoryStore {
    private static var directory: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Memories", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func url(planId: String, kind: MemoryKind) -> URL {
        directory.appendingPathComponent("\(planId)_\(kind.rawValue).json")
    }

    static func load(planId: String, kind: MemoryKind) -> MemoryProject? {
        guard let data = try? Data(contentsOf: url(planId: planId, kind: kind)) else { return nil }
        return try? JSONDecoder().decode(MemoryProject.self, from: data)
    }

    static func save(_ project: MemoryProject) {
        var project = project
        project.updatedAt = Date()
        guard let data = try? JSONEncoder().encode(project) else { return }
        try? data.write(to: url(planId: project.planId, kind: project.kind), options: .atomic)
    }

    static func delete(planId: String, kind: MemoryKind) {
        try? FileManager.default.removeItem(at: url(planId: planId, kind: kind))
    }
}
