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

    /// 読む言語（先にあるほど優先）。
    /// 3.4 で韓国語と中国語（繁体字）を足した。韓国・台湾への旅行の予約画面（航空会社・現地の予約サイト）を読むため。
    /// 日本語の画面の読み取りが悪くならないことはテストで確かめている（`ReservationImageTextReaderTests`）
    static let recognitionLanguages = ["ja-JP", "en-US", "ko-KR", "zh-Hant"]

    /// 画像の文字を、上の行から順に返す
    /// - Parameter orientation: 写真の向き。カメラで撮った写真は横向きのまま保存されていることがある
    static func text(from image: CGImage,
                     orientation: CGImagePropertyOrientation = .up,
                     languages: [String] = recognitionLanguages) async throws -> String {
        let observations = try await recognize(image, orientation: orientation, languages: languages)
        let text = layout(observations.compactMap { observation in
            let candidates = observation.topCandidates(3).map(\.string)
            return candidates.isEmpty ? nil : TextBox(text: bestCandidate(candidates), frame: observation.boundingBox)
        })
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReadError.noText }
        return text
    }

    private static func recognize(_ image: CGImage,
                                  orientation: CGImagePropertyOrientation,
                                  languages: [String]) async throws -> [VNRecognizedTextObservation] {
        // 時間のかかる処理なので、画面の処理を止めないよう別のスレッドで読む。
        // 完了の知らせ（completionHandler）は使わない。失敗したときに知らせと例外の
        // 両方が来ることがあり、二重に再開して落ちるのを避けるため
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = languages
            // 画像ごとに言語を見分ける。並べた言語を一度に使うと、ハングルを先頭の日本語の読み方で読み、
            // 「출발」が「香些」のような漢字になっていた
            request.automaticallyDetectsLanguage = languages.count > 2
            // 言葉として自然になるよう直す処理は、予約番号（K7Q2PX など）まで
            // それらしい単語に変えてしまうことがあるので使わない
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            try handler.perform([request])
            return request.results ?? []
        }.value
    }

    // MARK: - 候補から選ぶ（3.8）

    /// 見た目の似た文字。写真の文字認識で取り違えやすい
    private static let lookAlikes: Set<[Character]> = [["O", "0"], ["0", "O"], ["o", "0"], ["0", "o"],
                                                       ["I", "1"], ["1", "I"], ["l", "1"], ["1", "l"],
                                                       ["S", "5"], ["5", "S"], ["B", "8"], ["8", "B"]]

    /// Vision の候補（よさそうな順）から使うものを選ぶ。ふつうは1番目。
    ///
    /// 2番目以降の候補が、1番目と見た目の似た文字（O/0・I/1・S/5・B/8）だけ違い、
    /// その違いで便名が読めるようになるときだけ、そちらを使う（「NH8O14」→「NH8014」）。
    /// 文全体を決まった規則で置き換えると、正しい予約番号（「EEF03D」の O など）を壊すので、しない
    static func bestCandidate(_ candidates: [String]) -> String {
        guard let first = candidates.first else { return "" }
        let firstFlights = ReservationEmailParser.flightNumbers(in: first).count
        for alternative in candidates.dropFirst() where alternative.count == first.count {
            let differences = zip(first, alternative).filter { $0 != $1 }
            guard !differences.isEmpty,
                  differences.allSatisfy({ lookAlikes.contains([$0.0, $0.1]) }) else { continue }
            if ReservationEmailParser.flightNumbers(in: alternative).count > firstFlights { return alternative }
        }
        return first
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
