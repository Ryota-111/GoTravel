import SwiftUI

// MARK: - カテゴリ（カレンダー）の画面（3.0）

/// カレンダーをタグで絞り込む（右上の絞り込みボタンから）。選んでいる間は、そのタグの予定だけを出す
struct PlanTagFilterSheet: View {
    let tags: [PlanTag]
    @Binding var selectedIDs: Set<String>
    let categoryName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if tags.isEmpty {
                    Text("「\(categoryName)」にはタグがありません。タグは予定を作るときや、タグ管理から作れます。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Section {
                        ForEach(tags) { tag in
                            Button {
                                if selectedIDs.contains(tag.id) {
                                    selectedIDs.remove(tag.id)
                                } else {
                                    selectedIDs.insert(tag.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Circle().fill(tag.color).frame(width: 14, height: 14)
                                    Text(tag.name).foregroundColor(.primary)
                                    Spacer()
                                    if selectedIDs.contains(tag.id) {
                                        Image(systemName: "checkmark").foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    } footer: {
                        Text("選んだタグのどれかが付いている予定だけを、カレンダーに表示します。")
                    }
                }
            }
            .navigationTitle("タグで絞り込む")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("すべて表示") {
                        selectedIDs = []
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

/// カテゴリを作る・直す・共有する・消す
struct PlanCategoryEditorView: View {
    /// nil なら新しく作る
    let editing: PlanCategory?
    /// 新しく作るとき、はじめから「共有する」をオンにしておくか（共有カレンダーを作る入口から開いたとき）
    var sharesOnCreate = false
    var onCreated: ((PlanCategory) -> Void)? = nil

    @ObservedObject private var manager = PlanCategoryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex = PlanTagPalette.swatches[0].hex
    @State private var showsDeleteConfirm = false

    /// 作ってすぐ共有したカテゴリ（作ったあとも画面を閉じず、共有コードを見せる）
    @State private var createdId: String?
    @State private var shareAfterCreate = false
    @State private var isCreatingShare = false
    @State private var shareError: String?

    private var current: PlanCategory? {
        if let createdId { return manager.category(for: createdId) }
        return editing.flatMap { manager.category(for: $0.id) } ?? editing
    }
    private var color: Color { Color(hex: colorHex) ?? .gray }
    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：家族、友達、仕事", text: $name)
                } header: {
                    Text("カテゴリ名")
                } footer: {
                    Text("カテゴリごとにカレンダーが分かれます。予定を入れるときに、どのカテゴリに入れるかを選びます。")
                }

                // 共有は色より先に出す（共有できることが目に入るように）
                if let current {
                    PlanCategoryShareSection(categoryId: current.id, tint: color)
                } else {
                    Section {
                        Toggle("作ったら、家族や友達と共有する", isOn: $shareAfterCreate)
                    } footer: {
                        Text("共有すると、このカテゴリの予定とタグを、家族や友達と一緒に見て書けます。共有コードを送るだけで参加できます（相手も Travory 3.0 以降）。")
                    }
                }

                Section("色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(PlanTagPalette.swatches) { swatch in
                            Button { colorHex = swatch.hex } label: {
                                Circle()
                                    .fill(swatch.color)
                                    .frame(height: 34)
                                    .overlay(Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .opacity(colorHex == swatch.hex ? 1 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(swatch.name)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if current != nil {
                    Section {
                        Button("このカテゴリを削除", role: .destructive) { showsDeleteConfirm = true }
                    } footer: {
                        Text("入っている予定とタグは「自分用」に移ります（消えません）。")
                    }
                }
            }
            .tint(color)
            .navigationTitle(editing == nil && createdId == nil ? (sharesOnCreate ? "共有カレンダーを作る" : "カテゴリを追加") : "カテゴリを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if createdId != nil {
                        Button("完了") { dismiss() }
                            .fontWeight(.semibold)
                    } else {
                        Button(editing == nil ? "追加" : "保存") { save() }
                            .fontWeight(.semibold)
                            .disabled(trimmed.isEmpty)
                    }
                }
            }
            .overlay {
                if isCreatingShare { ProgressView() }
            }
            .alert("共有できませんでした", isPresented: Binding(get: { shareError != nil },
                                                          set: { if !$0 { shareError = nil } })) {
                Button("OK", role: .cancel) { shareError = nil }
            } message: {
                Text(shareError ?? "")
            }
            .onAppear {
                shareAfterCreate = sharesOnCreate
                if let editing {
                    name = editing.name
                    colorHex = editing.colorHex ?? colorHex
                } else {
                    colorHex = PlanTagPalette.hex(forIndex: manager.categories.count + 3)
                }
            }
            .confirmationDialog("このカテゴリを削除しますか？", isPresented: $showsDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) { delete() }
            } message: {
                Text(deleteMessage)
            }
        }
    }

    private var deleteMessage: String {
        guard let current, current.isShared, let userId = manager.userId else {
            return "入っている予定とタグは「自分用」に移ります。"
        }
        return current.isOwner(userId: userId)
            ? "共有をやめてから削除します。友達の手元では、このカテゴリは更新されなくなります。あなたの予定とタグは「自分用」に移ります。"
            : "このカテゴリから抜けてから削除します。ほかの人の予定はそのままです。あなたの手元の予定とタグは「自分用」に移ります。"
    }

    private func save() {
        if var updated = current {
            updated.name = trimmed
            updated.colorHex = colorHex
            manager.upsert(updated)
            SharedCategoryService.shared.categoryDidChange(updated)
        } else if let created = manager.add(name: trimmed, colorHex: colorHex) {
            onCreated?(created)
            if shareAfterCreate {
                // 閉じずに、そのまま共有コードを出す
                createdId = created.id
                Task { await shareCreated(created) }
                return
            }
        }
        dismiss()
    }

    private func shareCreated(_ category: PlanCategory) async {
        guard let userId = manager.userId else { return }
        isCreatingShare = true
        do {
            _ = try await SharedCategoryService.shared.share(category, userId: userId)
        } catch {
            shareError = ICloudGuidanceText.isAccountProblem(error)
                ? ICloudGuidanceText.sharingUnavailable
                : "カテゴリは作りましたが、共有できませんでした。通信環境をご確認のうえ、下の「このカテゴリを共有する」からもう一度お試しください。"
        }
        isCreatingShare = false
    }

    private func delete() {
        guard let current, let userId = manager.userId else { return }
        if current.isShared {
            if current.isOwner(userId: userId) {
                SharedCategoryService.shared.stopSharing(current, userId: userId)
            } else {
                SharedCategoryService.shared.leave(current, userId: userId)
            }
        }
        manager.delete(current)
        dismiss()
    }
}

/// カテゴリの「友達と共有」（`SharedCategoryService`）。
/// 共有コードは**公開に成功してから**出す（公開されていないコードを送ってしまわないため）
struct PlanCategoryShareSection: View {
    let categoryId: String
    let tint: Color

    @ObservedObject private var manager = PlanCategoryManager.shared
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var copied = false
    @State private var showsStopConfirm = false

    private var category: PlanCategory? { manager.category(for: categoryId) }
    private var isOwner: Bool {
        guard let category, let userId = manager.userId else { return false }
        return category.isOwner(userId: userId)
    }

    var body: some View {
        Section {
            if let category, category.isShared, let code = category.shareCode {
                Text(code)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .textSelection(.enabled)
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                } label: {
                    Label(copied ? "コピーしました" : "コードをコピー", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                ShareLink(item: inviteMessage(name: category.name, code: code)) {
                    Label("招待を送る", systemImage: "square.and.arrow.up")
                }
                Text("\(category.sharedWith.count)人で共有しています")
                Button(isOwner ? "共有をやめる" : "このカテゴリから抜ける", role: .destructive) {
                    showsStopConfirm = true
                }
            } else {
                Button {
                    Task { await share() }
                } label: {
                    HStack {
                        Label("このカテゴリを共有する", systemImage: "person.badge.plus")
                        if isWorking { Spacer(); ProgressView() }
                    }
                }
                .disabled(isWorking)
            }
        } header: {
            Text("友達と共有")
        } footer: {
            Text(category?.isShared == true
                 ? "相手はプロフィールの「共有コードで参加」から入れます（Travory 3.0 以降）。通知・済みの印・写真は、それぞれのものです。"
                 : "共有すると、このカテゴリの予定とタグを、友達と一緒に見て書けます。誰が書き換えても全員にとどきます。相手も Travory 3.0 以降が必要です。")
        }
        .alert("共有できませんでした", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(isOwner ? "共有をやめますか？" : "このカテゴリから抜けますか？",
                            isPresented: $showsStopConfirm, titleVisibility: .visible) {
            Button(isOwner ? "共有をやめる" : "抜ける", role: .destructive) { stop() }
        } message: {
            Text(isOwner
                 ? "友達の手元では、このカテゴリは更新されなくなります。あなたのカテゴリと予定はそのまま残ります。"
                 : "このカテゴリと予定は、あなたの手元に残ります（以後は更新されません）。ほかの人の予定はそのままです。")
        }
    }

    private func inviteMessage(name: String, code: String) -> String {
        """
        Travory のカレンダー「\(name)」に招待します！
        Travory（3.0 以降）のプロフィール →「共有コードで参加」から、この共有コードを入力してください。

        共有コード: \(code)
        """
    }

    private func share() async {
        guard let category, let userId = manager.userId else { return }
        isWorking = true
        do {
            _ = try await SharedCategoryService.shared.share(category, userId: userId)
        } catch {
            errorMessage = ICloudGuidanceText.isAccountProblem(error)
                ? ICloudGuidanceText.sharingUnavailable
                : "通信環境をご確認のうえ、もう一度お試しください。"
        }
        isWorking = false
    }

    private func stop() {
        guard let category, let userId = manager.userId else { return }
        if isOwner {
            SharedCategoryService.shared.stopSharing(category, userId: userId)
        } else {
            SharedCategoryService.shared.leave(category, userId: userId)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}
