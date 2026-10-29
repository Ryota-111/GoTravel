import CoreGraphics
import Foundation

// MARK: - 旅のダイジェストの調整（3.2）
//
// - コマごと：トリミング（どこを・どれだけ大きく見せるか）と、動画を何秒目から使うか（`DigestClipEdit`）
// - 動画全体：色味（`DigestLook`）・画面の形（`DigestShape`）・1コマの秒数（`DigestPace`）

/// 1コマの調整。写真・動画の id ごとに、旅行ごとに端末に覚えておく
nonisolated struct DigestClipEdit: Codable, Equatable, Hashable {
    /// 画面の真ん中に来る位置（写真の左上が 0、右下が 1）
    var focusX: Double = 0.5
    var focusY: Double = 0.5
    /// 画面いっぱいに広げた大きさからの倍率（1〜`maxZoom`）
    var zoom: Double = 1
    /// 動画を何秒目から使うか。nil なら真ん中（撮りはじめと撮り終わりはぶれやすい）
    var videoStart: Double?

    static let maxZoom: Double = 3

    /// トリミングしていない
    var isUncropped: Bool { zoom <= 1.0001 && abs(focusX - 0.5) < 0.0001 && abs(focusY - 0.5) < 0.0001 }
    /// 何も変えていない（覚えておく必要がない）
    var isDefault: Bool { isUncropped && videoStart == nil }

    /// 写真（大きさ source）を画面（canvas）いっぱいに広げて、zoom 倍したときの大きさ
    static func filledSize(of source: CGSize, in canvas: CGSize, zoom: Double) -> CGSize {
        guard source.width > 0, source.height > 0 else { return canvas }
        let scale = max(canvas.width / source.width, canvas.height / source.height) * zoom
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    /// 写真の左上の位置（画面の左上から。上が 0 の向き）。画面に写真の外が見えないよう、端で止める
    static func origin(of source: CGSize, in canvas: CGSize, zoom: Double, focus: CGPoint) -> CGPoint {
        let size = filledSize(of: source, in: canvas, zoom: zoom)
        let x = canvas.width / 2 - focus.x * size.width
        let y = canvas.height / 2 - focus.y * size.height
        return CGPoint(x: min(0, max(canvas.width - size.width, x)), y: min(0, max(canvas.height - size.height, y)))
    }

    /// 画面に写真の外が見えない範囲に、真ん中の位置と倍率を収めたもの
    func clamped(source: CGSize, canvas: CGSize) -> DigestClipEdit {
        var edit = self
        edit.zoom = min(max(zoom, 1), Self.maxZoom)
        let size = Self.filledSize(of: source, in: canvas, zoom: edit.zoom)
        guard size.width > 0, size.height > 0 else { return edit }
        let halfX = canvas.width / 2 / size.width, halfY = canvas.height / 2 / size.height
        edit.focusX = min(max(focusX, halfX), 1 - halfX)
        edit.focusY = min(max(focusY, halfY), 1 - halfY)
        return edit
    }

    /// 動画（長さ duration 秒）のうち使う範囲。length 秒より短い動画は全部
    func videoRange(duration: Double, length: Double) -> (start: Double, length: Double) {
        let used = min(length, max(duration, 0))
        let latest = max(0, duration - used)
        let start = videoStart.map { min(max($0, 0), latest) } ?? latest / 2
        return (start, used)
    }
}

/// 色味。全部のコマを同じ色味にそろえる（題名のカードの背景も）
nonisolated enum DigestLook: String, CaseIterable, Identifiable {
    case natural, film, warm, crisp, mono

    static let storageKey = "tripDigestLook"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .natural: return "そのまま"
        case .film: return "フィルム"
        case .warm: return "あたたかい"
        case .crisp: return "すっきり"
        case .mono: return "白黒"
        }
    }

    static var current: DigestLook {
        UserDefaults.standard.string(forKey: storageKey).flatMap(DigestLook.init(rawValue:)) ?? .natural
    }
}

/// 画面の形
enum DigestShape: String, CaseIterable, Identifiable {
    /// 縦長（リール・ストーリーズ・TikTok）
    case vertical
    /// 正方形（投稿）
    case square
    /// 横長（テレビ・パソコン）
    case landscape

    static let storageKey = "tripDigestShape"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .vertical: return "縦長"
        case .square: return "正方形"
        case .landscape: return "横長"
        }
    }

    var size: CGSize {
        switch self {
        case .vertical: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        case .landscape: return CGSize(width: 1920, height: 1080)
        }
    }

    static var current: DigestShape {
        UserDefaults.standard.string(forKey: storageKey).flatMap(DigestShape.init(rawValue:)) ?? .vertical
    }
}

/// 1コマの秒数
enum DigestPace {
    static let storageKey = "tripDigestClipSeconds"
    static let choices: [Double] = [1.5, 2, 3, 4]
    static let standard: Double = 2

    static var current: Double {
        let value = UserDefaults.standard.double(forKey: storageKey)
        return choices.contains(value) ? value : standard
    }

    /// 「1.5秒」「2秒」
    static func text(_ seconds: Double) -> String {
        seconds == seconds.rounded() ? "\(Int(seconds))秒" : String(format: "%.1f秒", seconds)
    }
}
