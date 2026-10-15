import SwiftUI

/// カレンダーの一覧（題名を押すと出る。3.0）。
///
/// 前は題名のメニューに、切り替え・共有・追加・iPhone のカレンダー・読み込みが全部並んでいて、
/// カテゴリを直すにはいったん切り替えてからもう一度メニューを開く必要があった。
/// 純正のカレンダーの「カレンダー」画面にならい、1つの一覧で切り替え、各行の ⓘ でその場で直せるようにする
struct PlanCategoryListSheet: View {

    /// 閉じてから、見ているカレンダーの画面で行うこと（シートの上にシートを重ねないため）
    enum Action {
        case newCategory
        case newSharedCategory
        case join
        case importICS
    }

    let selection: PlanCategorySelection
    let onSelect: (PlanCategorySelection) -> Void
    let onAction: (Action) -> Void

    @ObservedObject private var manager = PlanCategoryManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing: PlanCategory?

    @Environment(\.colorScheme) private var colorScheme

    /// 行の上で読める差し色（デフォルトカラーのダークモードで黒が行に溶けないように）
    private var accent: Color { themeManager.currentTheme.listTint(for: colorScheme) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(title: "すべて", subtitle: "どのカレンダーの予定も重ねて見る", color: nil,
                        isSelected: selection == .all) { choose(.all) }
                    row(title: PlanCategory.personalName, subtitle: "自分だけの予定。旅行計画と iPhone の予定もここに出ます",
                        color: accent.opacity(0.5), isSelected: selection == .personal) { choose(.personal) }
                    ForEach(manager.categories) { category in
                        row(title: category.name, subtitle: sharingText(category), color: category.color,
                            isShared: category.isShared, isSelected: selection == .category(category.id),
                            onInfo: { editing = category }) {
                            choose(.category(category.id))
                        }
                    }
                    .onMove { manager.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("カレンダー")
                } footer: {
                    if !manager.categories.isEmpty {
                        Text("ⓘ で名前・色・共有・削除ができます。")
                    }
                }

                Section {
                    actionRow("家族・友達と共有するカレンダーを作る", systemImage: "person.2.fill", action: .newSharedCategory)
                    actionRow("共有コードで参加", systemImage: "person.badge.plus", action: .join)
                    actionRow("カレンダーを追加", systemImage: "plus", action: .newCategory)
                }

                Section {
                    NavigationLink {
                        CalendarExportSettingsView()
                    } label: {
                        Label("iPhone のカレンダー", systemImage: "calendar")
                            .foregroundColor(.primary)
                    }
                    actionRow("ファイル（.ics）から読み込む", systemImage: "square.and.arrow.down", action: .importICS)
                } header: {
                    Text("ほかのカレンダー")
                } footer: {
                    Text("iPhone のカレンダーの予定を並べて見たり、Travory の予定を iPhone のカレンダーに入れたりできます。")
                }
            }
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .fontWeight(.semibold)
                }
                if manager.categories.count > 1 {
                    ToolbarItem(placement: .cancellationAction) {
                        EditButton()
                    }
                }
            }
            .sheet(item: $editing) { category in
                PlanCategoryEditorView(editing: category)
                    .environmentObject(authVM)
            }
        }
    }

    // MARK: - 行

    private func row(title: String, subtitle: String?, color: Color?, isShared: Bool = false,
                     isSelected: Bool, onInfo: (() -> Void)? = nil, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    if let color {
                        Circle().fill(color).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.body.weight(isSelected ? .semibold : .regular))
                                .foregroundColor(.primary)
                            if isShared {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(accent)
                            }
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onInfo {
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(accent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("「\(title)」を編集・共有")
            }
        }
        .padding(.vertical, 2)
    }

    private func actionRow(_ title: String, systemImage: String, action: Action) -> some View {
        Button {
            onAction(action)
            dismiss()
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundColor(accent)
        }
    }

    // MARK: - 中身

    private func choose(_ newSelection: PlanCategorySelection) {
        onSelect(newSelection)
        dismiss()
    }

    /// 「共有中・3人」「共有中（参加）・2人」。共有していなければ nil
    private func sharingText(_ category: PlanCategory) -> String? {
        guard category.isShared else { return nil }
        let count = max(category.sharedWith.count, 1)
        let role = authVM.userId.map { category.isOwner(userId: $0) } == true ? "共有中" : "参加中"
        return "\(role)・\(count)人"
    }
}
