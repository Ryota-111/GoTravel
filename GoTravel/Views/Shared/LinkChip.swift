import SwiftUI

/// URLを開くための共通ボタン。
/// 旅行スケジュール・おでかけプラン・保存した場所で同じ見た目と挙動にするために切り出している
struct LinkChip: View {
    let rawURL: String
    var tint: Color = .blue
    /// 省略時はドメイン名を出す
    var label: String? = nil

    var body: some View {
        if let url = LinkChip.normalized(rawURL) {
            Link(destination: url) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 10))
                    Text(label ?? url.host ?? "リンクを開く")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.borderless)
        }
    }

    /// スキームが省略されたURLに https:// を補う。
    /// 入力欄で「example.com」と打たれても開けるようにするため
    static func normalized(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "https://\(trimmed)")
    }
}
