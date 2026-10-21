import CoreGraphics

/// 日本全国フォトマップの県の位置と大きさの微調整（3.1）。
///
/// 手でそろえた位置・大きさ（`Prefecture.baseMapPosition` / `baseMapSize`）はそのまま残し、
/// 隣の県との重なりとすき間が小さくなるよう、ここで少しだけずらし・大きさを変える。
/// 県の形の画像を重ねて測り、白いすき間が出ないことを優先して決めた（2026-10-21）。
///
/// **元に戻すときは `table` を空にする**（手でそろえた位置・大きさに戻る）
struct PrefectureMapAdjustment {
    /// 右・下へずらす量（ポイント。370 × 600 の地図の中で）
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    /// 大きさの倍率（真ん中を変えずに大きく・小さくする）
    var scale: CGFloat = 1

    static let table: [Prefecture: PrefectureMapAdjustment] = [
        .aichi: .init(dx: 0.0, dy: 0.0, scale: 0.94),
        .chiba: .init(dx: -0.5, dy: 0.5, scale: 0.96),
        .fukuoka: .init(dx: 0.0, dy: -0.5, scale: 0.94),
        .fukushima: .init(dx: 0.0, dy: 1.0, scale: 1.0),
        .gunma: .init(dx: -0.5, dy: -1.0, scale: 0.94),
        .ishikawa: .init(dx: -0.5, dy: 0.0, scale: 1.0),
        .kagawa: .init(dx: 0.0, dy: 0.0, scale: 1.02),
        .kochi: .init(dx: 0.0, dy: 0.5, scale: 1.0),
        .kyoto: .init(dx: 0.0, dy: 0.0, scale: 1.02),
        .mie: .init(dx: 0.0, dy: 0.0, scale: 0.98),
        .miyagi: .init(dx: 0.0, dy: 0.0, scale: 0.96),
        .miyazaki: .init(dx: 0.0, dy: 0.0, scale: 0.96),
        .nagano: .init(dx: 0.0, dy: -0.5, scale: 1.0),
        .nara: .init(dx: 0.5, dy: 0.5, scale: 1.0),
        .niigata: .init(dx: 0.0, dy: -0.5, scale: 0.98),
        .okayama: .init(dx: 0.0, dy: 0.0, scale: 0.98),
        .osaka: .init(dx: 0.5, dy: -0.5, scale: 1.0),
        .saga: .init(dx: 0.0, dy: -0.5, scale: 0.98),
        .shiga: .init(dx: 0.0, dy: 0.5, scale: 0.98),
        .shimane: .init(dx: 0.0, dy: -0.5, scale: 1.0),
        .tochigi: .init(dx: 0.0, dy: 0.0, scale: 0.98),
        .tokyo: .init(dx: 0.0, dy: 0.0, scale: 0.94),
        .tottori: .init(dx: 0.0, dy: 0.0, scale: 0.98),
        .toyama: .init(dx: 0.0, dy: -1.0, scale: 1.0),
        .yamagata: .init(dx: 0.0, dy: 0.0, scale: 0.98),
    ]
}

extension Prefecture {
    /// 地図のキャンバス（370 × 600）
    static let mapCanvas = CGSize(width: 370, height: 600)

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
