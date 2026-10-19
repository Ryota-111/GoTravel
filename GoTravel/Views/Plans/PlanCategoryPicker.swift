import SwiftUI

/// 予定を入れるカテゴリ（カレンダー）を選ぶ欄（3.0）。予定の作成と編集で使う。
///
/// カテゴリを変えると、前のカテゴリのタグは外れる（タグはカテゴリごとに持つため）
struct PlanCategoryPicker: View {
    @Binding var categoryId: String?
    @Binding var tagIDs: [String]
    let accentColor: Color

    @ObservedObject private var manager = PlanCategoryManager.shared

    var body: some View {
        // カテゴリを作っていない人には出さない（今までどおり「自分用」に入る）
        if !manager.categories.isEmpty {
            Menu {
                Button {
                    select(nil)
                } label: {
                    if categoryId == nil {
                        Label(PlanCategory.personalName, systemImage: "checkmark")
                    } else {
                        Text(PlanCategory.personalName)
                    }
                }
                ForEach(manager.categories) { category in
                    Button {
                        select(category.id)
                    } label: {
                        let title = category.isShared ? "\(category.name)（共有）" : category.name
                        if categoryId == category.id {
                            Label(title, systemImage: "checkmark")
                        } else {
                            Text(title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(manager.category(for: categoryId)?.color ?? accentColor.opacity(0.4))
                        .frame(width: 10, height: 10)
                    Text(manager.name(for: categoryId))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                    if manager.category(for: categoryId)?.isShared == true {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(accentColor.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).stroke(accentColor.opacity(0.2), lineWidth: 1))
            }
            if let category = manager.category(for: categoryId), category.isShared {
                Text("「\(category.name)」のメンバー全員（\(category.sharedWith.count)人）に表示されます")
                    .font(.caption)
                    .foregroundColor(accentColor.opacity(0.55))
            }
        }
    }

    private func select(_ id: String?) {
        guard id != categoryId else { return }
        categoryId = id
        // タグはカテゴリごと。前のカテゴリのタグは外す
        tagIDs = PlansViewModel.tagIDs(tagIDs, inCategory: id)
    }
}
