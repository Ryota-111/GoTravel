import Foundation

/// 「前回そろえたときの内容」を覚えておく。
///
/// 共有の突き合わせ（`SharedPlanMerge`）は、手元・相手・前回の3つを見ないと
/// 「自分が足した」と「相手が消した」を区別できない。その前回ぶんを持つ。
///
/// **端末ごとの覚え書きなので、同期しない。**
/// どこまで受け取ったかは端末ごとに違うため、共有したら意味が壊れる。
/// Core Data に持たせると CloudKit にも載ってしまうので、ファイルに置く。
///
/// 消えても壊れない。無ければ「相手を正とする」に倒れるだけで、
/// それは3方向マージを入れる前と同じ振る舞いになる。
enum SharedPlanBaseStore {

    /// 写真と混ざらない場所に置く。
    /// `PhotoSyncService` は画像の拡張子だけを見るので、ここには手を出さない
    private static var directory: URL {
        let url = FileManager.documentsDirectory().appendingPathComponent("SharedPlanBase")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private static func fileURL(planId: String) -> URL {
        // planId は UUID なので、そのままファイル名にしてよい
        directory.appendingPathComponent("\(planId).json")
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// 前回そろえた内容。初回や、読めなかったときは nil
    static func load(planId: String) -> TravelPlan? {
        guard let data = try? Data(contentsOf: fileURL(planId: planId)) else { return nil }
        return try? decoder.decode(TravelPlan.self, from: data)
    }

    /// そろえ終えた内容を覚える。
    /// **相手から受け取った姿をそのまま入れること。** マージ後の姿を入れると、
    /// 次回に「自分が足したぶん」を相手のものと取り違える
    static func save(_ plan: TravelPlan) {
        guard let planId = plan.id,
              let data = try? encoder.encode(plan) else { return }
        try? data.write(to: fileURL(planId: planId), options: .atomic)
    }

    /// 共有をやめた・計画を消したときに片付ける
    static func remove(planId: String) {
        try? FileManager.default.removeItem(at: fileURL(planId: planId))
    }
}
