import SwiftUI

struct ManageCategoriesView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var categoryManager = PlaceCategoryManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var showAddSheet = false
    @State private var editingCategory: CustomPlaceCategory?

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        NavigationView {
            List {
                // デフォルトカテゴリー（削除・変更不可）
                Section("デフォルト") {
                    ForEach(categoryManager.categories.filter { $0.isDefault }) { cat in
                        HStack(spacing: 12) {
                            categoryChip(cat)

                            Text(cat.name)
                                .foregroundColor(accentColor)

                            Spacer()

                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // カスタムカテゴリー（タップで編集、スワイプで削除）
                Section("カスタム") {
                    let custom = categoryManager.categories.filter { !$0.isDefault }
                    if custom.isEmpty {
                        Text("カスタムカテゴリーがありません")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    } else {
                        ForEach(custom) { cat in
                            Button(action: { editingCategory = cat }) {
                                HStack(spacing: 12) {
                                    categoryChip(cat)

                                    Text(cat.name)
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
                        .onDelete { indexSet in
                            // カスタムのみの配列から削除
                            let customCategories = categoryManager.categories.filter { !$0.isDefault }
                            for i in indexSet {
                                categoryManager.delete(customCategories[i])
                            }
                        }
                    }
                }
            }
            .navigationTitle("カテゴリー管理")
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
        .sheet(isPresented: $showAddSheet) {
            CategoryEditorView(categoryManager: categoryManager, editing: nil)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorView(categoryManager: categoryManager, editing: category)
        }
    }

    /// 一覧でもその色で出す。管理画面で色を選んでも、
    /// ここが灰色のままでは選んだ結果を確かめられない
    private func categoryChip(_ category: CustomPlaceCategory) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(category.color.opacity(colorScheme == .dark ? 0.26 : 0.16))
                .frame(width: 32, height: 32)

            Image(systemName: category.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(category.color)
        }
    }
}

// MARK: - Category Editor

/// 追加と編集で同じ画面を使う。作るときだけ色を選べて、
/// 後から変えられないほうが不便なため
struct CategoryEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var categoryManager: PlaceCategoryManager
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    let editing: CustomPlaceCategory?

    @State private var name = ""
    @State private var selectedIcon = "mappin.circle.fill"
    @State private var selectedHex = PlaceCategoryPalette.swatches[0].hex

    let icons = [
        "house.fill", "fork.knife", "mountain.2.fill", "bed.double.fill",
        "airplane", "train.side.front.car", "car.fill", "ferry.fill",
        "tent.fill", "building.2.fill", "camera.fill", "heart.fill",
        "star.fill", "bag.fill", "cup.and.saucer.fill", "music.note",
        "sportscourt.fill", "leaf.fill", "sun.max.fill", "mappin.circle.fill"
    ]

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var selectedColor: Color {
        Color(hex: selectedHex) ?? .gray
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    preview

                    // カテゴリー名
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カテゴリー名")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(accentColor)

                        TextField("例：カフェ、公園", text: $name)
                            .padding(14)
                            .background(colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedColor.opacity(0.4), lineWidth: 1.5))
                    }
                    .padding(.horizontal, 20)

                    colorSection

                    iconSection
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle(editing == nil ? "カテゴリーを追加" : "カテゴリーを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editing == nil ? "追加" : "保存", action: save)
                        .foregroundColor(trimmedName.isEmpty ? themeManager.currentTheme.secondaryText : selectedColor)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                guard let editing else { return }
                name = editing.name
                selectedIcon = editing.icon
                selectedHex = editing.colorHex ?? PlaceCategoryPalette.fallbackHex(forCategoryId: editing.id)
            }
        }
    }

    /// 選んだ色とアイコンでできあがりを見せる。
    /// 一覧に出るのと同じ形にしておく
    private var preview: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedColor.opacity(colorScheme == .dark ? 0.26 : 0.16))
                    .frame(width: 56, height: 56)

                Image(systemName: selectedIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(selectedColor)
            }

            Text(trimmedName.isEmpty ? "カテゴリー名" : trimmedName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(selectedColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(selectedColor.opacity(colorScheme == .dark ? 0.24 : 0.14), in: RoundedRectangle(cornerRadius: 7))

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
                ForEach(PlaceCategoryPalette.swatches) { swatch in
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

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("アイコン")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(accentColor)
                .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: { selectedIcon = icon }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedIcon == icon ? selectedColor.opacity(0.18) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedIcon == icon ? selectedColor : themeManager.currentTheme.secondaryText.opacity(0.3), lineWidth: 1.5)
                                )
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundColor(selectedIcon == icon ? selectedColor : accentColor.opacity(0.7))
                        }
                        .frame(height: 52)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func save() {
        if let editing {
            var updated = editing
            updated.name = trimmedName
            updated.icon = selectedIcon
            updated.colorHex = selectedHex
            categoryManager.update(updated)
        } else {
            let newCategory = CustomPlaceCategory(
                id: UUID().uuidString,
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedHex
            )
            categoryManager.add(newCategory)
        }

        presentationMode.wrappedValue.dismiss()
    }
}
