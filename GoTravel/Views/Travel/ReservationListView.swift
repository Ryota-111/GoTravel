import SwiftUI

/// 旅行の予約をまとめる画面。
///
/// 旅行先で予約確認メールを探し直すのが手間なので、
/// **予約番号をすぐ出せること**を中心に据えている。
struct ReservationListView: View {
    let plan: TravelPlan
    /// タブに埋め込むときは true。NavigationStack とツールバーを出さない
    var isEmbedded: Bool = false

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var editing: Reservation?
    @State private var copiedId: String?

    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    /// 日時の決まっているものを先に、時系列で並べる
    private var reservations: [Reservation] {
        currentPlan.reservations.sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.title < rhs.title
            }
        }
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    var body: some View {
        if isEmbedded {
            embeddedContent
        } else {
            standaloneContent
        }
    }

    /// タブの中身。背景と枠は親が持つ
    private var embeddedContent: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button {
                    editing = Reservation()
                } label: {
                    Label("予約を追加", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(accent)
                }
            }

            if reservations.isEmpty {
                emptyState
            } else {
                ForEach(reservations) { reservation in
                    reservationCard(reservation)
                }
            }
        }
        .sheet(item: $editing) { reservation in
            ReservationEditorView(planId: plan.id ?? "", reservation: reservation)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
    }

    private var standaloneContent: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                if reservations.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(reservations) { reservation in
                                reservationCard(reservation)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("予約リスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editing = Reservation()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(accent)
                    .accessibilityLabel(Text("予約を追加"))
                }
            }
            .sheet(item: $editing) { reservation in
                ReservationEditorView(planId: plan.id ?? "", reservation: reservation)
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "ticket")
                .font(.system(size: 44))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))

            Text("まだ予約が登録されていません")
                .font(.subheadline.weight(.medium))
                .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))

            Text("飛行機・宿・レストランの予約番号をまとめておくと、\n現地で確認メールを探さずに済みます。")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                editing = Reservation()
            } label: {
                Text("予約を追加")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(ThemePreset.readableText(on: accent))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(accent))
            }
            .padding(.top, 4)
        }
        .padding(30)
    }

    private func reservationCard(_ reservation: Reservation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: reservation.kind.icon)
                    .font(.system(size: 16))
                    .foregroundColor(accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(accent.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(reservation.title.isEmpty ? reservation.kind.label : reservation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(textColor)
                        .lineLimit(2)

                    if let date = reservation.date {
                        Text(Self.dateFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                Spacer(minLength: 0)

                // 長押しの contextMenu だけだと削除に気づけない。
                // 旅行計画のカードと同じ「…」に揃え、1度覚えれば他でも使えるようにする
                Menu {
                    Button {
                        editing = reservation
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }

                    Button("削除", systemImage: "trash", role: .destructive) {
                        delete(reservation)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("予約のメニュー")
            }

            // 空港・駅で一番見るものなので、予約番号の前に出す
            if reservation.hasRoute {
                routeRow(reservation)
            }

            if !detailChips(reservation).isEmpty {
                FlowDetailChips(chips: detailChips(reservation),
                                textColor: textColor,
                                secondary: themeManager.currentTheme.secondaryText)
            }

            if let number = reservation.confirmationNumber, !number.isEmpty {
                confirmationNumberRow(number, id: reservation.id)
            }

            if let note = reservation.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let link = reservation.linkURL, !link.isEmpty, let url = URL(string: link) {
                Link(destination: url) {
                    Label("予約内容を開く", systemImage: "arrow.up.forward.square")
                        .font(.caption.weight(.medium))
                        .foregroundColor(accent)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardFill)
                // 白黒テーマは背景とカードの明るさがほぼ同じなので必ず枠を引く
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(textColor.opacity(0.12), lineWidth: 1))
        )

    }

    /// 出発地 → 到着地。時刻が入っていればその下に添える
    private func routeRow(_ reservation: Reservation) -> some View {
        HStack(alignment: .top, spacing: 8) {
            endpoint(place: reservation.departurePlace, time: reservation.date, alignment: .leading)

            VStack(spacing: 2) {
                Image(systemName: reservation.kind == .flight ? "airplane" : "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accent)
                if let duration = durationText(reservation) {
                    Text(duration)
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
            }
            .padding(.top, 6)

            endpoint(place: reservation.arrivalPlace, time: reservation.arrivalDate, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.06)))
    }

    private func endpoint(place: String?, time: Date?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(place ?? "-")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let time {
                Text(Self.timeFormatter.string(from: time))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    /// 出発から到着までの所要時間。両方入っているときだけ
    private func durationText(_ reservation: Reservation) -> String? {
        guard let start = reservation.date, let end = reservation.arrivalDate, end > start else { return nil }
        let minutes = Int(end.timeIntervalSince(start) / 60)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)分" }
        return rest == 0 ? "\(hours)時間" : "\(hours)時間\(rest)分"
    }

    /// 便名・座席・ターミナルなど、短い情報をまとめて出す
    private func detailChips(_ reservation: Reservation) -> [(String, String)] {
        var chips: [(String, String)] = []
        if let number = reservation.transportNumber, !number.isEmpty {
            chips.append((reservation.kind == .flight ? "便名" : "列車", number))
        }
        if let seat = reservation.seat, !seat.isEmpty {
            chips.append(("座席", seat))
        }
        if let terminal = reservation.terminal, !terminal.isEmpty {
            chips.append(("ターミナル", terminal))
        }
        return chips
    }

    /// 予約番号はこの機能の主役なので、大きく出してタップでコピーできるようにする
    private func confirmationNumberRow(_ number: String, id: String) -> some View {
        Button {
            UIPasteboard.general.string = number
            copiedId = id
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedId == id { copiedId = nil }
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("予約番号")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Text(number)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)

                Image(systemName: copiedId == id ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(copiedId == id ? themeManager.currentTheme.success : accent)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func delete(_ reservation: Reservation) {
        guard let userId = authVM.userId else { return }
        var updated = currentPlan
        updated.reservations.removeAll { $0.id == reservation.id }
        viewModel.update(updated, userId: userId)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

/// 便名・座席などの短い情報を並べる。
/// 文字数がまちまちなので、固定列にせず幅なりに折り返す
private struct FlowDetailChips: View {
    let chips: [(String, String)]
    let textColor: Color
    let secondary: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
            ForEach(chips, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(secondary)
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
