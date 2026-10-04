import Foundation
@preconcurrency import Vision
import CoreGraphics

/// 予約の確認画面のスクリーンショットや e チケットの画像から、文字を読み取る。
///
/// **端末の中だけで読む**（Vision の文字認識）。画像はどこにも送らない。
/// 読んだ文字は `ReservationEmailParser` にそのまま渡すので、メールと同じ形に並べ直す
enum ReservationImageTextReader {

    enum ReadError: Error {
        case noText
    }

    /// 画像の文字を、上の行から順に返す
    /// - Parameter orientation: 写真の向き。カメラで撮った写真は横向きのまま保存されていることがある
    static func text(from image: CGImage,
                     orientation: CGImagePropertyOrientation = .up) async throws -> String {
        let observations = try await recognize(image, orientation: orientation)
        let text = layout(observations.compactMap { observation in
            observation.topCandidates(1).first.map {
                TextBox(text: $0.string, frame: observation.boundingBox)
            }
        })
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReadError.noText }
        return text
    }

    private static func recognize(_ image: CGImage,
                                  orientation: CGImagePropertyOrientation) async throws -> [VNRecognizedTextObservation] {
        // 時間のかかる処理なので、画面の処理を止めないよう別のスレッドで読む。
        // 完了の知らせ（completionHandler）は使わない。失敗したときに知らせと例外の
        // 両方が来ることがあり、二重に再開して落ちるのを避けるため
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            // 言葉として自然になるよう直す処理は、予約番号（K7Q2PX など）まで
            // それらしい単語に変えてしまうことがあるので使わない
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            try handler.perform([request])
            return request.results ?? []
        }.value
    }

    // MARK: - 行に並べ直す

    struct TextBox: Equatable {
        let text: String
        /// Vision の座標（0〜1、左下が原点）
        let frame: CGRect
    }

    /// 文字の塊を、画面の見た目どおりの行に並べ直す。
    ///
    /// 確認画面は「予約番号　　K7Q2PX」のように、ラベルと値が左右に離れて
    /// 並ぶことが多い。Vision はこれを別々の塊として返すので、そのままだと
    /// ラベルと値が別の行になり、どの値がどのラベルのものか分からなくなる。
    /// 高さが重なる塊を同じ行にまとめ、左から順にタブでつなぐ
    static func layout(_ boxes: [TextBox]) -> String {
        // 上から順に（Vision は下が原点なので、maxY の大きいほうが上）
        let sorted = boxes.sorted { $0.frame.midY > $1.frame.midY }
        var rows: [[TextBox]] = []

        for box in sorted {
            if let last = rows.last, let anchor = last.first, sameRow(anchor.frame, box.frame) {
                rows[rows.count - 1].append(box)
            } else {
                rows.append([box])
            }
        }

        return rows
            .map { row in row.sorted { $0.frame.minX < $1.frame.minX }.map(\.text).joined(separator: "\t") }
            .joined(separator: "\n")
    }

    /// 2つの塊が同じ行か。低いほうの高さの半分以上が重なっていれば同じ行とみなす
    private static func sameRow(_ a: CGRect, _ b: CGRect) -> Bool {
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        return overlap > min(a.height, b.height) * 0.5
    }
}
