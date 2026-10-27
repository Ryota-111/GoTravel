import SwiftUI

/// 日の時間帯を決め、入っている予定の時間帯もまとめて直す画面（3.0）。
///
/// 何ヶ国も回る旅行で「Day 4 からはパリ」と決めたり、日本時間で入っていた予定を
/// 現地の時刻に直したりする。直し方は2つあり、例の時刻を出して選んでもらう
/// （どちらのつもりで入れたかは、入れた本人にしか分からないため）
struct TimeZoneSettingsSheet: View {
    let plan: TravelPlan
    let day: Int
    let tripDuration: Int
    let destination: TimeZone?
    let tint: Color
    let onApply: (TravelPlan, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zone: TimeZone
    @State private var range: DayRange = .thisDay
    @State private var conversion: Conversion = .none
    @State private var showsSearch = false

    enum DayRange: Hashable {
        case thisDay, fromThisDay, allDays
    }

    enum Conversion: Hashable {
        case none, keepWallClock, keepMoment

        var mode: ScheduleZoneConversion? {
            switch self {
            case .none: return nil
            case .keepWallClock: return .keepWallClock
            case .keepMoment: return .keepMoment
            }
        }
    }

    init(plan: TravelPlan, day: Int, tripDuration: Int, destination: TimeZone?, tint: Color,
         onApply: @escaping (TravelPlan, String) -> Void) {
        self.plan = plan
        self.day = day
        self.tripDuration = tripDuration
        self.destination = destination
        self.tint = tint
        self.onApply = onApply
        // 勧め：その日の時間帯 → その日の予定で多い時間帯 → 目的地 → いまいる場所 → 日本
        let current: TimeZone? = ScheduleClock.isForeign(.current, at: Date()) ? .current : nil
        _zone = State(initialValue: plan.dayTimeZone(day)
                      ?? plan.foreignZonesUsed(onDay: day).first
                      ?? destination ?? current ?? ScheduleClock.legacyTimeZone)
    }

    private var days: Set<Int> {
        switch range {
        case .thisDay: return [day]
        case .fromThisDay: return Set(day...max(day, tripDuration))
        case .allDays: return Set(1...max(1, tripDuration))
        }
    }

    private var choices: [ScheduleZoneChoice] {
        let used = plan.foreignZonesUsed(onDay: day)
        var list = ScheduleClock.zoneChoices(place: nil, day: plan.dayTimeZone(day), destination: destination,
                                             current: .current, recents: used + RecentTimeZones.list(), at: Date())
        if !list.contains(where: { ScheduleClock.showsSameTime($0.zone, zone, at: Date()) }) {
            list.insert(ScheduleZoneChoice(zone: zone, source: .searched), at: 0)
        }
        return list
    }

    /// 直す予定の数
    private var affectedCount: Int {
        plan.scheduleItemCount(onDays: days, notIn: zone)
    }

    /// 例に使う予定（直すもののうち最初の1件）
    private var sampleItem: ScheduleItem? {
        plan.daySchedules
            .filter { days.contains($0.dayNumber) }
            .sorted { $0.dayNumber < $1.dayNumber }
            .flatMap { $0.scheduleItems.sorted(by: ScheduleItem.chronologically) }
            .first { !ScheduleClock.showsSameTime($0.timeZone, zone, at: $0.time) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(choices) { choice in
                        Button {
                            zone = choice.zone
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ScheduleClock.choiceTitle(of: choice.zone))
                                        .foregroundColor(.primary)
                                    if let source = choice.sourceLabel {
                                        Text(source).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if ScheduleClock.showsSameTime(choice.zone, zone, at: Date()) {
                                    Image(systemName: "checkmark").foregroundColor(tint)
                                }
                            }
                        }
                    }
                    Button {
                        showsSearch = true
                    } label: {
                        Label("ほかの時間帯を探す…", systemImage: "magnifyingglass")
                            .foregroundColor(tint)
                    }
                } header: {
                    Text("時間帯")
                } footer: {
                    if let offset = ScheduleClock.offsetFromJapanText(zone, at: Date()) {
                        Text("\(ScheduleClock.cityName(of: zone))は\(offset)です")
                    }
                }

                Section("決める日") {
                    Picker("決める日", selection: $range) {
                        Text("Day \(day) だけ").tag(DayRange.thisDay)
                        if day < tripDuration {
                            Text("Day \(day) 以降").tag(DayRange.fromThisDay)
                        }
                        Text("すべての日").tag(DayRange.allDays)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if affectedCount > 0 {
                    Section {
                        Picker("入っている予定", selection: $conversion) {
                            conversionRow(.none, title: "そのまま", detail: "これから入れる予定だけ、この時間帯で入れ始めます")
                            conversionRow(.keepWallClock, title: "時刻の数字はそのまま",
                                          detail: "現地の時刻のつもりで入れていたとき。\(example(.keepWallClock))")
                            conversionRow(.keepMoment, title: "同じ時刻に直す",
                                          detail: "日本時間で正しく入れていたとき。\(example(.keepMoment))")
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text("入っている予定（\(affectedCount)件）")
                    }
                }

                if days.contains(where: { plan.dayTimeZone($0) != nil }) {
                    Section {
                        Button("この日の時間帯を決めない", role: .destructive) {
                            onApply(plan.clearingDayTimeZone(onDays: days), "日の時間帯を外しました")
                            dismiss()
                        }
                    } footer: {
                        Text("入っている予定の時刻は変わりません。")
                    }
                }
            }
            .navigationTitle("時間帯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(tint)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決める") { apply() }
                        .fontWeight(.semibold)
                        .foregroundColor(tint)
                }
            }
            .sheet(isPresented: $showsSearch) {
                TimeZoneSearchView(tint: tint) { zone = $0 }
            }
        }
    }

    private func conversionRow(_ value: Conversion, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tag(value)
    }

    /// 「例：15:00（日本）→ 8:00（パリ）」
    private func example(_ mode: ScheduleZoneConversion) -> String {
        guard let item = sampleItem else { return "" }
        let converted = item.converted(to: zone, mode: mode)
        let before = "\(item.dayShiftLabel.map { "\($0) " } ?? "")\(item.timeText)（\(zoneName(item.timeZone, at: item.time))）"
        let after = "\(converted.dayShiftLabel.map { "\($0) " } ?? "")\(converted.timeText)（\(zoneName(zone, at: item.time))）"
        return "例：\(before) → \(after)"
    }

    private func zoneName(_ zone: TimeZone, at date: Date) -> String {
        ScheduleClock.isForeign(zone, at: date) ? ScheduleClock.cityName(of: zone) : "日本"
    }

    private func apply() {
        RecentTimeZones.record(zone)
        let updated = plan.settingTimeZone(zone, onDays: days, mode: conversion.mode)
        let city = ScheduleClock.isForeign(zone, at: Date()) ? ScheduleClock.cityName(of: zone) : "日本"
        onApply(updated, conversion == .none || affectedCount == 0
                ? "時間帯を\(city)にしました" : "予定を\(city)の時刻にしました")
        dismiss()
    }
}
