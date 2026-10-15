import SwiftUI
import UniformTypeIdentifiers
import Combine

/// .ics ファイルを開いたときの中身（シートに渡すために包む）
struct ICSImportFile: Identifiable {
    let id = UUID()
    let name: String
    let candidates: [ICSImportRule.Candidate]

    /// ファイルを読む。読めなければ nil
    static func load(_ url: URL) -> ICSImportFile? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) else { return nil }
        let events = ICSParser.parse(text)
        return ICSImportFile(name: url.deletingPathExtension().lastPathComponent,
                             candidates: ICSImportRule.candidates(from: events))
    }

    /// 読み込める種類（.ics）
    static var contentTypes: [UTType] {
        [UTType(filenameExtension: "ics"), .calendarEvent].compactMap { $0 }
    }
}

/// 「Travory で開く」から .ics を受け取ったとき、カレンダーの画面へ渡す
final class ICSImportInbox: ObservableObject {
    static let shared = ICSImportInbox()
    @Published var file: ICSImportFile?
    /// 読めなかったときの知らせ
    @Published var failed = false

    func open(_ url: URL) {
        if let file = ICSImportFile.load(url) {
            self.file = file
        } else {
            failed = true
        }
    }
}

/// 読み込む予定を確かめてから入れる（3.0）
struct ICSImportView: View {
    let file: ICSImportFile
    var initialCategoryId: String?

    @EnvironmentObject private var viewModel: PlansViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selected: Set<String> = []
    @State private var categoryId: String?
    @State private var tagIDs: [String] = []
    @State private var hasPrepared = false
    @State private var result: String?

    private var rows: [(candidate: ICSImportRule.Candidate, status: ICSImportRule.Status)] {
        file.candidates.map { candidate in
            (candidate, ICSImportRule.status(of: candidate.plan, local: viewModel.plans.first { $0.id == candidate.plan.id }))
        }
    }

    private var newCount: Int { rows.filter { selected.contains($0.candidate.id) && $0.status == .new }.count }
    private var updateCount: Int { rows.filter { selected.contains($0.candidate.id) && $0.status == .update }.count }

    var body: some View {
        NavigationStack {
            List {
                if file.candidates.isEmpty {
                    Text("このファイルには、読み込める予定がありませんでした。")
                        .foregroundColor(.secondary)
                } else {
                    Section {
                        PlanCategoryPicker(categoryId: $categoryId, tagIDs: $tagIDs,
                                           accentColor: themeManager.currentTheme.listTint(for: colorScheme))
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } header: {
                        Text("入れるカテゴリ")
                    } footer: {
                        Text("新しく入る予定だけに使います。すでにある予定は、今のカテゴリのままです。")
                    }

                    Section {
                        ForEach(rows, id: \.candidate.id) { item in
                            candidateRow(item.candidate, status: item.status)
                        }
                    } header: {
                        HStack {
                            Text("予定（\(file.candidates.count)件）")
                            Spacer()
                            Button(allSelectable.isSubset(of: selected) ? "すべて外す" : "すべて選ぶ") {
                                selected = allSelectable.isSubset(of: selected) ? [] : allSelectable
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    } footer: {
                        Text("同じ予定をもう一度読み込むと、2重にならずに新しい内容で直します。通知や済みの印は、そのままです。")
                    }
                }
            }
            .navigationTitle(file.name.isEmpty ? "予定を読み込む" : file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("入れる") { importSelected() }
                        .fontWeight(.semibold)
                        .disabled(newCount + updateCount == 0)
                }
            }
            .onAppear(perform: prepare)
            .alert(result ?? "", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil; dismiss() } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var allSelectable: Set<String> {
        Set(rows.filter { $0.status == .new || $0.status == .update }.map(\.candidate.id))
    }

    private func prepare() {
        guard !hasPrepared else { return }
        hasPrepared = true
        categoryId = initialCategoryId
        selected = allSelectable
    }

    @ViewBuilder
    private func candidateRow(_ candidate: ICSImportRule.Candidate, status: ICSImportRule.Status) -> some View {
        let selectable = status == .new || status == .update
        Button {
            guard selectable else { return }
            if selected.contains(candidate.id) { selected.remove(candidate.id) } else { selected.insert(candidate.id) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selectable ? themeManager.currentTheme.listTint(for: colorScheme) : .secondary.opacity(0.4))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: candidate.plan.planType.icon)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(candidate.plan.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    Text(dateText(candidate.plan))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let badge = badge(status) {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(status == .update ? themeManager.currentTheme.listTint(for: colorScheme) : .secondary)
                    }
                    ForEach(candidate.notes, id: \.self) { note in
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .opacity(selectable ? 1 : 0.6)
    }

    private func badge(_ status: ICSImportRule.Status) -> String? {
        switch status {
        case .new: return nil
        case .update: return "すでにある予定を、新しい内容で直します"
        case .unchanged: return "すでに入っています（変わりなし）"
        case .recurringInProgress: return "繰り返しの予定がすでに進んでいるため、そのままにします"
        }
    }

    private func dateText(_ plan: Plan) -> String {
        let day = Date.FormatStyle().year().month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP"))
        var text: String
        switch plan.planType {
        case .daily:
            let time = Date.FormatStyle().hour().minute().locale(Locale(identifier: "ja_JP"))
            text = plan.startDate.formatted(day)
            if let start = plan.time {
                text += " " + start.formatted(time)
                if let end = plan.endTime { text += "〜" + end.formatted(time) }
            }
        case .outing:
            text = plan.startDate.formatted(day)
            if !Calendar.current.isDate(plan.startDate, inSameDayAs: plan.endDate) {
                text += " 〜 " + plan.endDate.formatted(day)
            }
        case .anniversary:
            text = plan.startDate.formatted(day)
        }
        if plan.recurrence != .none { text += "・\(plan.recurrence.displayName)" }
        return text
    }

    private func importSelected() {
        guard let userId = authVM.userId else { return }
        var added = 0, updated = 0
        for row in rows where selected.contains(row.candidate.id) {
            switch row.status {
            case .new:
                var plan = row.candidate.plan
                plan.categoryId = categoryId
                plan.reminders = PlanReminderDefaults.shared.reminders(for: plan.planType)
                viewModel.add(plan, userId: userId)
                added += 1
            case .update:
                guard let local = viewModel.plans.first(where: { $0.id == row.candidate.id }) else { continue }
                viewModel.update(ICSImportRule.merged(row.candidate.plan, into: local), userId: userId)
                updated += 1
            case .unchanged, .recurringInProgress:
                continue
            }
        }
        var parts: [String] = []
        if added > 0 { parts.append("\(added)件を入れました") }
        if updated > 0 { parts.append("\(updated)件を新しい内容にしました") }
        result = parts.joined(separator: "。") + "。"
    }
}
