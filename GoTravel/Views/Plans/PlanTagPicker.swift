import SwiftUI

/// タグを選ぶ欄。予定の作成（`AddPlanView`）と編集（`PlanDetailView`）で同じものを使う。
///
/// **既にあるタグから選ぶのが主で、作るのは例外**という並びにしてある。
/// 分類の本命にした以上、思いつくまま打てる欄を前に出すと
/// 「仕事」と「しごと」が並んで、絞り込みの軸として使えなくなる
struct PlanTagPicker: View {
    @Binding var selectedIDs: [String]
    /// 画面ごとに文字色が違うので外から受け取る
    let accentColor: Color

    @ObservedObject var tagManager = PlanTagManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var showNewTagEditor = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tagManager.tags.isEmpty {
                starterSuggestions
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(tagManager.tags) { tag in
                        tagChip(tag)
                    }

                    newTagChip
                }
            }
        }
        .sheet(isPresented: $showNewTagEditor) {
            PlanTagEditorView(editing: nil) { created in
                // 作った直後は付けたいはずなので、そのまま選択に入れる
                if !selectedIDs.contains(created.id) {
                    selectedIDs.append(created.id)
                }
            }
        }
    }

    // MARK: - Chips

    private func tagChip(_ tag: PlanTag) -> some View {
        let isSelected = selectedIDs.contains(tag.id)
        // 選んだタグは塗る。塗りは白文字が読める濃さまで落とす
        let fill = ThemePreset.readableTint(tag.color, on: .white)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedIDs.removeAll { $0 == tag.id }
                } else {
                    selectedIDs.append(tag.id)
                }
            }
        } label: {
            Text(tag.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : tag.color)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? AnyShapeStyle(fill)
                        : AnyShapeStyle(tag.color.opacity(colorScheme == .dark ? 0.22 : 0.12)),
                    in: Capsule()
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var newTagChip: some View {
        Button { showNewTagEditor = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                Text("新しいタグ")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(accentColor.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().strokeBorder(
                    accentColor.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// タグが1つも無いとき。空の選択欄だけ出しても何を入れる場所か伝わらないので、
    /// 押せばそのままタグになる候補を並べる
    private var starterSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("予定を仕分ける名前をつけます。一覧はこのタグで絞り込めます")
                .font(.system(size: 12))
                .foregroundColor(accentColor.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(PlanTag.starterSuggestions, id: \.self) { name in
                    Button {
                        guard let created = tagManager.add(name: name) else { return }
                        selectedIDs.append(created.id)
                    } label: {
                        Text("＋ \(name)")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(accentColor.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                newTagChip
            }
        }
    }
}
