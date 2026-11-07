import SwiftUI
import MapKit

// MARK: - 「移動」と「時間未定」の入力（3.4）
//
// 予定を足す画面（`AddScheduleItemView`）と直す画面（`EditScheduleItemView`）で使う。
// 中身の決まりは `ScheduleMove.swift` と `ScheduleUndecidedTime.swift`、考え方は `docs/設計_移動と時間未定.md`

/// 予定を足す・直す画面で入れている中身（移動の欄）
struct MoveInput: Equatable {
    var mode: TransportMode = .train
    var from: MovePlace?
    var to: MovePlace?
    var fromText = ""
    var toText = ""
    var line = ""
    var platform = ""
    var seat = ""

    init() {}

    init(_ move: ScheduleMove) {
        mode = move.transportMode
        from = move.from
        to = move.to
        fromText = move.from?.name ?? ""
        toText = move.to?.name ?? ""
        line = move.line ?? ""
        platform = move.platform ?? ""
        seat = move.seat ?? ""
    }

    /// 保存する形。地図で選んだあとに名前を打ち直したら、位置は捨てて名前だけにする（違う場所の位置が残らないように）
    var move: ScheduleMove {
        ScheduleMove(mode: mode, line: line, platform: platform, seat: seat,
                     from: Self.place(from, typed: fromText), to: Self.place(to, typed: toText))
    }

    private static func place(_ picked: MovePlace?, typed: String) -> MovePlace? {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let picked, picked.name == name { return picked }
        return MovePlace(name: name)
    }

    mutating func swap() {
        (from, to) = (to, from)
        (fromText, toText) = (toText, fromText)
    }
}

/// 「予定」か「移動」か
struct ScheduleEntryKindPicker: View {
    @Binding var isMove: Bool
    let tint: Color

    var body: some View {
        Picker("種類", selection: $isMove) {
            Label("予定", systemImage: "mappin.circle").tag(false)
            Label("移動", systemImage: "arrow.triangle.swap").tag(true)
        }
        .pickerStyle(.segmented)
        .tint(tint)
        .accessibilityHint("移動を選ぶと、乗り物・出発地・到着地・便を入れられます")
    }
}

/// 移動の中身。乗り物・出発地 → 到着地・便や系統・のりば・座席
struct ScheduleMoveFields: View {
    @Binding var input: MoveInput
    let searchRegion: MKCoordinateRegion
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    private enum Target: Identifiable {
        case from, to
        var id: Self { self }
    }
    @State private var searching: Target?

    /// 移動に選べる乗り物。徒歩もあるが、いちばん後ろ
    private static let modes: [TransportMode] = [.train, .bus, .plane, .ship, .car, .taxi, .walk]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            modePicker
            routeFields
            detailField("便・系統", text: $input.line, placeholder: linePlaceholder, icon: "number")
            HStack(spacing: 10) {
                detailField("のりば・番線", text: $input.platform, placeholder: platformPlaceholder, icon: "signpost.right")
                detailField("座席", text: $input.seat, placeholder: "例：5A", icon: "chair")
            }
        }
        .fullScreenCover(item: $searching) { target in
            MapPlaceSearchView(title: target == .from ? "出発地を探す" : "到着地を探す",
                               startRegion: searchRegion, accent: tint) { picked in
                let place = MovePlace(name: picked.name, address: picked.address,
                                      latitude: picked.latitude, longitude: picked.longitude)
                switch target {
                case .from:
                    input.from = place
                    input.fromText = place.name
                case .to:
                    input.to = place
                    input.toText = place.name
                }
            }
        }
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.modes) { mode in
                    let selected = input.mode == mode
                    Button {
                        input.mode = mode
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                            .font(.subheadline.weight(selected ? .semibold : .regular))
                            .foregroundColor(selected ? .white : textColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(selected ? tint : fieldBackground))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    /// 出発地と到着地。右の矢印で入れ替える（帰りの移動を作るとき）
    private var routeFields: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 8) {
                placeField(text: $input.fromText, picked: input.from, placeholder: fromPlaceholder,
                           icon: "circle.circle", target: .from)
                placeField(text: $input.toText, picked: input.to, placeholder: toPlaceholder,
                           icon: "mappin.circle.fill", target: .to)
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { input.swap() }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(tint)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(fieldBackground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("出発地と到着地を入れ替える")
        }
    }

    private func placeField(text: Binding<String>, picked: MovePlace?, placeholder: String,
                            icon: String, target: Target) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(tint.opacity(0.8))
                .frame(width: 22)
            TextField(placeholder, text: text)
                .foregroundColor(textColor)
            // 地図で選んだ場所なら印を出す（名前を打ち直すと外れる）
            if let picked, picked.hasCoordinate, picked.name == text.wrappedValue {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(tint)
                    .accessibilityLabel("地図の場所")
            }
            Button {
                searching = target
            } label: {
                Image(systemName: "map")
                    .foregroundColor(tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(target == .from ? "出発地を地図で探す" : "到着地を地図で探す")
        }
        .padding(14)
        .background(fieldBackground)
        .cornerRadius(12)
    }

    private func detailField(_ label: String, text: Binding<String>, placeholder: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(secondaryText)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(tint.opacity(0.7))
                TextField(placeholder, text: text)
                    .foregroundColor(textColor)
            }
            .padding(12)
            .background(fieldBackground)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity)
    }

    private var fromPlaceholder: String {
        switch input.mode {
        case .plane: return "出発地（例：羽田空港）"
        case .bus: return "出発地（例：大阪梅田）"
        case .ship: return "出発地（例：神戸港）"
        default: return "出発地（例：京都駅）"
        }
    }

    private var toPlaceholder: String {
        switch input.mode {
        case .plane: return "到着地（例：那覇空港）"
        case .bus: return "到着地（例：清水寺）"
        case .ship: return "到着地（例：小豆島）"
        default: return "到着地（例：嵐山）"
        }
    }

    private var linePlaceholder: String {
        switch input.mode {
        case .plane: return "例：ANA123"
        case .bus: return "例：市バス 206系統"
        case .ship: return "例：高速船 3便"
        case .train: return "例：JR嵯峨野線・のぞみ21号"
        default: return "例：〇〇タクシー"
        }
    }

    private var platformPlaceholder: String {
        switch input.mode {
        case .bus: return "例：D2のりば"
        case .plane: return "例：搭乗口 12"
        default: return "例：14番線"
        }
    }
}

/// 時間未定のスイッチと、未定のときの「どこに入れるか」
struct UndecidedTimeFields: View {
    @Binding var isUndecided: Bool
    /// この予定のすぐ前に来る予定の id。nil ならいちばん前
    @Binding var anchorID: String?
    /// その日の予定（並んでいる順。自分自身は入れない）
    let dayItems: [ScheduleItem]
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $isUndecided.animation(.easeInOut(duration: 0.2))) {
                HStack(spacing: 10) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(tint.opacity(0.8))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("時間未定")
                            .font(.subheadline)
                            .foregroundColor(textColor)
                        Text("時間を決めずに入れ、あとで前後に動かせます")
                            .font(.caption)
                            .foregroundColor(secondaryText)
                    }
                }
            }
            .tint(tint)
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(12)

            if isUndecided {
                positionMenu
            }
        }
    }

    private var positionMenu: some View {
        Menu {
            Button { anchorID = nil } label: { choiceLabel("いちばん前", selected: anchorID == nil) }
            if !dayItems.isEmpty { Divider() }
            ForEach(dayItems) { item in
                Button { anchorID = item.id } label: {
                    choiceLabel("\(item.timeText)　\(item.title) のあと", selected: anchorID == item.id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.number")
                    .foregroundColor(tint.opacity(0.8))
                    .frame(width: 24)
                Text("入れる位置")
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Spacer()
                Text(positionText)
                    .font(.subheadline)
                    .foregroundColor(tint)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(secondaryText)
            }
            .padding(14)
            .background(fieldBackground)
            .cornerRadius(12)
        }
    }

    private var positionText: String {
        guard let anchorID, let anchor = dayItems.first(where: { $0.id == anchorID }) else { return "いちばん前" }
        return "\(anchor.title) のあと"
    }

    @ViewBuilder
    private func choiceLabel(_ text: String, selected: Bool) -> some View {
        if selected { Label(text, systemImage: "checkmark") } else { Text(text) }
    }
}

/// 移動の予約番号（3.4）。入れると予約の一覧にも入り、予約の画面と同じ内容になる
struct ReservationNumberField: View {
    @Binding var number: String
    /// すでに予約とつながっているか
    let isLinked: Bool
    let tint: Color
    let textColor: Color
    let secondaryText: Color
    let fieldBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("予約番号（任意）")
                .font(.caption)
                .foregroundColor(secondaryText)
            HStack(spacing: 8) {
                Image(systemName: "number.square")
                    .font(.caption)
                    .foregroundColor(tint.opacity(0.7))
                TextField("例：AB1234", text: $number)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundColor(textColor)
            }
            .padding(12)
            .background(fieldBackground)
            .cornerRadius(12)
            Text(isLinked
                 ? "予約とつながっています。ここで直した時刻・発着地・便は、予約にも入ります"
                 : "入れると予約の一覧にも入ります。時刻・発着地・便はそのまま引き継ぎます")
                .font(.caption2)
                .foregroundColor(secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
