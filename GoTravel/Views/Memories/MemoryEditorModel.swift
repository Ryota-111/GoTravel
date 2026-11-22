import SwiftUI
import UIKit
import Combine

/// 編集画面の中身（3.8・旅の思い出をつくる）。写真コラージュ・ポスター・日記で共通。
///
/// 1. 写真を読む許可を確かめる
/// 2. 旅行中に撮った写真を集めて採点する（数百枚あると数秒かかる）
/// 3. 前に作ったものがあれば続きから、無ければ自動で作る
/// 4. 使う写真を、枠に足りる解像度で読む
/// 直したらその場で保存する
@MainActor
final class MemoryEditorModel: ObservableObject {
    enum Phase: Equatable {
        case loading(String)
        case ready
        case denied
    }

    let plan: TravelPlan
    let kind: MemoryKind

    @Published private(set) var phase: Phase = .loading("旅行中に撮った写真を選んでいます…")
    @Published var project: MemoryProject = MemoryProject(planId: "", kind: .photoDump, templateId: "", aspect: .story)
    @Published private(set) var images: [String: UIImage] = [:]
    @Published private(set) var candidates: [TripPhotoCandidate] = []

    init(plan: TravelPlan, kind: MemoryKind) {
        self.plan = plan
        self.kind = kind
    }

    /// 写真を読む解像度（長い辺）。ポスターは1枚を大きく使うので高く、日記は小さく貼るので低く
    private var maxPixel: CGFloat {
        switch kind {
        case .poster: return 2400
        case .photoDump: return 1600
        // 日記は全ページの写真（1日4枚）を持つので小さめに。貼る大きさ（書き出しで 900px ほど）に足りる
        case .diary: return 900
        }
    }

    func start() async {
        guard phase != .ready else { return }
        guard await TripPhotoLibrary.authorize() else {
            phase = .denied
            return
        }
        candidates = await TripPhotoLibrary.candidates(for: plan, includeVideos: kind == .diary)
        if let saved = MemoryStore.load(planId: plan.id ?? "", kind: kind) {
            project = saved
        } else {
            phase = .loading("仕上げています…")
            let name = await TripPhotoLibrary.englishPlaceName(for: plan)
            project = MemoryBuilder.newProject(plan: plan, kind: kind, englishName: name, candidates: candidates)
            MemoryStore.save(project)
        }
        await loadImages()
        phase = .ready
    }

    /// 使っている写真のうち、まだ読んでいないものを読む
    func loadImages() async {
        let ids = Set(project.photos.map(\.assetId) + project.pages.flatMap { $0.entries.compactMap { $0.photo?.assetId } })
        for id in ids where images[id] == nil {
            if let image = await TripPhotoLibrary.image(assetId: id, maxPixel: maxPixel) {
                images[id] = image
            }
        }
    }

    /// 直して保存する
    func update(_ change: (inout MemoryProject) -> Void) {
        change(&project)
        MemoryStore.save(project)
    }

    /// 写真を差し替える（位置と大きさは戻す）
    func replacePhoto(_ photoId: String, assetId: String, isVideo: Bool, date: Date?) {
        update { project in
            if let index = project.photos.firstIndex(where: { $0.id == photoId }) {
                project.photos[index] = MemoryPhoto(id: photoId, assetId: assetId, isVideo: isVideo,
                                                    date: date ?? project.photos[index].date)
            }
        }
        Task { await loadImages() }
    }

    /// 写真の枠が足りないテンプレートに変えたとき、足りない分を足す
    func fillPhotos(for template: MemoryTemplate) {
        guard project.photos.count < template.photoCount else { return }
        let used = Set(project.photos.map(\.assetId))
        let more = TripPhotoLibrary.best(candidates, count: template.photoCount - project.photos.count, excluding: used)
        update { $0.photos += MemoryBuilder.photos(from: more) }
        Task { await loadImages() }
    }

    /// おまかせで選び直す
    func reshuffle() {
        update { $0.photos = MemoryBuilder.reshuffled($0, candidates: candidates) }
        Task { await loadImages() }
    }

    /// 日記をはじめから作り直す（写真と一言を、自動で選び直す）
    func rebuildDiary() {
        update { $0.pages = MemoryBuilder.diaryPages(plan: plan, candidates: candidates) }
        Task { await loadImages() }
    }

    /// 書き出す。日記は全ページ。
    /// 1枚ずつ JPEG のファイルにして、そのたびに画像を手放す（高解像度の画像を全ページぶん持つと、
    /// 長い旅行の日記で数百 MB になり、メモリ不足で止められるため）
    func renderFiles(showsWatermark: Bool) -> [URL] {
        let pages = kind == .diary ? Array(project.pages.indices) : [0]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MemoryExport", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var urls: [URL] = []
        for page in pages {
            autoreleasepool {
                guard let image = MemoryRenderer.render(templateId: project.templateId, project: project, images: images,
                                                        showsWatermark: showsWatermark, pageIndex: page),
                      let data = image.jpegData(compressionQuality: 0.92) else { return }
                let name = kind == .diary ? "Travory_\(kind.rawValue)_Day\(page + 1).jpg" : "Travory_\(kind.rawValue).jpg"
                let url = directory.appendingPathComponent(name)
                if (try? data.write(to: url, options: .atomic)) != nil { urls.append(url) }
            }
        }
        return urls
    }
}
