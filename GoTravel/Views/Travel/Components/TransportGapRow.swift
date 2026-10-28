import SwiftUI

// MARK: - 予定と予定の間の移動手段（3.2）
//
// 時刻と時刻をつなぐ棒そのものを「移動」として見せる。
// - 手段を決めた区間は、前の予定の点から次の予定の点まで線を変える
//   （徒歩は点線、電車・バス・車・タクシーは太い線、飛行機・船は破線。`TransportRailSegment`）
// - アイコンは区間のちょうど真ん中の棒の上に置き、手段の名前と時間は左の時刻の列に添える
//   （右に置くと、前の予定のタイトルや金額と重なる。`transportBadge`）
// - 手段を決めていない区間は、間の行に小さな＋だけ（`TransportGapRow`）
//
// 旅行の日程とおでかけの予定の両方で使う。時刻の列は幅46、棒はその右10の位置で幅12（両方の行と同じ寸法）

private enum TransportRailMetrics {
    static let timeColumnWidth: CGFloat = 46
    static let railLeading: CGFloat = 10
    static let railWidth: CGFloat = 12
    /// 行の上から予定の点の下端まで（上の余白3 + 点12）
    static let dotBottom: CGFloat = 15
    /// 次の行の上から点の上端まで
    static let nextDotTop: CGFloat = 3
}

/// 手段を選ぶメニューの中身
@ViewBuilder
private func transportMenuItems(selected: TransportMode?, onSelect: @escaping (TransportMode?) -> Void) -> some View {
    ForEach(TransportMode.allCases) { candidate in
        Button {
            onSelect(candidate)
        } label: {
            if candidate == selected {
                Label(candidate.title, systemImage: "checkmark")
            } else {
                Label(candidate.title, systemImage: candidate.systemImage)
            }
        }
    }
    if selected != nil {
        Divider()
        Button(role: .destructive) {
            onSelect(nil)
        } label: {
            Label("外す", systemImage: "xmark")
        }
    }
}

/// 予定と予定の間の行。決めていなければ＋、決めていれば線だけ（アイコンは `transportBadge` が真ん中に置く）。
/// 行のどこを押しても手段を選べる
struct TransportGapRow: View {
    let mode: TransportMode?
    let tint: Color
    /// 手段を決めていない区間の棒の色。両側の行の棒と同じ色
    let railColor: Color
    /// 手段を決めていない区間の「＋」の色
    let placeholderColor: Color
    /// 過ぎた区間は色を落とす
    var isPast = false
    let onSelect: (TransportMode?) -> Void

    var body: some View {
        Menu {
            transportMenuItems(selected: mode, onSelect: onSelect)
        } label: {
            HStack(spacing: 0) {
                Color.clear.frame(width: TransportRailMetrics.timeColumnWidth)

                Group {
                    if mode == nil {
                        // 決めていない間は目立たせない。予定の間に毎回出るので、強いと行程が読みにくくなる
                        VStack(spacing: 0) {
                            TransportRailSegment(mode: nil, tint: tint, railColor: railColor)
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(placeholderColor)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(placeholderColor, lineWidth: 1))
                            TransportRailSegment(mode: nil, tint: tint, railColor: railColor)
                        }
                    } else {
                        TransportRailSegment(mode: mode, tint: tint, railColor: railColor, isPast: isPast)
                    }
                }
                .frame(width: TransportRailMetrics.railWidth)
                .padding(.leading, TransportRailMetrics.railLeading)

                Spacer(minLength: 0)
            }
            .frame(height: mode == nil ? 28 : 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("次の予定までの移動手段を選ぶ"))
    }

    /// 「25分」「1時間10分」。0分以下や1日以上は出さない（入れ間違いの見込みが高い）
    static func durationText(_ interval: TimeInterval) -> String? {
        let minutes = Int((interval / 60).rounded())
        guard minutes > 0, minutes < 24 * 60 else { return nil }
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest)分" }
        return rest == 0 ? "\(hours)時間" : "\(hours)時間\(rest)分"
    }
}

extension View {
    /// 前の予定の行と間の行をまとめたものに付け、移動手段のアイコンを区間の真ん中の棒の上に重ねる。
    ///
    /// - Parameters:
    ///   - leading: 時刻の列の左端（行の左の余白）
    ///   - duration: 前の予定の終わりから次の予定の始まりまで。終わりの時刻が無いときは nil（滞在の時間が混ざるため）
    func transportBadge(mode: TransportMode?, duration: TimeInterval?, tint: Color, isPast: Bool,
                        leading: CGFloat, onSelect: @escaping (TransportMode?) -> Void) -> some View {
        overlay(alignment: .topLeading) {
            if let mode {
                GeometryReader { geometry in
                    let top = TransportRailMetrics.dotBottom
                    let bottom = geometry.size.height + TransportRailMetrics.nextDotTop
                    // 時刻の列の上のほうには終わりの時刻などが出るので、短い区間でもそこには掛けない
                    let center = max((top + bottom) / 2, 48)
                    TransportBadge(mode: mode, duration: duration, tint: tint, isPast: isPast, onSelect: onSelect)
                        .offset(x: leading, y: center - TransportBadge.height / 2)
                }
            }
        }
    }
}

/// 区間の真ん中に置くアイコン。左の時刻の列に手段の名前と時間を添える
private struct TransportBadge: View {
    static let height: CGFloat = 26

    let mode: TransportMode
    let duration: TimeInterval?
    let tint: Color
    let isPast: Bool
    let onSelect: (TransportMode?) -> Void

    private var color: Color { tint.opacity(isPast ? 0.45 : 1) }
    private var durationText: String? { duration.flatMap(TransportGapRow.durationText) }

    var body: some View {
        Menu {
            transportMenuItems(selected: mode, onSelect: onSelect)
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(mode.title)
                        .font(.system(size: 10, weight: .bold))
                    if let durationText {
                        Text(durationText)
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: TransportRailMetrics.timeColumnWidth, alignment: .trailing)

                Image(systemName: mode.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: Self.height, height: Self.height)
                    .background(Circle().fill(color))
                    // 棒の幅（12）の真ん中に、はみ出して重ねる
                    .frame(width: TransportRailMetrics.railWidth)
                    .padding(.leading, TransportRailMetrics.railLeading)
            }
            .frame(height: Self.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("次の予定まで\(mode.title)\(durationText.map { "、\($0)" } ?? "")"))
    }
}

/// 時刻と時刻をつなぐ棒の線。移動手段を決めた区間は、前の予定の点から次の予定の点まで
/// この線で描く（予定の行の中も、間の行も）。手段を決めていなければ今までの細い線
struct TransportRailSegment: View {
    let mode: TransportMode?
    let tint: Color
    let railColor: Color
    var isPast = false

    private var lineColor: Color { tint.opacity(isPast ? 0.45 : 1) }

    var body: some View {
        switch mode {
        case nil:
            Rectangle()
                .fill(railColor)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        case .walk:
            VerticalLine()
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [0.1, 5]))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
        case .plane, .ship:
            VerticalLine()
                .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 4]))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
        case .train, .bus, .car, .taxi:
            Rectangle()
                .fill(lineColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
        }
    }
}

/// 縦の1本線。点線・破線を描くため
private struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
