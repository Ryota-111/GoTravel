import SwiftUI

// MARK: - 前回の控え（読むだけ）
//
// 端末に残した旅行計画の控え（`TravelPlanBackupStore`）を見せる画面。
// iCloud が外れて一覧が空のときでも、旅行中に日程・予約番号・持ち物を確かめられるようにする。
//
// **見た目はいつもの旅行計画の画面に寄せるが、部品は使い回さない。**
// いつもの画面には書き換えの入口が数十か所あり、1つでも残ると、iCloud が外れている間に
// 書き込んで、戻ったときに中身が二重になったり古い内容で上書きしたりする。
// ここは見た目だけをまねた、読むだけの部品で組む。写真・天気・地図は控えに無いので出さない

/// 控えの一覧
struct TravelPlanBackupView: View {
    let backup: TravelPlanBackupStore.Backup

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var theme: ThemePreset { themeManager.currentTheme }
    private var palette: BackupPalette { BackupPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        BackupNotice(savedAt: backup.savedAt, palette: palette)
                        ForEach(backup.plans.sorted { $0.startDate > $1.startDate }) { plan in
                            NavigationLink {
                                BackupPlanDetailView(plan: plan, savedAt: backup.savedAt)
                            } label: {
                                planCard(plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("前回の控え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(palette.accent)
                }
            }
        }
    }

    private func planCard(_ plan: TravelPlan) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: theme.style.radiusSmall)
                .fill((plan.cardColor ?? theme.primary).opacity(0.85))
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundColor(palette.text)
                Text(BackupFormat.dateRange(plan) + "・" + plan.destination)
                    .font(.caption)
                    .foregroundColor(palette.subText)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(palette.subText)
        }
        .padding(14)
        .background(palette.cardBackground(radius: theme.style.radiusLarge))
    }
}

// MARK: - 1つの旅行計画

private struct BackupPlanDetailView: View {
    let plan: TravelPlan
    let savedAt: Date

    private enum Tab: String, CaseIterable, Identifiable {
        case schedule = "日程"
        case reservation = "予約確認"
        case list = "リスト"
        var id: String { rawValue }
    }

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: Tab = .schedule
    @State private var selectedDay = 1
    @State private var listKind: PackingItem.Kind? = .packing
    @State private var copiedId: String?

    private var theme: ThemePreset { themeManager.currentTheme }
    private var palette: BackupPalette { BackupPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BackupNotice(savedAt: savedAt, palette: palette)
                    header
                    tabBar
                    switch tab {
                    case .schedule: scheduleSection
                    case .reservation: reservationSection
                    case .list: listSection
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedDay = initialDay }
    }

    /// 旅行中なら今日の日、それ以外は1日目から
    private var initialDay: Int {
        plan.dayNumber(forDate: Date()) ?? 1
    }

    // MARK: 見出し

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.destination)
                .font(.caption.weight(.semibold))
                .foregroundColor(palette.subText)
            Text(plan.title)
                .font(theme.displayFont(.title2))
                .foregroundColor(palette.text)
            Text(BackupFormat.dateRange(plan))
                .font(.subheadline)
                .foregroundColor(palette.subText)
        }
    }

    /// いつもの画面の上のタブと同じ形（下線で選択を示す）
    private var tabBar: some View {
        HStack(spacing: 20) {
            ForEach(Tab.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { tab = item }
                } label: {
                    VStack(spacing: 6) {
                        Text(item.rawValue)
                            .font(.system(size: 16, weight: tab == item ? .bold : .regular))
                            .foregroundColor(tab == item ? palette.text : palette.subText)
                        Capsule()
                            .fill(tab == item ? palette.accent : Color.clear)
                            .frame(height: 3)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 日程

    private var days: [DaySchedule] {
        plan.daySchedulesInRange.sorted { $0.dayNumber < $1.dayNumber }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            dayTabs
            let items = days.first { $0.dayNumber == selectedDay }?
                .scheduleItems.sorted(by: ScheduleItem.chronologically) ?? []
            if items.isEmpty {
                emptyText("この日の予定はありません")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        timelineRow(item, isLast: index == items.count - 1)
                    }
                }
            }
        }
    }

    /// いつもの画面と同じ Day のタブ（曜日と件数つき）
    private var dayTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...max(plan.dayCount, 1), id: \.self) { day in
                    let isSelected = selectedDay == day
                    let count = days.first { $0.dayNumber == day }?.scheduleItems.count ?? 0
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedDay = day }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Day \(day)")
                                .font(.system(size: 13, weight: .bold))
                            Text(BackupFormat.day(plan.date(forDay: day)))
                                .font(.system(size: 10))
                                .opacity(0.8)
                            Text("\(count)件")
                                .font(.system(size: 10, weight: .medium))
                                .monospacedDigit()
                                .opacity(count == 0 ? 0.5 : 0.9)
                        }
                        .foregroundColor(isSelected ? ThemePreset.readableText(on: palette.accent) : palette.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? palette.accent : palette.card)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// いつもの画面と同じ、時刻のレールに沿った1行
    private func timelineRow(_ item: ScheduleItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(item.timeText)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                if let end = item.endTimeText {
                    Text("〜\(end)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .opacity(0.75)
                }
            }
            .foregroundColor(palette.subText)
            .frame(width: 50, alignment: .trailing)

            VStack(spacing: 0) {
                Circle()
                    .stroke(palette.accent, lineWidth: 2.5)
                    .frame(width: 12, height: 12)
                    .padding(.top, 3)
                if !isLast {
                    Rectangle()
                        .fill(palette.subText.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(palette.text)
                if let location = item.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(palette.subText)
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(palette.subText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let cost = item.displayCost, cost > 0 {
                    Text("¥" + cost.formatted(.number.precision(.fractionLength(0)))
                         + (item.costNote.map { "　\($0)" } ?? ""))
                        .font(.system(size: 12))
                        .foregroundColor(palette.subText)
                }
            }
            .padding(.bottom, isLast ? 0 : 22)
            Spacer(minLength: 0)
        }
    }

    // MARK: 予約確認

    private var reservationSection: some View {
        VStack(spacing: 12) {
            if plan.reservations.isEmpty {
                emptyText("予約は登録されていません")
            }
            ForEach(plan.reservations.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }) { reservation in
                reservationCard(reservation)
            }
        }
    }

    /// いつもの画面と同じ予約のカード。予約番号は大きく出し、押すとコピーできる
    private func reservationCard(_ reservation: Reservation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: reservation.kind.icon)
                    .font(.system(size: 16))
                    .foregroundColor(palette.accent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(palette.accent.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(reservation.title.isEmpty ? reservation.kind.label : reservation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(palette.text)
                    if let line = reservation.dateLineText {
                        Text(line)
                            .font(.caption)
                            .foregroundColor(palette.subText)
                    }
                }
                Spacer(minLength: 0)
            }

            if reservation.hasRoute {
                HStack {
                    routeEnd(reservation.departurePlace, reservation.date, reservation.dateTimeZone)
                    Spacer()
                    Image(systemName: reservation.kind == .flight ? "airplane" : "arrow.right")
                        .foregroundColor(palette.accent)
                    Spacer()
                    routeEnd(reservation.arrivalPlace, reservation.arrivalDate, reservation.arrivalTimeZone)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(palette.accent.opacity(0.06)))
            }

            if let location = reservation.location {
                Label(location.name, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(palette.subText)
            }

            if let number = reservation.confirmationNumber, !number.isEmpty {
                Button {
                    UIPasteboard.general.string = number
                    copiedId = reservation.id
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("予約番号")
                                .font(.caption2)
                                .foregroundColor(palette.subText)
                            Text(number)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(palette.text)
                        }
                        Spacer()
                        Label(copiedId == reservation.id ? "コピーしました" : "コピー",
                              systemImage: copiedId == reservation.id ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(palette.accent)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.accent.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            if let note = reservation.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(palette.subText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(palette.cardBackground(radius: theme.style.radiusLarge))
    }

    private func routeEnd(_ place: String?, _ time: Date?, _ zone: TimeZone) -> some View {
        VStack(spacing: 2) {
            Text(place ?? "-")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(palette.text)
                .lineLimit(1)
            if let time {
                Text(ScheduleClock.timeText(time, in: zone))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(palette.text)
            }
        }
    }

    // MARK: リスト

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("リストの種類", selection: $listKind) {
                ForEach(PackingItem.Kind.allCases) { kind in
                    Text(kind.title).tag(Optional(kind))
                }
                Text("メモ").tag(PackingItem.Kind?.none)
            }
            .pickerStyle(.segmented)

            if let kind = listKind {
                let items = plan.items(of: kind)
                if items.isEmpty {
                    emptyText("まだありません")
                }
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isChecked ? theme.success : palette.subText)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .foregroundColor(item.isChecked ? palette.subText : palette.text)
                                .strikethrough(item.isChecked)
                            if let note = item.note, !note.isEmpty {
                                Text(note).font(.caption).foregroundColor(palette.subText)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(palette.cardBackground(radius: 12))
                }
            } else if !plan.memos.isEmpty {
                // 3.0 からはメモが何枚もある
                ForEach(plan.memos) { memo in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(memo.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(palette.text)
                        if !memo.body.isEmpty {
                            Text(memo.body)
                                .foregroundColor(palette.text)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(palette.cardBackground(radius: 14))
                }
            } else {
                emptyText("メモはありません")
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(palette.subText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}

// MARK: - 共通

/// 「読むだけの控え」だとはっきり伝える帯。本物と見分けがつかないと、編集しようとして迷う
private struct BackupNotice: View {
    let savedAt: Date
    let palette: BackupPalette

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(palette.accent)
            Text("前回の控え（\(BackupFormat.savedAt(savedAt)) 時点）です。見ることだけできます。iCloudにつながると、いつもの画面に戻ります。")
                .font(.caption)
                .foregroundColor(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.accent.opacity(0.12)))
    }
}

/// テーマから決める色。文字はどれも、実際の地に対して読める色にする
private struct BackupPalette {
    let theme: ThemePreset
    let colorScheme: ColorScheme

    var background: Color { colorScheme == .dark ? theme.backgroundDark : theme.backgroundLight }
    var card: Color { colorScheme == .dark ? theme.secondaryBackgroundDark : theme.secondaryBackgroundLight }
    var text: Color { ThemePreset.readableText(on: card) }
    var subText: Color { text.opacity(0.65) }
    var accent: Color { ThemePreset.readableTint(theme.actionFill, on: card) }

    func cardBackground(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(card)
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(text.opacity(0.12), lineWidth: 1))
    }
}

private enum BackupFormat {
    static func savedAt(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().hour().minute())
    }

    /// 「10月1日(木)」
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    /// 「10/1 (木) — 10/7 (水)」
    static func dateRange(_ plan: TravelPlan) -> String {
        let formatter = DateFormatter.japanese
        formatter.dateFormat = "M/d (E)"
        return "\(formatter.string(from: plan.startDate)) — \(formatter.string(from: plan.endDate))"
    }
}
