import SwiftUI

/// 24時以降の予定（0:30 → 「24:30」）にするスイッチ（3.2）。
///
/// 21:00 発 → 23:00 着 → 24:30 チェックインのような夜の移動を入れると、0:30 がその日の
/// 一番上に並んでしまい、23:58・23:59 のように入れて合わせていたというご要望から。
/// 入れると `ScheduleItem.dayShift` が 1 になり、その日の最後に「24:30」と並ぶ。
/// 時刻の選び方は 0〜23 時までなので、0:30 を選んでこのスイッチを入れる。
/// 使いにくければ、24〜29 時を選べる入力欄に替える
///
/// 明け方の時刻（`isCandidate`）を選んだときと、もう翌日にしてある予定にだけ出す
struct NextDayToggle: View {
    @Binding var isOn: Bool
    /// 選んでいる時刻。「24:30 として出します」と添えるのに使う
    let time: Date
    let timeZone: TimeZone
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    /// 0:00〜5:59。日付をまたいだ夜の予定として入れることが多い時刻
    static func isCandidate(_ time: Date, in zone: TimeZone) -> Bool {
        ScheduleClock.calendar(in: zone).component(.hour, from: time) < 6
    }

    private var caption: String {
        let plain = ScheduleClock.timeText(time, in: timeZone)
        guard Self.isCandidate(time, in: timeZone) else {
            return "夜の移動のあとのチェックインなどを、この日の最後に並べます"
        }
        let late = ScheduleClock.lateNightText(time, in: timeZone)
        return "\(plain) を「\(late)」として、この日の最後に並べます"
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text("24時以降として入れる")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                Text(caption)
                    .font(.caption)
                    .foregroundColor(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(tint)
        .padding(12)
        .background(fieldBackground)
        .cornerRadius(12)
    }
}
