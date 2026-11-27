import CoreGraphics

/// 日本全国フォトマップの県の位置と大きさの微調整。
///
/// 3.1 では手でそろえた地図のすき間と重なりをここで直していたが、3.9 で実際の県境から
/// 地図を作り直したので、今は空。一部の県だけ大きくしたいときなどに使う
struct PrefectureMapAdjustment {
    /// 右・下へずらす量（ポイント。370 × 600 の地図の中で）
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    /// 大きさの倍率（真ん中を変えずに大きく・小さくする）
    var scale: CGFloat = 1

    /// 3.9 で実際の県境から作り直したので、ずらす県は無い
    static let table: [Prefecture: PrefectureMapAdjustment] = [:]
}

extension Prefecture {
    /// 地図のキャンバス（370 × 600）
    static let mapCanvas = CGSize(width: 370, height: 600)

    /// 沖縄を囲む角丸の枠（370 × 600 の中のポイント）。沖縄は九州の左下に大きくして置いているので、
    /// 別の場所だと分かるように枠で囲む
    static let okinawaInsetFrame = CGRect(x: 2.520, y: 284.310, width: 72.391, height: 54.100)

    /// 地図に描く位置（手でそろえた位置 ＋ 微調整）
    var mapPosition: CGPoint {
        let base = baseMapPosition
        guard let adjustment = PrefectureMapAdjustment.table[self] else { return base }
        return CGPoint(x: base.x + adjustment.dx / Self.mapCanvas.width,
                       y: base.y + adjustment.dy / Self.mapCanvas.height)
    }

    /// 地図に描く大きさ（手でそろえた大きさ × 微調整）
    var mapSize: CGSize {
        let base = baseMapSize
        guard let adjustment = PrefectureMapAdjustment.table[self] else { return base }
        return CGSize(width: base.width * adjustment.scale, height: base.height * adjustment.scale)
    }
}
