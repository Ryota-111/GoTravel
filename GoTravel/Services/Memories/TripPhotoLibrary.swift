import Foundation
import Photos
import UIKit
import Vision
import CoreLocation

/// 旅行中に撮った写真の候補（3.8・旅の思い出をつくる）
struct TripPhotoCandidate: Identifiable, Equatable {
    /// カメラロールの id（localIdentifier）
    var id: String
    var date: Date
    var isVideo: Bool
    /// 写真の美しさ（Vision の採点。-1〜1。採点できなければ 0）
    var score: Float = 0
}

/// 旅行の写真を集めて選ぶ・読む。
///
/// - 旅行の期間（出発日の0時から、終わりの日の翌日0時まで）に撮った写真をカメラロールから集める。スクショは除く
/// - 多すぎるときは、時間が散らばるように絞ってから採点する（1枚ずつ採点すると、数百枚で時間がかかるため）
/// - iOS 18 の Vision で美しさを採点し、書類やレシートのような「実用の写真」を外す
/// - 選ぶときは、時間の流れに沿って区切り、それぞれの区切りでいちばんきれいな1枚を取る（同じ場面ばかりにしない）
enum TripPhotoLibrary {

    /// 採点する枚数の上限
    static let maxScored = 120

    /// 写真を読む許可。一部だけ許可している人も、選べる写真で作る
    static func authorize() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// 旅行中に撮った写真（と動画）。撮った順
    static func candidates(for plan: TravelPlan, includeVideos: Bool = false) async -> [TripPhotoCandidate] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.startDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: plan.endDate)) else { return [] }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var assets: [PHAsset] = []
        // 旅行中に作って保存した思い出の画像は、旅行の写真に混ぜない
        let exported = exportedAssetIds
        // 旅行計画なしで、写真を自分で選んで作るときは、選んだ写真だけ
        let picked = FreeMemoryStore.pickedAssetIds(planId: plan.id)
        PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
            if let picked, !picked.contains(asset.localIdentifier) { return }
            guard picked != nil || !exported.contains(asset.localIdentifier) else { return }
            switch asset.mediaType {
            case .image where !asset.mediaSubtypes.contains(.photoScreenshot):
                assets.append(asset)
            case .video where includeVideos && asset.duration >= 1:
                assets.append(asset)
            default:
                break
            }
        }

        let spreadAssets = spread(assets, limit: maxScored)
        var result: [TripPhotoCandidate] = []
        for asset in spreadAssets {
            guard let date = asset.creationDate else { continue }
            var candidate = TripPhotoCandidate(id: asset.localIdentifier, date: date, isVideo: asset.mediaType == .video)
            if asset.mediaType == .image, let thumb = await image(asset: asset, maxPixel: 360)?.cgImage {
                let (score, isUtility) = await aesthetics(of: thumb)
                if isUtility { continue }
                candidate.score = score
            }
            result.append(candidate)
        }
        return result
    }

    /// 時間が散らばるように、間引いて `limit` 枚にする
    static func spread<T>(_ items: [T], limit: Int) -> [T] {
        guard items.count > limit, limit > 0 else { return items }
        let step = Double(items.count) / Double(limit)
        return (0..<limit).map { items[min(Int(Double($0) * step), items.count - 1)] }
    }

    /// `count` 枚を選ぶ。撮った順に `count` 個に区切り、それぞれでいちばんきれいな1枚を取る（撮った順のまま返す）
    static func best(_ candidates: [TripPhotoCandidate], count: Int, excluding: Set<String> = []) -> [TripPhotoCandidate] {
        let pool = candidates.filter { !excluding.contains($0.id) && !$0.isVideo }
        guard pool.count > count, count > 0 else { return pool }
        let step = Double(pool.count) / Double(count)
        return (0..<count).compactMap { index in
            let lower = Int(Double(index) * step)
            let upper = min(Int(Double(index + 1) * step), pool.count)
            guard lower < upper else { return nil }
            return pool[lower..<upper].max { $0.score < $1.score }
        }
    }

    /// 美しさの点数と、実用の写真か
    private static func aesthetics(of image: CGImage) async -> (Float, Bool) {
        do {
            let observation = try await CalculateImageAestheticsScoresRequest().perform(on: image)
            return (observation.overallScore, observation.isUtility)
        } catch {
            // シミュレーターなど、採点できない環境では、選ぶ順番を撮った順に任せる
            return (0, false)
        }
    }

    // MARK: - 読む

    /// 写真を、長い辺が `maxPixel` になる大きさで読む（枠に足りる解像度だけ読み、メモリを使いすぎない）。
    /// iCloud にしかない写真は取り寄せる
    static func image(assetId: String, maxPixel: CGFloat) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject else { return nil }
        return await image(asset: asset, maxPixel: maxPixel)
    }

    static func image(asset: PHAsset, maxPixel: CGFloat) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let longest = CGFloat(max(asset.pixelWidth, asset.pixelHeight, 1))
        let ratio = min(1, maxPixel / longest)
        let target = CGSize(width: CGFloat(asset.pixelWidth) * ratio, height: CGFloat(asset.pixelHeight) * ratio)
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: target, contentMode: .aspectFit,
                                                  options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - 書き出す

    /// 写真アプリに保存する（追加だけの許可）。画像はファイルから入れる（メモリに全部を持たない）
    static func save(files: [URL]) async -> Bool {
        guard !files.isEmpty else { return false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        var created: [String] = []
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for url in files {
                    if let id = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)?
                        .placeholderForCreatedAsset?.localIdentifier {
                        created.append(id)
                    }
                }
            }
            rememberExported(created)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 保存した思い出

    private static let exportedKey = "MemoryExportedAssetIds"

    /// 思い出をつくるで保存した画像の id。旅行の写真の候補から外す（作ったコラージュが次のコラージュに入らないように）
    static var exportedAssetIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: exportedKey) ?? [])
    }

    private static func rememberExported(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        // 多くなりすぎないよう、新しいほうから 500 件まで
        let all = (UserDefaults.standard.stringArray(forKey: exportedKey) ?? []) + ids
        UserDefaults.standard.set(Array(all.suffix(500)), forKey: exportedKey)
    }

    // MARK: - 目的地の英語の名前

    /// 旅行の位置から、目的地の英語の名前（「Okinawa」「Kyoto」「Paris」）を引く。引けなければ nil
    static func englishPlaceName(for plan: TravelPlan) async -> String? {
        guard let latitude = plan.latitude, let longitude = plan.longitude else {
            return asciiName(plan.destination)
        }
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "en_US")).first else {
            return asciiName(plan.destination)
        }
        // 日本は都道府県（「Okinawa」「Kyoto」）、海外は市（「Paris」）。東京は都道府県名も Tokyo
        let raw = placemark.isoCountryCode == "JP"
            ? (placemark.administrativeArea ?? placemark.locality)
            : (placemark.locality ?? placemark.administrativeArea ?? placemark.country)
        return raw.map(cleaned) ?? asciiName(plan.destination)
    }

    /// 「Okinawa Prefecture」の「Prefecture」などを外す
    static func cleaned(_ name: String) -> String {
        var name = name
        for suffix in [" Prefecture", " Metropolis", "-ken", "-fu", "-to"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    /// 目的地がもともと英字で書いてあれば、それを使う
    private static func asciiName(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII }) else { return nil }
        return trimmed
    }
}
