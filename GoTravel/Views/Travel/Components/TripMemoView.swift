import SwiftUI

/// 旅行のメモ（3.0 から何枚も書ける）。リストのタブの「メモ」で出す。
///
/// 共有した旅行では、メモごとに「みんなで見る」か「自分だけ」を選べる
/// （ご要望から。`TripMemo`）。1文字ごとには保存せず、編集の画面を閉じたときに保存する
struct TripMemoView: View {
    let plan: TravelPlan

    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var editing: TripMemo?

    private var currentPlan: TravelPlan {
        viewModel.travelPlans.first(where: { $0.id == plan.id }) ?? plan
    }

    /// 新しいものを上に
    private var memos: [TripMemo] {
        currentPlan.memos.sorted { $0.updatedAt > $1.updatedAt }
    }

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
                Label("メモごとに「みんなで見る」か「自分だけ」を選べます", systemImage: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
            }

            Button {
                editing = TripMemo(isPrivate: false, authorId: authVM.userId)
            } label: {
                Label("メモを追加", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(accent)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
            }
            .buttonStyle(.plain)

            if memos.isEmpty {
                Text("旅行のメモを自由に書けます（例：集合場所、駐車場、気をつけること）")
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .padding(.top, 6)
            }

            ForEach(memos) { memo in
                Button {
                    editing = memo
                } label: {
                    memoCard(memo)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $editing) { memo in
            TripMemoEditor(memo: memo, isShared: currentPlan.isShared,
                           isNew: !currentPlan.memos.contains { $0.id == memo.id }) { result in
                apply(result)
            }
        }
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
            if !memo.body.isEmpty {
                Text(memo.body)
                    .font(.system(size: 13))
                    .foregroundColor(textColor.opacity(0.8))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardFill)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(textColor.opacity(0.12), lineWidth: 1))
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
