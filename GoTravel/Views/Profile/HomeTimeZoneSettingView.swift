import SwiftUI

/// 住んでいる地域の時間帯を選ぶ（3.3）。
///
/// 旅行の日付（出発日・帰る日）は、この時間帯で入れたものとして読む（`ScheduleClock.homeTimeZone`）。
/// 日本に住む人は変えなくてよい。海外に住む人が日本時間のまま使うと、何日目かの数え方や
/// ウィジェットが1日ずれる
struct HomeTimeZoneSettingView: View {
    @AppStorage(ScheduleClock.homeTimeZoneKey) private var identifier: String = ""
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var query = ""

    private var accentColor: Color {
        themeManager.currentTheme.adaptiveText(for: colorScheme)
    }

    private var selected: TimeZone { ScheduleClock.homeTimeZone }

    /// 上に出す候補：日本と、この iPhone の時間帯（日本と違うときだけ）と、選んでいるもの
    private var suggestions: [TimeZone] {
        var zones = [ScheduleClock.legacyTimeZone]
        for zone in [TimeZone.current, selected] where !zones.contains(where: { $0.identifier == zone.identifier }) {
            zones.append(zone)
        }
        return zones
    }

    private var results: [TimeZone] {
        ScheduleClock.searchZones(query).filter { zone in
            !suggestions.contains { $0.identifier == zone.identifier }
        }
    }

    var body: some View {
        List {
            Section {
                Text("旅行の出発日や帰る日を、どこの日付で入れているかを決めます。日本にお住まいの方は「日本時間」のままで大丈夫です。海外にお住まいの方は、お住まいの地域を選ぶと、何日目かの数え方やウィジェットの日付がずれなくなります。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Section {
                ForEach(suggestions, id: \.identifier) { zone in
                    row(zone, note: zone.identifier == TimeZone.current.identifier
                        && zone.identifier != ScheduleClock.legacyTimeZone.identifier ? "この iPhone の時間帯" : nil)
                }
            }

            if !query.isEmpty || !results.isEmpty {
                Section("ほかの地域") {
                    ForEach(results, id: \.identifier) { zone in
                        row(zone, note: nil)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "都市の名前で探す")
        .navigationTitle("住んでいる地域の時間帯")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ zone: TimeZone, note: String?) -> some View {
        Button {
            // 日本時間は「選んでいない」として残す（標準のまま）
            // ウィジェットの日付は、アプリを閉じたときに書き直される
            identifier = zone.identifier == ScheduleClock.legacyTimeZone.identifier ? "" : zone.identifier
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScheduleClock.choiceTitle(of: zone))
                        .foregroundColor(accentColor)
                    if let note {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                Spacer()

                if zone.identifier == selected.identifier {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.actionFill)
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
