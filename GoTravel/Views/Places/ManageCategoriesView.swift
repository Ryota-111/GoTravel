import SwiftUI

struct ManageCategoriesView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var categoryManager = PlaceCategoryManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var showAddSheet = false

    private var accentColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    var body: some View {
        NavigationView {
            List {
                // デフォルトカテゴリー（削除不可）
                Section("デフォルト") {
                    ForEach(categoryManager.categories.filter { $0.isDefault }) { cat in
                        HStack(spacing: 12) {
                            Image(systemName: cat.icon)
                                .frame(width: 28)
                                .foregroundColor(themeManager.currentTheme.primary)
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

                // カスタムカテゴリー（スワイプ削除可）
                Section("カスタム") {
                    let custom = categoryManager.categories.filter { !$0.isDefault }
                    if custom.isEmpty {
                        Text("カスタムカテゴリーがありません")
                            .font(.subheadline)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    } else {
                        ForEach(custom) { cat in
                            HStack(spacing: 12) {
                                Image(systemName: cat.icon)
                                    .frame(width: 28)
                                    .foregroundColor(themeManager.currentTheme.primary)
                                Text(cat.name)
                                    .foregroundColor(accentColor)
                                Spacer()
                            }
                            .padding(.vertical, 4)
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
            AddCategoryView(categoryManager: categoryManager)
        }
    }
}

struct AddCategoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var categoryManager: PlaceCategoryManager
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var name = ""
    @State private var selectedIcon = "mappin.circle.fill"

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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // タイトル入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カテゴリー名")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(accentColor)
                        TextField("例：カフェ、公園", text: $name)
                            .padding(14)
                            .background(colorScheme == .dark ? themeManager.currentTheme.backgroundDark : themeManager.currentTheme.backgroundLight)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.currentTheme.primary.opacity(0.3), lineWidth: 1.5))
                    }
                    .padding(.horizontal, 20)

                    // アイコン選択グリッド
                    VStack(alignment: .leading, spacing: 10) {
                        Text("アイコンを選択")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 20)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedIcon == icon ? themeManager.currentTheme.primary.opacity(0.2) : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedIcon == icon ? themeManager.currentTheme.primary : themeManager.currentTheme.secondaryText.opacity(0.3), lineWidth: 1.5)
                                            )
                                        Image(systemName: icon)
                                            .font(.title3)
                                            .foregroundColor(selectedIcon == icon ? themeManager.currentTheme.primary : accentColor.opacity(0.7))
                                    }
                                    .frame(height: 52)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("カテゴリーを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        let newCat = CustomPlaceCategory(id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespaces), icon: selectedIcon)
                        categoryManager.add(newCat)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? themeManager.currentTheme.secondaryText : themeManager.currentTheme.primary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
