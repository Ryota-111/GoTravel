import Foundation

/// 住所の無い保存済みの場所に、位置から調べた住所を入れる（3.5）。
///
/// 3.4 までは「＋」→「地図で探す」で保存すると住所を残していなかった。位置（緯度・経度）はあるので、
/// 場所保存の画面を開いたときに、住所の無い場所だけ調べて記録する（iCloud で他の端末にも届く）。
/// - 住所の調べものは Apple に回数の上限があるので、1件ごとに（うまくいかなくても）間をあけ、1回に調べる数も絞る
/// - 通信できない・上限に当たったときは、その回はそこでやめる。残りは「調べ済み」にせず、次に画面を開いたときに続ける
/// - 本当に住所が出ない場所（海の上など）だけ、アプリを開き直すまで調べ直さない
/// - 場所の数が変わって呼び直されたら、前の回はやめて新しい回が続きを調べる（前の回と同時には動かさない）
@MainActor
enum PlaceAddressBackfill {
    private static var tried: Set<String> = []
    /// 今動いている回の番号。新しい回が始まったら、前の回は次の区切りでやめる
    private static var currentRun = 0
    /// 1回に調べる数
    static let batchSize = 40

    /// 住所を入れたほうがいい場所（住所が無く、位置がある）
    nonisolated static func needsAddress(_ place: VisitedPlace) -> Bool {
        (place.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(place.latitude == 0 && place.longitude == 0)
            && place.id != nil
    }

    static func fill(_ places: [VisitedPlace], userId: String, using placesVM: PlacesViewModel) async {
        currentRun += 1
        let run = currentRun

        let targets = places.filter { needsAddress($0) && !tried.contains($0.id ?? "") }.prefix(batchSize)
        for place in targets {
            // 画面を離れた・新しい回が始まった：やめる（調べていない場所は、次の回が続ける）
            guard run == currentRun, !Task.isCancelled, let id = place.id else { return }
            let address: String?
            do {
                address = try await AddressLookup.lookup(latitude: place.latitude, longitude: place.longitude)
            } catch {
                // 通信できない・回数の上限：この場所は調べ済みにしない。今回はここでやめる
                return
            }
            tried.insert(id)
            // 調べている間に直された場所は、その新しい中身に住所だけ足す
            if let address, var latest = placesVM.places.first(where: { $0.id == id }), needsAddress(latest) {
                latest.address = address
                placesVM.update(latest, userId: userId)
            }
            // うまくいかなかったときも間をあける（すぐ次を頼むと上限に当たる）
            try? await Task.sleep(for: .milliseconds(400))
        }
    }
}
