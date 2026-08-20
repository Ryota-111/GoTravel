import SwiftUI

/// 旅行計画を複製する。
///
/// 毎年の帰省や定番の旅行で「ベースは前回と同じで、日程だけ変えたい」
/// という要望から用意した。日数は元のままで、出発日だけ選び直してもらう。
struct DuplicateTravelPlanView: View {
    let plan: TravelPlan

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var startDate: Date
    @State private var includeSchedule = true
    @State private var includePacking = true
    @State private var includeReservations = true
    @State private var isWorking = false

    init(plan: TravelPlan) {
        self.plan = plan
        _title = State(initialValue: "\(plan.title) のコピー")
        // 前回と同じ日付で作ると、どちらが新しいのか分からなくなる。
        // 今日以降で選び直してもらう前提で、今日を初期値にする
        _startDate = State(initialValue: Calendar.current.startOfDay(for: Date()))
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    private var scheduleItemCount: Int {
        plan.daySchedulesInRange.reduce(0) { $0 + $1.scheduleItems.count }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWorking
    }

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: plan.dayCount - 1, to: startDate) ?? startDate
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
                        titleField
                        dateSection
                        contentToggles
                        noticeText
                    }
                    .padding(20)
                }
            }
            .navigationTitle("計画を複製")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("複製") { duplicate() }
                        .foregroundColor(canSave ? accent : themeManager.currentTheme.secondaryText)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("新しいタイトル")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            TextField("例：沖縄旅行 2026", text: $title)
                .foregroundColor(textColor)
                .autocorrectionDisabled()
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("出発日")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                HStack {
                    Text("\(plan.dayCount)日間（元の計画と同じ）")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    Spacer()
                    Text("〜 \(dateString(endDate))")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(textColor)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        }
    }

    private var contentToggles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("引き継ぐもの")
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)

            VStack(spacing: 0) {
                toggleRow("タイムスケジュール", count: scheduleItemCount, isOn: $includeSchedule)
                Divider().padding(.leading, 14)
                toggleRow("持ち物リスト", count: plan.packingItems.count, isOn: $includePacking)
                Divider().padding(.leading, 14)
                toggleRow("予約", count: plan.reservations.count, isOn: $includeReservations)
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(cardFill))
        }
    }

    private func toggleRow(_ label: String, count: Int, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                Text("\(count)件")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
        .tint(accent)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.5 : 1)
        .padding(14)
    }

    private var noticeText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("実際に使った金額と持ち物のチェックは引き継ぎません", systemImage: "info.circle")
            Label("共有はされていない状態で作られます", systemImage: "info.circle")
        }
        .font(.caption2)
        .foregroundColor(themeManager.currentTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    private func duplicate() {
        guard let userId = authVM.userId else { return }
        isWorking = true

        var copy = plan.duplicated(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: Calendar.current.startOfDay(for: startDate),
            includeSchedule: includeSchedule,
            includePacking: includePacking,
            includeReservations: includeReservations
        )
        copy.localImageFileName = copiedImageFileName()

        viewModel.add(copy, userId: userId)
        dismiss()
    }

    /// カバー写真はファイルごと複製する。
    /// ファイル名だけ引き継ぐと、片方の計画を削除したときに
    /// もう片方の写真まで消えてしまう
    private func copiedImageFileName() -> String? {
        guard let original = plan.localImageFileName,
              let image = FileManager.documentsImage(named: original),
              let data = image.jpegData(compressionQuality: 0.9) else { return nil }

        let fileName = "travel_plan_\(UUID().uuidString).jpg"
        do {
            try FileManager.saveImageDataToDocuments(data: data, named: fileName)
            return fileName
        } catch {
            return nil
        }
    }
}
