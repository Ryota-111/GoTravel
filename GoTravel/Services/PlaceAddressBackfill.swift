import Foundation

/// 住所の無い保存済みの場所に、位置から調べた住所を入れる（3.5）。
///
/// 3.4 までは「＋」→「地図で探す」で保存すると住所を残していなかった。位置（緯度・経度）はあるので、
/// 場所保存の画面を開いたときに、住所の無い場所だけ調べて記録する（iCloud で他の端末にも届く）。
/// 住所の調べものは Apple に回数の上限があるので、1件ずつ間をあけ、1回に調べる数も絞る。
/// 調べても分からなかった場所（海の上など）は、アプリを開き直すまで調べ直さない
@MainActor
enum PlaceAddressBackfill {
    private static var tried: Set<String> = []
    private static var isRunning = false
    /// 1回に調べる数
    static let batchSize = 40

    /// 住所を入れたほうがいい場所（住所が無く、位置がある）
    nonisolated static func needsAddress(_ place: VisitedPlace) -> Bool {
        (place.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(place.latitude == 0 && place.longitude == 0)
            && place.id != nil
    }

    static func fill(_ places: [VisitedPlace], userId: String, using placesVM: PlacesViewModel) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let targets = places.filter { needsAddress($0) && !tried.contains($0.id ?? "") }.prefix(batchSize)
        for place in targets {
            guard !Task.isCancelled, let id = place.id else { return }
            let address = await AddressLookup.address(latitude: place.latitude, longitude: place.longitude)
            tried.insert(id)
            guard let address else { continue }
            // 調べている間に直された場所は、その新しい中身に住所だけ足す
            guard var latest = placesVM.places.first(where: { $0.id == id }), needsAddress(latest) else { continue }
            latest.address = address
            placesVM.update(latest, userId: userId)
            try? await Task.sleep(for: .milliseconds(400))
        }
    }
}
