import SwiftUI
import UniformTypeIdentifiers

/// 旅行のメモ（3.0 から何枚も書ける）。リストのタブの「メモ」で出す。
///
/// 共有した旅行では、メモごとに「みんなで見る」か「自分だけ」を選べる
/// （ご要望から。`TripMemo`）。1文字ごとには保存せず、編集の画面を閉じたときに保存する。
/// 3.7 から、直しても並びは変わらず、「並び替え」を押すとその場でカードをつまんで動かせる（`orderedMemos`）
struct TripMemoView: View {
    let plan: TravelPlan

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var editing: TripMemo?
    /// 並び替えのあいだの並び。nil なら並び替えていない。「完了」で保存する
    @State private var reordering: [TripMemo]?
    /// つまんで動かしているメモ
    @State private var draggingId: String?

    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    /// 並べた順（新しく足したものは上）。直しても動かない
    private var memos: [TripMemo] { currentPlan.orderedMemos }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }
    private var accent: Color { themeManager.currentTheme.actionFill }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if currentPlan.isShared {
                Label("「みんなのメモ」は同行者も見て書けます。「自分だけのメモ」は自分だけに見えます", systemImage: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 共有中の旅行では、新しいメモは「自分だけ」から（3.7）。書く画面で「みんなで見る」に替えられる。
            // 共有していない旅行では 3.6 までと同じ（しおりは「みんな」のメモだけを載せるため）
            Button {
                editing = TripMemo(isPrivate: currentPlan.isShared, authorId: authVM.userId)
            } label: {
                Label("メモを追加", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(accent)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .strokeBorder(accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
            }
            .buttonStyle(.plain)

            if memos.count >= 2 || reordering != nil {
                reorderBar
            }

            if memos.isEmpty {
                Text("旅行のメモを自由に書けます（例：集合場所、駐車場、気をつけること）")
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.top, 6)
            }

            if currentPlan.isShared && !memos.isEmpty {
                // 共有中の旅行では「みんなの」と「自分だけの」の2つの欄に分ける（3.7）
                memoSection(isPrivate: false)
                memoSection(isPrivate: true)
            } else {
                memoCards(reordering ?? memos)
            }
        }
        // カードの間やまわりで指を離したときも、つまんだ印を消す
        .onDrop(of: [.text], isTargeted: nil) { _ in
            draggingId = nil
            return reordering != nil
        }
        .sheet(item: $editing) { memo in
            TripMemoEditor(memo: memo, isShared: currentPlan.isShared,
                           isNew: !currentPlan.memos.contains { $0.id == memo.id }) { result in
                apply(result)
            }
        }
    }

    // MARK: - 欄

    @ViewBuilder
    private func memoCards(_ list: [TripMemo]) -> some View {
        if reordering != nil {
            ForEach(list) { memo in
                reorderCard(memo)
            }
        } else {
            ForEach(list) { memo in
                Button {
                    editing = memo
                } label: {
                    memoCard(memo)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memoSection(isPrivate: Bool) -> some View {
        let list = (reordering ?? memos).filter { $0.isPrivate == isPrivate }
        let title = isPrivate ? "自分だけのメモ" : "みんなのメモ"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: isPrivate ? "lock.fill" : "person.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isPrivate ? themeManager.currentTheme.secondaryText : accent)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.adaptiveText(for: colorScheme))
                Spacer(minLength: 0)
                if reordering == nil {
                    Button {
                        editing = TripMemo(isPrivate: isPrivate, authorId: authVM.userId)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 17))
                            .foregroundColor(accent)
                            .frame(width: 30, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(title)を足す"))
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)

            if list.isEmpty {
                Text(isPrivate
                     ? "まだありません。メモを書く画面で「自分だけ」を選ぶと、ここに入ります"
                     : "まだありません。メモを書く画面で「みんなで見る」を選ぶと、ここに入ります")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            } else {
                memoCards(list)
            }
        }
    }

    // MARK: - その場で並び替え

    private var reorderBar: some View {
        HStack {
            if reordering != nil {
                Text("カードをつまんで上下に動かします")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                Spacer()
                Button("キャンセル") {
                    withAnimation(.easeInOut(duration: 0.2)) { reordering = nil }
                    draggingId = nil
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)
                Button("完了") {
                    if let reordering { saveOrder(reordering.map(\.id)) }
                    withAnimation(.easeInOut(duration: 0.2)) { reordering = nil }
                    draggingId = nil
                }
                .font(.caption.weight(.bold))
                .foregroundColor(accent)
                .padding(.leading, 8)
            } else {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { reordering = memos }
                } label: {
                    Label("並び替え", systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accent)
                }
            }
        }
    }

    /// 並び替えのあいだのカード。題名だけの小さな形にして、つまみを出す。
    /// 旅行計画の画面のスクロールと取り合わないよう、長押ししてからつまむ（ドラッグ＆ドロップ）
    private func reorderCard(_ memo: TripMemo) -> some View {
        HStack(spacing: 10) {
            Text(memo.displayTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            if currentPlan.isShared {
                Image(systemName: memo.isPrivate ? "lock.fill" : "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.currentTheme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(cardFill)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(draggingId == memo.id ? accent : textColor.opacity(0.12),
                            lineWidth: draggingId == memo.id ? 2 : 1))
        )
        .opacity(draggingId == memo.id ? 0.5 : 1)
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: AppRadius.large))
        .onDrag {
            draggingId = memo.id
            return NSItemProvider(object: memo.id as NSString)
        }
        .onDrop(of: [.text], delegate: MemoReorderDropDelegate(targetId: memo.id,
                                                              items: $reordering,
                                                              draggingId: $draggingId))
        .accessibilityElement(children: .combine)
        .accessibilityHint("上下に動かすには、アクションを使います")
        .accessibilityAction(named: "上へ移動") { move(memo.id, by: -1) }
        .accessibilityAction(named: "下へ移動") { move(memo.id, by: 1) }
    }

    /// VoiceOver のための1つずつの移動
    private func move(_ id: String, by offset: Int) {
        guard var list = reordering, let from = list.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard list.indices.contains(to) else { return }
        list.swapAt(from, to)
        reordering = list
    }

    private func saveOrder(_ orderedIds: [String]) {
        guard let userId = authVM.userId else { return }
        var updated = currentPlan
        updated.reorderMemos(displayedIds: orderedIds)
        guard updated.memos.map(\.id) != currentPlan.memos.map(\.id) else { return }
        viewModel.update(updated, userId: userId)
    }

    private func memoCard(_ memo: TripMemo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(memo.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                Spacer()
                if currentPlan.isShared {
                    Image(systemName: memo.isPrivate ? "lock.fill" : "person.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .accessibilityLabel(memo.isPrivate ? "自分だけ" : "みんなで見る")
                }
            }
            if !memo.bodyBelowTitle.isEmpty {
                Text(memo.bodyBelowTitle)
                    .font(.system(size: 13))
                    .foregroundColor(textColor.opacity(0.8))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(cardFill)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large).stroke(textColor.opacity(0.12), lineWidth: 1))
        )
    }

    private func apply(_ result: TripMemoEditor.Result) {
        guard let userId = authVM.userId else { return }
        var updated = currentPlan
        switch result {
        case .save(let memo):
            if let index = updated.memos.firstIndex(where: { $0.id == memo.id }) {
                guard updated.memos[index] != memo else { return }
                updated.memos[index] = memo
            } else {
                guard !memo.isEmpty else { return }
                updated.memos.append(memo)
            }
        case .delete(let id):
            updated.memos.removeAll { $0.id == id }
        }
        viewModel.update(updated, userId: userId)
    }
}

/// つまんだカードがほかのカードの上に来たら、その場で入れ替える
private struct MemoReorderDropDelegate: DropDelegate {
    let targetId: String
    @Binding var items: [TripMemo]?
    @Binding var draggingId: String?

    func dropEntered(info: DropInfo) {
        guard let draggingId, draggingId != targetId, var list = items,
              let from = list.firstIndex(where: { $0.id == draggingId }),
              let to = list.firstIndex(where: { $0.id == targetId }),
              // 「みんなの」と「自分だけの」の欄をまたいでは動かさない（欄は書く画面で替える）
              list[from].isPrivate == list[to].isPrivate else { return }
        list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        withAnimation(.easeInOut(duration: 0.2)) { items = list }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }
}

/// メモを書く画面
struct TripMemoEditor: View {
    enum Result {
        case save(TripMemo)
        case delete(String)
    }

    let isShared: Bool
    let isNew: Bool
    let onFinish: (Result) -> Void

    @State private var memo: TripMemo
    /// 開いたときの中身。変えていなければ保存しない（共有にも送らない）
    private let original: TripMemo
    @State private var showsDeleteConfirm = false
    @State private var didDelete = false
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    init(memo: TripMemo, isShared: Bool, isNew: Bool, onFinish: @escaping (Result) -> Void) {
        _memo = State(initialValue: memo)
        self.original = memo
        self.isShared = isShared
        self.isNew = isNew
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("題名（なくても大丈夫です）", text: $memo.title)
                }
                Section {
                    TextEditor(text: $memo.body)
                        .frame(minHeight: 240)
                }
                if isShared {
                    Section {
                        Picker("見る人", selection: $memo.isPrivate) {
                            Text("みんなで見る").tag(false)
                            Text("自分だけ").tag(true)
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        Text(memo.isPrivate
                             ? "このメモは、共有している人には見えません。"
                             : "このメモは、共有している全員が見て書けます。")
                    }
                }
                if !isNew {
                    Section {
                        Button("このメモを削除", role: .destructive) { showsDeleteConfirm = true }
                    }
                }
            }
            .tint(themeManager.currentTheme.actionFill)
            .navigationTitle(isNew ? "新しいメモ" : "メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { finish() }
                        .fontWeight(.semibold)
                }
                if isNew {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            didDelete = true   // 何も保存しない
                            dismiss()
                        }
                    }
                }
            }
            .confirmationDialog("このメモを削除しますか？", isPresented: $showsDeleteConfirm, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    didDelete = true
                    onFinish(.delete(memo.id))
                    dismiss()
                }
            }
            // 下に引いて閉じたときも、書いた分は保存する
            .onDisappear {
                if !didDelete { save() }
            }
        }
    }

    private func finish() {
        save()
        didDelete = true   // onDisappear で2回保存しない
        dismiss()
    }

    private func save() {
        guard memo.title != original.title || memo.body != original.body || memo.isPrivate != original.isPrivate else { return }
        var result = memo
        result.updatedAt = Date()
        onFinish(.save(result))
    }
}
