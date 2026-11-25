import Foundation
import SwiftUI

/// 旅行と写真から、はじめの形を自動で作る（3.8・旅の思い出をつくる）。
/// 写真を選ぶだけでも仕上がるよう、文字は旅行の情報から入れておく（あとから押して直せる）
enum MemoryBuilder {

    static func newProject(plan: TravelPlan, kind: MemoryKind, englishName: String?,
                           candidates: [TripPhotoCandidate]) -> MemoryProject {
        let name = displayName(plan: plan, englishName: englishName)
        let template = MemoryTemplate.templates(for: kind).first { !$0.isPro } ?? MemoryTemplate.templates(for: kind)[0]
        var project = MemoryProject(planId: plan.id ?? UUID().uuidString, kind: kind, templateId: template.id, aspect: .story)
        project.subtitle = dateRangeText(start: plan.startDate, end: plan.endDate)
        project.badge = dayCountText(plan.dayCount)
        switch kind {
        case .photoDump:
            project.title = "\(name) Trip"
            project.note = "Good Memories ♡"
            project.detail = name
            project.photos = photos(from: TripPhotoLibrary.best(candidates, count: maxPhotos(for: kind)))
        case .poster:
            project.title = name
            project.note = "A Journey to Remember"
            project.detail = coordinateText(latitude: plan.latitude, longitude: plan.longitude) ?? plan.destination
            if let best = candidates.filter({ !$0.isVideo }).max(by: { $0.score < $1.score }) {
                project.photos = photos(from: [best])
            }
        case .diary:
            project.title = "\(name) Trip"
            project.pages = diaryPages(plan: plan, candidates: candidates)
        }
        return project
    }

    /// その種類のテンプレートで、いちばん多く使う写真の数
    static func maxPhotos(for kind: MemoryKind) -> Int {
        MemoryTemplate.templates(for: kind).map(\.photoCount).max() ?? 1
    }

    /// 題に使う名前。英語の名前が引ければそれ（「Okinawa」）、無ければ目的地か旅行の名前
    static func displayName(plan: TravelPlan, englishName: String?) -> String {
        if let englishName, !englishName.isEmpty { return englishName }
        let destination = plan.destination.trimmingCharacters(in: .whitespaces)
        return destination.isEmpty ? plan.title : destination
    }

    /// 「2026.11.15 – 11.17」。年をまたぐときは両方に年
    static func dateRangeText(start: Date, end: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy.MM.dd"
        let first = formatter.string(from: start)
        if calendar.isDate(start, inSameDayAs: end) { return first }
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)
        formatter.dateFormat = sameYear ? "MM.dd" : "yyyy.MM.dd"
        return "\(first) – \(formatter.string(from: end))"
    }

    static func dayCountText(_ days: Int) -> String {
        days <= 1 ? "1 DAY" : "\(days) DAYS"
    }

    /// 「26.2124° N  ·  127.6792° E」
    static func coordinateText(latitude: Double?, longitude: Double?) -> String? {
        guard let latitude, let longitude else { return nil }
        let ns = latitude >= 0 ? "N" : "S"
        let ew = longitude >= 0 ? "E" : "W"
        return String(format: "%.4f° %@  ·  %.4f° %@", abs(latitude), ns, abs(longitude), ew)
    }

    static func photos(from candidates: [TripPhotoCandidate]) -> [MemoryPhoto] {
        candidates.map { MemoryPhoto(assetId: $0.id, isVideo: $0.isVideo, date: $0.date) }
    }

    /// 写真を選び直す（おまかせ）。今の写真を外して、残りから選ぶ。残りが足りなければ全体から混ぜ直す
    static func reshuffled(_ project: MemoryProject, candidates: [TripPhotoCandidate]) -> [MemoryPhoto] {
        let count = project.kind == .poster ? 1 : maxPhotos(for: project.kind)
        let current = Set(project.photos.map(\.assetId))
        var picked = TripPhotoLibrary.best(candidates.shuffled().sorted { $0.date < $1.date },
                                           count: count, excluding: current)
        if picked.count < count {
            let rest = candidates.filter { !$0.isVideo && !picked.contains($0) }.shuffled()
            picked += rest.prefix(count - picked.count)
        }
        if project.kind == .poster, let best = picked.max(by: { $0.score < $1.score }) { picked = [best] }
        return photos(from: picked.sorted { $0.date < $1.date })
    }

    // MARK: - 日記

    /// 日ごとのページ。その日の写真から時間が散らばるように4枚まで選び、近い時刻の予定の名前を一言に入れる。
    /// 写真の無い日は、予定だけで項目を作る
    static func diaryPages(plan: TravelPlan, candidates: [TripPhotoCandidate],
                           calendar: Calendar = .current) -> [DiaryPage] {
        let pages: [DiaryPage] = (1...max(plan.dayCount, 1)).map { day in
            let date = plan.date(forDay: day)
            let items = (plan.daySchedules.first { $0.dayNumber == day }?.scheduleItems ?? [])
                .filter { !$0.hasUndecidedTime }
                .sorted { $0.time < $1.time }
            let dayPhotos = candidates.filter { calendar.isDate($0.date, inSameDayAs: date) }
            var entries: [DiaryEntry] = []
            if dayPhotos.isEmpty {
                entries = items.prefix(DiaryFormat.maxEntries).map { DiaryEntry(time: $0.time, text: $0.title) }
            } else {
                let picked = spreadBest(dayPhotos, count: DiaryFormat.maxEntries)
                entries = picked.map { candidate in
                    let nearest = items.min { abs($0.time.timeIntervalSince(candidate.date)) < abs($1.time.timeIntervalSince(candidate.date)) }
                    let text = nearest.flatMap { abs($0.time.timeIntervalSince(candidate.date)) <= 90 * 60 ? $0.title : nil } ?? ""
                    return DiaryEntry(time: candidate.date, text: text,
                                      photo: MemoryPhoto(assetId: candidate.id, isVideo: candidate.isVideo, date: candidate.date))
                }
            }
            return DiaryPage(dayNumber: day, date: date, entries: entries)
        }
        // 旅行計画なしで作るもの（予定が無い）は、写真の無い日のページを作らない（白紙のページが並ぶため）
        guard FreeMemoryStore.isFree(planId: plan.id) else { return pages }
        let filled = pages.filter { !$0.entries.isEmpty }
        return filled.isEmpty ? Array(pages.prefix(1)) : filled
    }

    /// 動画も含めて、時間が散らばるように選ぶ
    private static func spreadBest(_ candidates: [TripPhotoCandidate], count: Int) -> [TripPhotoCandidate] {
        let sorted = candidates.sorted { $0.date < $1.date }
        guard sorted.count > count else { return sorted }
        let step = Double(sorted.count) / Double(count)
        return (0..<count).compactMap { index in
            let lower = Int(Double(index) * step)
            let upper = min(Int(Double(index + 1) * step), sorted.count)
            guard lower < upper else { return nil }
            return sorted[lower..<upper].max { $0.score < $1.score }
        }
    }
}

/// 書き出す（3.8）。組み立ての大きさの2倍の解像度で画像にする（ストーリーなら 2160 × 3840）
enum MemoryRenderer {
    @MainActor
    static func render(templateId: String, project: MemoryProject, images: [String: UIImage],
                       showsWatermark: Bool, pageIndex: Int = 0) -> UIImage? {
        let context = MemoryCanvasContext(project: project, images: images, showsWatermark: showsWatermark)
        let renderer = ImageRenderer(content: MemoryCanvas(templateId: templateId, context: context, pageIndex: pageIndex))
        renderer.scale = 2
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
