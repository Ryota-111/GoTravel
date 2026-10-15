import SwiftUI

/// タグの管理。並び順がそのまま一覧の絞り込み行の並びになる。
///
/// 作りは `ManageCategoriesView` に揃えてある。
/// 違うのは既定のタグが無いこと（全部ユーザーが作る）と、並べ替えができること
struct ManagePlanTagsView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var tagManager = PlanTagManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var categoryManager = PlanCategoryManager.shared
    @State private var editingTag: PlanTag?
    /// タグを足すカテゴリ（3.0。タグはカテゴリごとに持つ）
    @State private var addingTarget: AddTarget?

    private struct AddTarget: Identifiable {
        let categoryId: String?
        var id: String { categoryId ?? "personal" }
    }

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        NavigationView {
            List {
                tagSection(categoryId: nil, title: PlanCategory.personalName)
                ForEach(categoryManager.categories) { category in
                    tagSection(categoryId: category.id,
                               title: category.isShared ? "\(category.name)（\(category.sharedWith.count)人で共有）" : category.name)
                }
            }
            .navigationTitle("タグ管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(accentColor)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(item: $addingTarget) { target in
            PlanTagEditorView(editing: nil, categoryId: target.categoryId)
        }
        .sheet(item: $editingTag) { tag in
            PlanTagEditorView(editing: tag)
        }
    }

    /// カテゴリごとのタグ。上から順に、予定一覧の絞り込みに並ぶ
    private func tagSection(categoryId: String?, title: String) -> some View {
        let tags = tagManager.tags(inCategory: categoryId)
        return Section {
            ForEach(tags) { tag in
                Button(action: { editingTag = tag }) {
                    HStack(spacing: 12) {
                        tagSwatch(tag)
                        Text(tag.name)
                            .foregroundColor(accentColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .onMove { source, destination in
                tagManager.move(inCategory: categoryId, fromOffsets: source, toOffset: destination)
            }

            Button {
                addingTarget = AddTarget(categoryId: categoryId)
            } label: {
                Label("タグを追加", systemImage: "plus")
                    .foregroundColor(themeManager.currentTheme.xprimary)
            }
        } header: {
            Text(title)
        } footer: {
            if categoryId == nil {
                Text("タグはカテゴリ（カレンダー）ごとに持ちます。共有したカテゴリのタグは、メンバー全員で同じものを使います。")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
        }
    }

    private func tagSwatch(_ tag: PlanTag) -> some View {
        Circle()
            .fill(tag.color)
            .frame(width: 22, height: 22)
    }
}

// MARK: - Tag Editor

/// 追加と編集で同じ画面を使う。
/// 作った直後に選択へ入れたい呼び出し元があるので、作成結果を渡せるようにしてある
struct PlanTagEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var tagManager = PlanTagManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    let editing: PlanTag?
    /// 新しく作るタグのカテゴリ（3.0。nil は「自分用」）
    var categoryId: String? = nil
    var onCreated: ((PlanTag) -> Void)? = nil

    @State private var name = ""
    @State private var selectedHex = PlanTagPalette.swatches[0].hex
    @State private var showDeleteConfirm = false

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var selectedColor: Color {
        Color(hex: selectedHex) ?? .gray
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// 同じカテゴリに同じ名前のタグは作れない。2つあると絞り込みの軸として使えなくなる
    private var isDuplicateName: Bool {
        let category = editing?.categoryId ?? categoryId
        return tagManager.tags.contains { $0.name == trimmedName && $0.id != editing?.id && $0.categoryId == category }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicateName
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    preview

                    VStack(alignment: .leading, spacing: 8) {
                        Text("タグ名")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(accentColor)

                        TextField("例：仕事、遊び、家族", text: $name)
                            .padding(14)
                            .background(colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedColor.opacity(0.4), lineWidth: 1.5))

                        if isDuplicateName {
                            Text("同じ名前のタグがあります")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)

                    colorSection

                    // 消したい人が最初に開くのはこの画面なので、削除はここに置く。
                    // 一覧のスワイプだけだと見つけられない
                    if editing != nil {
                        deleteButton
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle(editing == nil ? "タグを追加" : "タグを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editing == nil ? "追加" : "保存", action: save)
                        .foregroundColor(canSave ? selectedColor : themeManager.currentTheme.secondaryText)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                guard let editing else {
                    // 作るたびに同じ色から始まると、最初の数個が全部同じ色になる
                    selectedHex = PlanTagPalette.hex(forIndex: tagManager.tags.count)
                    return
                }
                name = editing.name
                selectedHex = editing.colorHex ?? PlanTagPalette.fallbackHex(forTagId: editing.id)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("このタグを削除")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.red.opacity(colorScheme == .dark ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .alert("このタグを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                guard let editing else { return }
                tagManager.delete(editing)
                presentationMode.wrappedValue.dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    private var deleteMessage: String {
        if let editing, let category = PlanCategoryManager.shared.category(for: editing.categoryId), category.isShared {
            return "「\(category.name)」のメンバー全員の予定からも、このタグが外れます。予定そのものは消えません。"
        }
        return "付いている予定からもこのタグが外れます。予定そのものは消えません。"
    }

    /// 一覧に出るのと同じ形で見せる。色を選んだ結果をここで確かめられる
    private var preview: some View {
        HStack(spacing: 12) {
            Text(trimmedName.isEmpty ? "タグ名" : trimmedName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ThemePreset.readableTint(selectedColor, on: .white), in: Capsule())

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("色")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
                .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(PlanTagPalette.swatches) { swatch in
                    Button(action: { selectedHex = swatch.hex }) {
                        Circle()
                            .fill(swatch.color)
                            .frame(height: 40)
                            .overlay(
                                Circle()
                                    .strokeBorder(accentColor.opacity(selectedHex == swatch.hex ? 0.9 : 0), lineWidth: 2.5)
                                    .padding(-4)
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(selectedHex == swatch.hex ? 1 : 0)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(swatch.name)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func save() {
        if let editing {
            // 共有の状態は開いている間に変わることがあるので、最新のタグを元にする
            var updated = tagManager.tag(for: editing.id) ?? editing
            updated.name = trimmedName
            updated.colorHex = selectedHex
            tagManager.update(updated)
        } else if let created = tagManager.add(name: trimmedName, colorHex: selectedHex, categoryId: categoryId) {
            onCreated?(created)
        }

        presentationMode.wrappedValue.dismiss()
    }
}
