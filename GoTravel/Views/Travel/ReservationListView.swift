import SwiftUI

/// 旅行の予約をまとめる画面。
///
/// 旅行先で予約確認メールを探し直すのが手間なので、
/// **予約番号をすぐ出せること**を中心に据えている。
struct ReservationListView: View {
    let plan: TravelPlan

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

                Button {
                    editing = reservation
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                .buttonStyle(.plain)
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
        .background(RoundedRectangle(cornerRadius: 14).fill(cardFill))
        .contextMenu {
            Button("編集") { editing = reservation }
            Button("削除", role: .destructive) { delete(reservation) }
        }
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
}
