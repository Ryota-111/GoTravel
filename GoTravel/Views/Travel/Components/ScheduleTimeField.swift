import SwiftUI

/// 予定の時刻の入力欄。
///
/// 海外の旅行では「現地時間」「日本時間」を切り替えられる。
/// 切り替えても**時:分はそのまま**で、どこの時計で読むかだけが変わる
/// （「15:00 と入れたのは現地の15:00のつもりだった」を後から直せるように）。
/// もう一方の時計で何時になるかも添えるので、日本にいながら現地の予定を組める
struct ScheduleTimeField: View {
    @Binding var time: Date
    @Binding var timeZone: TimeZone
    /// 目的地の時間帯。日本と時差が無い・分からないときは nil（切り替えを出さない）
    let destination: TimeZone?
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

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

            if let destination {
                LocalTimeZoneChooser(
                    time: $time,
                    timeZone: $timeZone,
                    destination: destination,
                    secondaryText: secondaryText
                )
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
