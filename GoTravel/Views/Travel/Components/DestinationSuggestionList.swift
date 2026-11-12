import SwiftUI
import MapKit

// MARK: - 行き先の候補と、見つかった場所（3.4）
//
// 旅行を作る画面（`AddTravelPlanView`）と、旅行の基本情報を直す画面（`EditTravelPlanBasicInfoView`）で使う。
// 「場所が見つかりました」だけでは、どこが見つかったのか分からなかった（「ロンドン」が愛媛県のお店になっていた）。
// 候補を国・地域つきで並べて選べるようにし、選ばなかったときも見つかった場所の名前を出す

/// 打った文字の候補。押すとその場所を行き先にする
struct DestinationSuggestionList: View {
    let results: [MKLocalSearchCompletion]
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let background: Color
    let onPick: (MKLocalSearchCompletion) -> Void

    var body: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    Button {
                        onPick(result)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: result.subtitle.isEmpty ? "globe.asia.australia.fill" : "mappin.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(tint.opacity(0.8))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(textColor)
                                    .lineLimit(1)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(result.subtitle.isEmpty ? result.title : "\(result.title)、\(result.subtitle)")

                    if index < results.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(background))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(tint.opacity(0.2), lineWidth: 1))
        }
    }
}

/// 行き先として入った場所。候補から選んだか、自動で見つけたかで言い方を変える
struct DestinationFoundLabel: View {
    let label: String
    /// 候補から自分で選んだか
    let isPicked: Bool
    let tint: Color
    let secondaryText: Color

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isPicked ? "checkmark.circle.fill" : "mappin.and.ellipse")
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(isPicked ? label : "見つかった場所：\(label)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(tint)
                    .fixedSize(horizontal: false, vertical: true)
                if !isPicked {
                    Text("違うときは、候補から選んでください")
                        .font(.caption2)
                        .foregroundColor(secondaryText)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
