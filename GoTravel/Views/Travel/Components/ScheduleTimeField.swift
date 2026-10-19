import SwiftUI
import CoreLocation

/// 予定の時刻の入力欄。
///
/// 海外の旅行では、時刻をどこの時計で入れるかを選べる（3.0 から、予定の場所・その日・目的地・
/// 日本・最近使った時間帯、ほかは検索して選ぶ）。切り替えても**時:分はそのまま**で、
/// どこの時計で読むかだけが変わる。もう一方の時計で何時になるかも添える。
///
/// 場所を選び直したら、その場所の時間帯に合わせる（自分で時間帯を選んだあとは変えない）
struct ScheduleTimeField: View {
    @Binding var time: Date
    @Binding var timeZone: TimeZone
    /// 予定の場所。時間帯を引いて候補に入れる
    var place: CLLocationCoordinate2D?
    /// その日の時間帯
    var dayZone: TimeZone?
    /// 旅行の目的地の時間帯
    let destination: TimeZone?
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    @State private var placeZone: TimeZone?
    /// 開いたときの場所。編集で開いただけで時間帯が変わらないよう、これと違うときだけ合わせる
    @State private var initialPlaceKey: String?
    @State private var didCaptureInitialPlace = false
    /// 自分で時間帯を選んだか。選んだあとは場所に合わせない
    @State private var pickedByHand = false
    @State private var note: String?
    @State private var showsSearch = false

    private var choices: [ScheduleZoneChoice] {
        ScheduleClock.zoneChoices(place: placeZone, day: dayZone, destination: destination,
                                  current: .current, recents: RecentTimeZones.list(), at: time)
    }

    private var placeKey: String? {
        place.map { String(format: "%.2f,%.2f", $0.latitude, $0.longitude) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(tint.opacity(0.8))
                    .frame(width: 24)
                Text("時刻")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Spacer()
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    // 選んだ時計で時:分を出し入れする。これが無いと端末の時計になる
                    .environment(\.timeZone, timeZone)
                    .colorMultiply(tint)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(12)

            if ScheduleClock.offersZoneChoice(choices, selected: timeZone, at: time) {
                ScheduleZoneMenu(
                    time: time,
                    timeZone: timeZone,
                    choices: choices,
                    tint: tint,
                    textColor: textColor,
                    secondaryText: secondaryText,
                    fieldBackground: fieldBackground,
                    note: note,
                    onPick: { pick($0) },
                    onSearch: { showsSearch = true }
                )
            }
        }
        .task(id: placeKey) { await followPlace() }
        .sheet(isPresented: $showsSearch) {
            TimeZoneSearchView(tint: tint) { zone in
                pick(zone)
            }
        }
    }

    private func pick(_ zone: TimeZone) {
        pickedByHand = true
        note = nil
        change(to: zone)
    }

    private func change(to zone: TimeZone) {
        guard zone.identifier != timeZone.identifier else { return }
        time = ScheduleClock.keepingWallClock(time, from: timeZone, to: zone)
        timeZone = zone
    }

    /// 場所の時間帯を引き、場所を選び直したときはその時計にする
    private func followPlace() async {
        if !didCaptureInitialPlace {
            didCaptureInitialPlace = true
            initialPlaceKey = placeKey
        }
        guard let place else { placeZone = nil; return }
        guard let zone = await DestinationTimeZoneService.shared.timeZone(
            latitude: place.latitude, longitude: place.longitude) else { return }
        placeZone = zone
        guard placeKey != initialPlaceKey, !pickedByHand,
              !ScheduleClock.showsSameTime(zone, timeZone, at: time) else { return }
        // 国内旅行で日本の場所を選んだだけなら、何も言わずにそのまま
        guard ScheduleClock.isForeign(zone, at: time) || ScheduleClock.isForeign(timeZone, at: time) else { return }
        change(to: zone)
        note = "場所に合わせて、\(ScheduleClock.cityName(of: zone))の時刻で入れます（時刻の数字はそのまま）"
    }
}

/// 時刻の時間帯を選ぶメニューと、もう一方の時計での時刻
struct ScheduleZoneMenu: View {
    let time: Date
    let timeZone: TimeZone
    let choices: [ScheduleZoneChoice]
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color
    var note: String?
    let onPick: (TimeZone) -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Menu {
                ForEach(choices) { choice in
                    Button {
                        onPick(choice.zone)
                    } label: {
                        let title = ScheduleClock.choiceTitle(of: choice.zone)
                            + (choice.sourceLabel.map { "　\($0)" } ?? "")
                        if ScheduleClock.showsSameTime(choice.zone, timeZone, at: time) {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                    }
                }
                Divider()
                Button {
                    onSearch()
                } label: {
                    Label("ほかの時間帯を探す…", systemImage: "magnifyingglass")
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundColor(tint.opacity(0.8))
                        .frame(width: 24)
                    Text("時間帯")
                        .font(.subheadline)
                        .foregroundColor(textColor)
                    Spacer()
                    Text(ScheduleClock.isForeign(timeZone, at: time) ? ScheduleClock.cityName(of: timeZone) : "日本時間")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(tint)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(tint)
                }
                .padding(14)
                .background(fieldBackground)
                .cornerRadius(12)
            }

            Text(note ?? caption)
                .font(.caption)
                .foregroundColor(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var caption: String {
        let japan = ScheduleClock.legacyTimeZone
        if ScheduleClock.isForeign(timeZone, at: time) {
            let offset = ScheduleClock.offsetFromJapanText(timeZone, at: time).map { "・\($0)" } ?? ""
            return "\(ScheduleClock.displayName(of: timeZone))\(offset)。日本時間では \(ScheduleClock.timeText(time, in: japan)) です"
        }
        // 日本時間で入れているときは、勧めの海外の時計での時刻を添える
        if let foreign = choices.first(where: { ScheduleClock.isForeign($0.zone, at: time) })?.zone {
            return "日本時間で入力しています。\(ScheduleClock.cityName(of: foreign))では \(ScheduleClock.timeText(time, in: foreign)) です"
        }
        return "日本時間で入力しています"
    }
}

/// 時間帯を都市名で探して選ぶ
struct TimeZoneSearchView: View {
    let tint: Color
    let onPick: (TimeZone) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(ScheduleClock.searchZones(query), id: \.identifier) { zone in
                Button {
                    RecentTimeZones.record(zone)
                    onPick(zone)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ScheduleClock.cityName(of: zone))
                                .foregroundColor(.primary)
                            Text(ScheduleClock.displayName(of: zone))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(ScheduleClock.offsetFromJapanText(zone, at: Date()) ?? "日本と同じ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "都市名（パリ、London など）")
            .navigationTitle("時間帯を探す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(tint)
                }
            }
        }
    }
}

/// 「現地時間 / 日本時間」の切り替えと、もう一方の時計での時刻。
///
/// 切り替えても**時:分はそのまま**で、どこの時計で読むかだけが変わる
/// （「15:00 と入れたのは現地の15:00のつもりだった」を後から直せるように）。
/// 予定の時刻欄と、予約の日時欄で使う
struct LocalTimeZoneChooser: View {
    @Binding var time: Date
    @Binding var timeZone: TimeZone
    let destination: TimeZone
    let secondaryText: Color
    /// 日付も入れる欄では、もう一方の時計での日付も添える（日付が変わることがあるため）
    var showsDate = false

    private enum Choice: Hashable {
        case local, japan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: choice) {
                Text("現地時間").tag(Choice.local)
                Text("日本時間").tag(Choice.japan)
            }
            .pickerStyle(.segmented)

            Text(caption)
                .font(.caption)
                .foregroundColor(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isLocal: Bool {
        ScheduleClock.showsSameTime(timeZone, destination, at: time)
    }

    private var choice: Binding<Choice> {
        Binding(
            get: { isLocal ? .local : .japan },
            set: { newValue in
                let target = newValue == .local ? destination : ScheduleClock.legacyTimeZone
                time = ScheduleClock.keepingWallClock(time, from: timeZone, to: target)
                timeZone = target
            }
        )
    }

    private func otherClockText(in zone: TimeZone) -> String {
        ScheduleClock.text(time, format: showsDate ? "M月d日 HH:mm" : "HH:mm", in: zone)
    }

    private var caption: String {
        if isLocal {
            let name = ScheduleClock.displayName(of: destination)
            let offset = ScheduleClock.offsetFromJapanText(destination, at: time).map { "・\($0)" } ?? ""
            return "\(name)\(offset)。日本時間では \(otherClockText(in: ScheduleClock.legacyTimeZone)) です"
        }
        return "日本時間で入力しています。現地では \(otherClockText(in: destination)) です"
    }
}

/// 予定の終わる時刻（任意）。始まりの時刻の欄の下に置く。
///
/// 入れていないときは「終了時刻を追加」だけを出し、押すと始まりの1時間後から入れ始める
struct ScheduleEndTimeField: View {
    @Binding var hasEndTime: Bool
    @Binding var endTime: Date
    let startTime: Date
    let timeZone: TimeZone
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    var body: some View {
        if hasEndTime {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(tint.opacity(0.8))
                    .frame(width: 24)
                Text("終了時刻")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Spacer()
                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                    .environment(\.timeZone, timeZone)
                    .colorMultiply(tint)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Button {
                    hasEndTime = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("終了時刻を消す"))
            }
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(12)
        } else {
            Button {
                endTime = startTime.addingTimeInterval(60 * 60)
                hasEndTime = true
            } label: {
                Label("終了時刻を追加", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(tint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
    }
}
