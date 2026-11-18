import SwiftUI

/// 持ち物・お土産・やりたいことの並び替え。
///
/// リストは旅行計画の画面のスクロールの中にあるので、その場でつまんで動かすと
/// スクロールと取り合いになる。並び替えはこの画面にまとめ、右のつまみで上下に動かす
/// （旅程の順や買う順に並べたい、というご要望から）
struct PackingReorderView: View {
    let kind: PackingItem.Kind
    /// 共有中の旅行では「みんなの」と「自分の」の欄ごとに並べ替える（3.7）。欄をまたいでは動かさない
    let splitsSections: Bool
    let onSave: ([String]) -> Void

    @State private var shared: [PackingItem]
    @State private var mine: [PackingItem]

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { themeManager.currentTheme.actionFill }

    init(kind: PackingItem.Kind, items: [PackingItem], splitsSections: Bool = false,
         onSave: @escaping ([String]) -> Void) {
        self.kind = kind
        self.splitsSections = splitsSections
        self.onSave = onSave
        if splitsSections {
            _shared = State(initialValue: items.filter(\.isShared))
            _mine = State(initialValue: items.filter { !$0.isShared })
        } else {
            _shared = State(initialValue: [])
            _mine = State(initialValue: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if splitsSections {
                    rows($shared, header: kind.sharedSectionTitle)
                    rows($mine, header: kind.privateSectionTitle)
                } else {
                    rows($mine, header: nil)
                }
                Section {
                } footer: {
                    Text(splitsSections
                         ? "右のつまみを上下にドラッグして並べ替えます。欄を移すときは、リストで項目の「…」から選んでください。済んだものは、リストではこれまでどおり下にまとめて表示します。"
                         : "右のつまみを上下にドラッグして並べ替えます。済んだものは、リストではこれまでどおり下にまとめて表示します。")
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
                        onSave((shared + mine).map(\.id))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(accent)
                }
            }
        }
    }

    @ViewBuilder
    private func rows(_ items: Binding<[PackingItem]>, header: String?) -> some View {
        Section {
            ForEach(items.wrappedValue) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isChecked ? themeManager.currentTheme.success
                                                        : themeManager.currentTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        if let note = item.recipientAndNote {
                            Text(note)
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.secondaryText)
                        }
                    }
                }
            }
            .onMove { source, destination in
                items.wrappedValue.move(fromOffsets: source, toOffset: destination)
            }
        } header: {
            if let header { Text(header) }
        }
    }
}
