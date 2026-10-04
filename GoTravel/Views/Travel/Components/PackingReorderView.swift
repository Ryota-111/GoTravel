import SwiftUI

/// 持ち物・お土産・やりたいことの並び替え。
///
/// リストは旅行計画の画面のスクロールの中にあるので、その場でつまんで動かすと
/// スクロールと取り合いになる。並び替えはこの画面にまとめ、右のつまみで上下に動かす
/// （旅程の順や買う順に並べたい、というご要望から）
struct PackingReorderView: View {
    let kind: PackingItem.Kind
    @State var items: [PackingItem]
    let onSave: ([String]) -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { themeManager.currentTheme.actionFill }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isChecked ? themeManager.currentTheme.success
                                                                : themeManager.currentTheme.secondaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                if let note = item.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .onMove { source, destination in
                        items.move(fromOffsets: source, toOffset: destination)
                    }
                } footer: {
                    Text("右のつまみを上下にドラッグして並べ替えます。済んだものは、リストではこれまでどおり下にまとめて表示します。")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("\(kind.title)を並び替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        onSave(items.map(\.id))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accent)
                }
            }
        }
    }
}
