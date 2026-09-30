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

    @State private var showAddSheet = false
    @State private var editingTag: PlanTag?

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    if tagManager.tags.isEmpty {
                        Text("タグがありません")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    } else {
                        ForEach(tagManager.tags) { tag in
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
                            tagManager.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                } footer: {
                    Text("上から順に、予定一覧の絞り込みに並びます")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.currentTheme.xprimary)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showAddSheet) {
            PlanTagEditorView(editing: nil)
        }
        .sheet(item: $editingTag) { tag in
            PlanTagEditorView(editing: tag)
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

    /// 同じ名前のタグは作れない。2つあると絞り込みの軸として使えなくなる
    private var isDuplicateName: Bool {
        tagManager.tags.contains { $0.name == trimmedName && $0.id != editing?.id }
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
            Text("付いている予定からもこのタグが外れます。予定そのものは消えません。")
        }
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
            var updated = editing
            updated.name = trimmedName
            updated.colorHex = selectedHex
            tagManager.update(updated)
        } else if let created = tagManager.add(name: trimmedName, colorHex: selectedHex) {
            onCreated?(created)
        }

        presentationMode.wrappedValue.dismiss()
    }
}
