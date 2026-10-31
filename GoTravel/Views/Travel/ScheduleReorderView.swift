import SwiftUI

/// 行程と日程の並び替え（3.2、ご要望から）。
///
/// 行程は旅行計画の画面のスクロールの中にあるので、その場でつまんで動かすと
/// スクロールや左右のタブ切り替えと取り合いになる。持ち物と同じく、この画面にまとめて
/// 右のつまみで上下に動かす。
/// 「予定」はその日の予定の順（時刻の枠はそのままで中身が入れ替わる）、
/// 「日にち」は日ごとの予定をまるごと入れ替える
struct ScheduleReorderView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case items = "予定"
        case days = "日にち"
        var id: String { rawValue }
    }

    let plan: TravelPlan
    let dayNumber: Int
    let memberFilter: String?
    let onSave: (TravelPlan) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .items
    @State private var items: [ScheduleItem] = []
    @State private var days: [DaySchedule] = []
    @State private var didLoad = false

    private var accent: Color { themeManager.currentTheme.actionFill }

    /// 並べ替える前の順。時刻の枠として使う
    private var originalItems: [ScheduleItem] {
        plan.timelineScheduleItems(onDay: dayNumber, for: memberFilter)
    }

    private var originalDays: [DaySchedule] {
        plan.daySchedules.sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        NavigationStack {
            List {
                if originalDays.count > 1 {
                    Section {
                        Picker("並び替えるもの", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                switch mode {
                case .items: itemSection
                case .days: daySection
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("並び替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accent)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                items = originalItems
                days = originalDays
            }
        }
    }

    // MARK: - 予定

    private var itemSection: some View {
        Section {
            if items.count < 2 {
                Text("この日の予定が2件以上になると並び替えられます。")
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        // 時刻は枠なので位置に付く。動かした予定はその位置の時刻になる
                        Text(originalItems.indices.contains(index) ? originalItems[index].timeText : item.timeText)
                            .font(.system(size: 14, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .frame(width: 48, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            if let location = item.location, !location.isEmpty {
                                Text(location)
                                    .font(.caption)
                                    .foregroundColor(themeManager.currentTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onMove { source, destination in
                    items.move(fromOffsets: source, toOffset: destination)
                }
            }
        } header: {
            Text("\(dayNumber)日目")
        } footer: {
            Text("右のつまみを上下にドラッグして並べ替えます。時刻はそのままで、予定が入れ替わります。終わりの時刻は、予定の長さを保ったまま一緒に動きます。一番上に固定した予定は含みません。")
        }
    }

    // MARK: - 日にち

    private var daySection: some View {
        Section {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                HStack(spacing: 12) {
                    // 何日目かと日付は位置に付く。動かした日の予定はその日付に移る
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(index + 1)日目")
                            .font(.system(size: 13, weight: .bold))
                        if originalDays.indices.contains(index) {
                            Text(Self.dateText(originalDays[index].date))
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .frame(width: 56, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.summary(of: day))
                            .lineLimit(2)
                        if day.dayNumber != index + 1 {
                            Text("もとは\(day.dayNumber)日目")
                                .font(.caption)
                                .foregroundColor(accent)
                        }
                    }
                }
            }
            .onMove { source, destination in
                days.move(fromOffsets: source, toOffset: destination)
            }
        } footer: {
            Text("右のつまみを上下にドラッグして、日ごとの予定をまるごと入れ替えます。日付はそのままで、予定の時刻（時:分）も変わりません。")
        }
    }

    private static func summary(of day: DaySchedule) -> String {
        let titles = day.scheduleItems.sorted(by: ScheduleItem.chronologically).map(\.title)
        return titles.isEmpty ? "予定なし" : titles.joined(separator: "、")
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E)"
        return formatter.string(from: date)
    }

    // MARK: - 保存

    private func save() {
        var updated = plan
        var changed = false
        let newItemOrder = items.map(\.id)
        let oldItemOrder = originalItems.map(\.id)
        // 予定を先に動かす。日にちを動かすとき、動かした予定ごとその日へ移る
        if newItemOrder != oldItemOrder {
            updated = updated.reorderingItems(onDay: dayNumber, from: oldItemOrder, to: newItemOrder)
            changed = true
        }
        let newDayOrder = days.map(\.dayNumber)
        if newDayOrder != originalDays.map(\.dayNumber) {
            updated = updated.reorderingDays(newDayOrder)
            changed = true
        }
        if changed {
            onSave(updated)
        }
    }
}
