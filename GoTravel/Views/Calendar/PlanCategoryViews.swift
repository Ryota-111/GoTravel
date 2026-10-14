import SwiftUI

// MARK: - カテゴリ（カレンダー）の画面（3.0）

/// カレンダータブの上の、カテゴリの切り替え。「すべて」「自分用」「家族👥」…「＋」
struct PlanCategoryBar: View {
    @Binding var selection: PlanCategorySelection
    let tint: Color
    let textColor: Color
    /// 「＋」を押したとき（新しいカテゴリ）
    let onAdd: () -> Void
    /// 長押しで編集
    let onEdit: (PlanCategory) -> Void

    @ObservedObject private var manager = PlanCategoryManager.shared

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "すべて", color: tint, selected: selection == .all) { selection = .all }
                chip(title: PlanCategory.personalName, color: tint, selected: selection == .personal) { selection = .personal }
                ForEach(manager.categories) { category in
                    chip(title: category.name, color: category.color, shared: category.isShared,
                         selected: selection == .category(category.id)) {
                        selection = .category(category.id)
                    }
                    .contextMenu {
                        Button {
                            onEdit(category)
                        } label: {
                            Label("編集・共有", systemImage: "pencil")
                        }
                    }
                }
                // 選んでいるカテゴリの編集・共有（長押しに気づかない人のため、ボタンでも開ける）
                if case .category(let id) = selection, let category = manager.category(for: id) {
                    Button { onEdit(category) } label: {
                        Image(systemName: category.isShared ? "person.2.circle" : "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(tint)
                            .frame(width: 34, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("「\(category.name)」の編集・共有")
                }
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(tint)
                        .frame(width: 34, height: 30)
                        .background(Capsule().strokeBorder(tint.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("カテゴリを追加")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func chip(title: String, color: Color, shared: Bool = false, selected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if shared {
                    Image(systemName: "person.2.fill").font(.system(size: 9, weight: .bold))
                }
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
            .foregroundColor(selected ? ThemePreset.readableText(on: color) : textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(selected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.14)))
            )
        }
        .buttonStyle(.plain)
    }
}

/// カレンダータブでタグを選ぶ（選んでいる間は、そのタグの予定だけを出す）
struct PlanTagFilterBar: View {
    let tags: [PlanTag]
    @Binding var selectedIDs: Set<String>
    let textColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textColor.opacity(0.5))
                ForEach(tags) { tag in
                    let selected = selectedIDs.contains(tag.id)
                    Button {
                        if selected { selectedIDs.remove(tag.id) } else { selectedIDs.insert(tag.id) }
                    } label: {
                        Text(tag.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(selected ? .white : tag.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(selected
                                ? AnyShapeStyle(ThemePreset.readableTint(tag.color, on: .white))
                                : AnyShapeStyle(tag.color.opacity(0.12))))
                    }
                    .buttonStyle(.plain)
                }
                if !selectedIDs.isEmpty {
                    Button("すべて表示") { selectedIDs = [] }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textColor.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// カテゴリを作る・直す・共有する・消す
struct PlanCategoryEditorView: View {
    /// nil なら新しく作る
    let editing: PlanCategory?
    var onCreated: ((PlanCategory) -> Void)? = nil

    @ObservedObject private var manager = PlanCategoryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex = PlanTagPalette.swatches[0].hex
    @State private var showsDeleteConfirm = false

    private var current: PlanCategory? { editing.flatMap { manager.category(for: $0.id) } ?? editing }
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

                if let current {
                    PlanCategoryShareSection(categoryId: current.id, tint: color)

                    Section {
                        Button("このカテゴリを削除", role: .destructive) { showsDeleteConfirm = true }
                    } footer: {
                        Text("入っている予定とタグは「自分用」に移ります（消えません）。")
                    }
                }
            }
            .tint(color)
            .navigationTitle(editing == nil ? "カテゴリを追加" : "カテゴリを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "追加" : "保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmed.isEmpty)
                }
            }
            .onAppear {
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
        }
        dismiss()
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
