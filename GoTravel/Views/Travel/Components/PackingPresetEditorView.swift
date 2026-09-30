import SwiftUI

/// 「よく使う持ち物」などの候補を編集する。
///
/// 候補はコードに直書きされた固定リストだった。要る物は人によって違うので、
/// 足す・消す・並べ替えができるようにした。
/// ここで整えた候補は、ユーザーに紐づいて**全部の旅行で使い回される。**
struct PackingPresetEditorView: View {
    let kind: PackingItem.Kind

    @ObservedObject private var manager = PackingPresetManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @FocusState private var isInputFocused: Bool

    private var theme: ThemePreset { themeManager.currentTheme }
    private var accent: Color { theme.actionFill }

    private var presets: [PackingPresetManager.Preset] {
        manager.presets(for: kind)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        TextField("候補を追加", text: $newName)
                            .focused($isInputFocused)
                            .submitLabel(.done)
                            // 続けて足すことが多いので、確定してそのまま次を打てるようにする
                            .onSubmit(add)

                        Button(action: add) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(trimmedNewName.isEmpty
                                                 ? theme.secondaryText.opacity(0.4)
                                                 : ThemePreset.readableTint(accent, on: theme.backgroundLight))
                        }
                        .disabled(trimmedNewName.isEmpty)
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    ForEach(presets) { preset in
                        Text(preset.name)
                            .foregroundColor(theme.text)
                    }
                    .onDelete(perform: delete)
                    .onMove { manager.move(kind: kind, from: $0, to: $1) }
                } header: {
                    Text("よく使う\(kind.title)")
                } footer: {
                    if presets.isEmpty {
                        Text("候補がありません。よく持っていくものを足しておくと、次の旅行から一覧に出ます。")
                    } else {
                        Text("並べ替えは長押しで。ここで整えた候補は、すべての旅行で使えます。")
                    }
                }

                if presets.isEmpty {
                    Section {
                        Button("もとの候補に戻す") {
                            manager.restoreDefaults(for: kind)
                        }
                        .foregroundColor(ThemePreset.readableTint(accent, on: theme.backgroundLight))
                    }
                }
            }
            .navigationTitle("候補を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(theme.secondaryText)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                        .foregroundColor(ThemePreset.readableTint(accent, on: theme.backgroundLight))
                }
            }
        }
    }

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        guard !trimmedNewName.isEmpty else { return }
        manager.add(name: trimmedNewName, kind: kind)
        newName = ""
        isInputFocused = true
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            manager.delete(presets[index])
        }
    }
}
