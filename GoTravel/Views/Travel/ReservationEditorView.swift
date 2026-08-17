import SwiftUI

/// 予約の追加・編集
struct ReservationEditorView: View {
    let planId: String
    @State var reservation: Reservation

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// 日時が決まっていない予約もあるので、入力するかどうかを選べるようにする
    @State private var hasDate = false
    @State private var date = Date()

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    private var canSave: Bool {
        !reservation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? themeManager.currentTheme.backgroundDark
                    : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        kindPicker
                        field(label: "予約の名前", text: $reservation.title, placeholder: reservation.kind.placeholder)
                        dateSection
                        numberField
                        optionalFields
                    }
                    .padding(20)
                }
            }
            .navigationTitle(reservation.title.isEmpty ? "予約を追加" : "予約を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .foregroundColor(canSave ? accent : themeManager.currentTheme.secondaryText)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if let existing = reservation.date {
                    hasDate = true
                    date = existing
                }
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("種類")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Reservation.Kind.allCases) { kind in
                    ReservationKindButton(
                        kind: kind,
                        isSelected: reservation.kind == kind,
                        accent: accent,
                        fill: cardFill,
                        textColor: textColor
                    ) {
                        reservation.kind = kind
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasDate) {
                Text("日時を設定する")
                    .font(.subheadline)
                    .foregroundColor(textColor)
            }
            .tint(accent)

            if hasDate {
                DatePicker("", selection: $date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
    }

    private var numberField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予約番号")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            TextField("例：ABC12345", text: Binding(
                get: { reservation.confirmationNumber ?? "" },
                set: { reservation.confirmationNumber = $0 }
            ))
            .font(.system(size: 17, design: .monospaced))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.characters)
            .foregroundColor(textColor)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))

            Text("旅行中に一番探すものなので、控えておくと安心です。")
                .font(.caption2)
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
    }

    private var optionalFields: some View {
        VStack(spacing: 16) {
            field(label: "メモ", text: Binding(
                get: { reservation.note ?? "" },
                set: { reservation.note = $0 }
            ), placeholder: "例：朝食付き / 禁煙ルーム")

            field(label: "リンク", text: Binding(
                get: { reservation.linkURL ?? "" },
                set: { reservation.linkURL = $0 }
            ), placeholder: "予約確認ページのURL")
        }
    }

    private func field(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            TextField(placeholder, text: text)
                .foregroundColor(textColor)
                .autocorrectionDisabled()
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        }
    }

    private func save() {
        guard let userId = authVM.userId,
              var plan = viewModel.travelPlans.first(where: { $0.id == planId }) else { return }

        var edited = reservation
        edited.title = edited.title.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.date = hasDate ? date : nil
        edited.confirmationNumber = edited.confirmationNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.note = edited.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.linkURL = edited.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = plan.reservations.firstIndex(where: { $0.id == edited.id }) {
            plan.reservations[index] = edited
        } else {
            plan.reservations.append(edited)
        }

        viewModel.update(plan, userId: userId)
        dismiss()
    }
}

/// 種類の選択ボタン。色の出し分けを本体に書くと型チェックが重くなるため分ける
private struct ReservationKindButton: View {
    let kind: Reservation.Kind
    let isSelected: Bool
    let accent: Color
    let fill: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: kind.icon)
                    .font(.system(size: 16))
                Text(kind.label)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? accent : textColor)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? accent.opacity(0.16) : fill))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
