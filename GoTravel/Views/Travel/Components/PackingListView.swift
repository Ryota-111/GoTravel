import SwiftUI

// MARK: - Packing List View
struct PackingListView: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject private var presetManager = PackingPresetManager.shared
    let plan: TravelPlan
    /// 持ち物・お土産・やりたいことのどれを出すか。
    /// 3つとも形が同じなので、この1つの画面を使い回す
    var kind: PackingItem.Kind = .packing

    @State private var newItemName: String = ""
    /// お土産の「誰に」。使わない種類では欄ごと出さない
    @State private var newItemNote: String = ""
    /// 「よく使う持ち物」で選択中のもの。まとめて追加するまで保持する
    @State private var selectedPresets: Set<String> = []
    @State private var showPresetEditor = false
    @State private var showImport = false
    @FocusState private var isInputFocused: Bool

    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == plan.id })
    }

    /// この種類で、かつ自分に見えてよいものだけ。
    /// 3つのリストは1つの配列に混ざって入っている
    private var items: [PackingItem] {
        (currentPlan?.packingItems ?? [])
            .filter { $0.kind == kind && $0.isVisible(to: authVM.userId) }
    }

    /// 新しく足す項目の持ち主。
    /// やりたいことは「みんなのもの」にしたいので持ち主を付けない
    private var newItemOwnerId: String? {
        kind.isSharedWithMembers ? nil : authVM.userId
    }

    private var presets: [String] {
        presetManager.names(for: kind)
    }

    /// 済んだものは下へ送る。まだ入れていないものを上に集めて見やすくする
    private var sortedItems: [PackingItem] {
        items.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isChecked != rhs.element.isChecked {
                    return !lhs.element.isChecked
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private var checkedCount: Int {
        items.filter(\.isChecked).count
    }

    private var accent: Color { themeManager.currentTheme.actionFill }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }

    /// カードの縁。白黒テーマは背景(0.96)とカード(0.95)がほぼ同じ明るさで
    /// 塗りだけだと境界が見えないため、どのテーマでも薄い枠を必ず引く
    private var cardStroke: Color { textColor.opacity(0.12) }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 14) {
            // 共有中の旅行でだけ、このリストが同行者に見えるのかを書いておく。
            // お土産に同行者へのぶんを書く人がいるので、黙っていてはいけない
            if currentPlan?.isShared == true {
                sharingBadge
            }

            if !items.isEmpty {
                progressHeader
            }

            addItemSection

            if items.isEmpty {
                emptyStateView
            } else {
                itemsList

                // 候補は空のときだけ出していたが、それだと
                // 1件でも足した瞬間に候補へ戻れなくなる
                presetSection
            }
        }
        .sheet(isPresented: $showPresetEditor) {
            PackingPresetEditorView(kind: kind)
        }
        .sheet(isPresented: $showImport) {
            PackingImportView(kind: kind,
                              currentPlan: currentPlan ?? plan,
                              onImport: importItems)
                .environmentObject(viewModel)
                .environmentObject(authVM)
        }
    }

    // MARK: - 共有の状態

    private var sharingBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: kind.isSharedWithMembers ? "person.2.fill" : "lock.fill")
                .font(.system(size: 11, weight: .semibold))

            Text(kind.sharingNote)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .foregroundColor(themeManager.currentTheme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeManager.currentTheme.secondaryText.opacity(0.08))
        )
    }

    // MARK: - 進捗

    /// 何個中いくつ入れ終えたかは、出発前に一番知りたい情報
    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(checkedCount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(checkedCount == items.count ? themeManager.currentTheme.success : accent)
                Text("/ \(items.count)")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)

                Spacer()

                if checkedCount == items.count {
                    Label(kind.doneLabel, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.success)
                }
            }

            ProgressView(value: Double(checkedCount), total: Double(max(items.count, 1)))
                .tint(checkedCount == items.count ? themeManager.currentTheme.success : accent)
        }
    }

    // MARK: - 追加

    private var addItemSection: some View {
        VStack(spacing: 8) {
            addNameRow

            // お土産だけ「誰に」を書ける。買う前に決めておくと店で迷わない
            if kind.usesNote {
                TextField(kind.notePlaceholder, text: $newItemNote)
                    .font(.system(size: 13))
                    .submitLabel(.done)
                    .onSubmit(addItem)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardFill)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(cardStroke, lineWidth: 1))
                    )
            }
        }
    }

    private var addNameRow: some View {
        HStack(spacing: 10) {
            TextField(kind.addPlaceholder, text: $newItemName)
                .font(.system(size: 15))
                .focused($isInputFocused)
                .submitLabel(.done)
                // 続けて入力することが多いので、確定で追加してそのまま次を打てるようにする
                .onSubmit(addItem)
                .foregroundColor(textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardFill)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(cardStroke, lineWidth: 1))
                )

            Button(action: addItem) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ThemePreset.readableText(on: accent))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(accent))
            }
            .disabled(trimmedNewItemName.isEmpty)
            .opacity(trimmedNewItemName.isEmpty ? 0.4 : 1)
        }
    }

    private var trimmedNewItemName: String {
        newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 一覧

    private var itemsList: some View {
        VStack(spacing: 8) {
            ForEach(sortedItems) { item in
                PackingItemRow(item: item, planId: plan.id ?? "")
                    .environmentObject(viewModel)
                    .environmentObject(authVM)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: sortedItems.map(\.isChecked))
    }

    // MARK: - 空のとき

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: kind.emptyIcon)
                .font(.system(size: 34))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))

            Text(kind.emptyMessage)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            presetSection
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardFill)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardStroke, lineWidth: 1))
        )
    }

    // MARK: - よく使う持ち物

    /// 最初の1件を入力する手間が一番の障壁なので、よく使うものから足せるようにする。
    ///
    /// 1つ押すたびに追加していた頃は、押した時点でリストが空でなくなり
    /// 候補ごと消えてしまって続けて選べなかった。
    /// まとめて選んでから確定する形にしている
    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("よく使う\(kind.title)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)

                Spacer()

                // 毎回だいたい同じものを持っていく人には、候補を1つずつ選ぶより
                // 前の旅行を指すほうが早い
                Button("前の旅行から") { showImport = true }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(ThemePreset.readableTint(accent, on: cardFill))

                // 人によって要る物は違う。候補そのものを組み替えられるようにする
                Button("編集") { showPresetEditor = true }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(ThemePreset.readableTint(accent, on: cardFill))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FlowChips(items: presets, selected: selectedPresets) { preset in
                if selectedPresets.contains(preset) {
                    selectedPresets.remove(preset)
                } else {
                    selectedPresets.insert(preset)
                }
            }

            Button(action: addSelectedPresets) {
                Text(selectedPresets.isEmpty ? "追加するものを選んでください" : "\(selectedPresets.count)件を追加")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(selectedPresets.isEmpty
                                     ? themeManager.currentTheme.secondaryText
                                     : ThemePreset.readableText(on: accent))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedPresets.isEmpty ? accent.opacity(0.10) : accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(selectedPresets.isEmpty)
            .animation(.easeInOut(duration: 0.15), value: selectedPresets.isEmpty)
        }
        .padding(.top, 4)
    }

    /// 選んだものをまとめて追加する。
    /// 1件ずつ保存すると、そのたびに CloudKit へ書き込みが走る
    private func addSelectedPresets() {
        guard !selectedPresets.isEmpty,
              let userId = authVM.userId,
              var updatedPlan = currentPlan ?? Optional(plan) else { return }

        // Set は順番を持たないので、候補に並んでいる順で足す
        for name in presets where selectedPresets.contains(name) {
            updatedPlan.packingItems.append(
                PackingItem(name: name, kind: kind, ownerId: newItemOwnerId)
            )
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.update(updatedPlan, userId: userId)
            selectedPresets.removeAll()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - 前の旅行から取り込む

    /// 前の旅行の項目を、いまの旅行に足す。
    ///
    /// - **チェックは外す。** 前回入れ終えたことは、今回の準備には関係ない
    /// - **同じ名前は重ねない。** すでに「充電器」があるところに
    ///   もう1つ増えても困るだけ
    /// - **持ち主は自分にする。** 前の旅行で共有だった項目でも、
    ///   持ち物とお土産は各自のものという扱いに揃える
    private func importItems(_ incoming: [PackingItem]) {
        guard let userId = authVM.userId,
              var updatedPlan = currentPlan ?? Optional(plan) else { return }

        let existingNames = Set(items.map(\.name))
        var added = 0

        for item in incoming where !existingNames.contains(item.name) {
            updatedPlan.packingItems.append(
                PackingItem(name: item.name,
                            isChecked: false,
                            kind: kind,
                            note: item.note,
                            ownerId: newItemOwnerId)
            )
            added += 1
        }

        guard added > 0 else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.update(updatedPlan, userId: userId)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Actions

    private func addItem() {
        add(name: trimmedNewItemName)
        newItemName = ""
        newItemNote = ""
    }

    private func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var updatedPlan = currentPlan ?? Optional(plan) else { return }

        let note = newItemNote.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPlan.packingItems.append(
            PackingItem(name: trimmed,
                        kind: kind,
                        note: note.isEmpty ? nil : note,
                        ownerId: newItemOwnerId)
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let userId = authVM.userId {
                viewModel.update(updatedPlan, userId: userId)
            }
        }
    }
}

// MARK: - チップの折り返し

/// 幅に応じて折り返す横並び。プリセットの数だけ行が伸びる
private struct FlowChips: View {
    let items: [String]
    let selected: Set<String>
    let onTap: (String) -> Void

    @ObservedObject var themeManager = ThemeManager.shared

    private var accent: Color { themeManager.currentTheme.actionFill }

    var body: some View {
        // 3列に固定すると文字数で崩れるため、可変幅のグリッドで折り返す
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selected.contains(item)
                Button {
                    onTap(item)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: isSelected ? "checkmark" : "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text(item)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(isSelected ? ThemePreset.readableText(on: accent) : accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(isSelected ? accent : accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

// MARK: - Packing Item Row
struct PackingItemRow: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    let item: PackingItem
    let planId: String

    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == planId })
    }

    private var accent: Color { themeManager.currentTheme.actionFill }

    private var cardFill: Color {
        colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.secondaryBackgroundLight
    }

    private var textColor: Color { ThemePreset.readableText(on: cardFill) }

    /// 白黒テーマは背景とカードの明るさがほぼ同じなので、必ず縁を引く
    private var cardStroke: Color { textColor.opacity(0.12) }

    // MARK: - Body
    var body: some View {
        // 行全体を押せるようにする。丸だけを狙わせると小さくて押しにくい
        HStack(spacing: 12) {
            checkmark

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15))
                    .foregroundColor(item.isChecked ? themeManager.currentTheme.secondaryText : textColor)
                    .strikethrough(item.isChecked, color: themeManager.currentTheme.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // お土産の「誰に」。入っているときだけ出す
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // 長押しの contextMenu だけだと削除に気づけないので常に出す。
            // チェックの丸は左端なので、右端なら間違って押しにくい
            Button(action: deleteItem) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(item.name)を削除"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.isChecked ? themeManager.currentTheme.success.opacity(0.35) : cardStroke, lineWidth: 1)
                )
        )
        .opacity(item.isChecked ? 0.6 : 1)
        // **Button にしないこと。**
        // Button はタブを切り替える横スワイプでもチェックが入ってしまう。
        // 縦スクロールは ScrollView がジェスチャを奪うので反応しないが、
        // 横方向は奪う相手がいないため、指を離した時点で action が走るため。
        // onTapGesture は指が動くと成立しないので、そのまま使える。
        //
        // 自前の DragGesture で移動量を見る方法は、simultaneousGesture にしても
        // 外側の ScrollView から縦スクロールを奪ってしまうので使えない
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleCheck)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item.isChecked ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "切り替える", toggleCheck)
        .contextMenu {
            Button("削除", role: .destructive, action: deleteItem)
        }
    }

    private var checkmark: some View {
        ZStack {
            Circle()
                .fill(item.isChecked ? themeManager.currentTheme.success : Color.clear)
                .frame(width: 24, height: 24)

            Circle()
                .stroke(item.isChecked ? themeManager.currentTheme.success : themeManager.currentTheme.secondaryText.opacity(0.4),
                        lineWidth: 2)
                .frame(width: 24, height: 24)

            if item.isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(ThemePreset.readableText(on: themeManager.currentTheme.success))
            }
        }
    }

    // MARK: - Actions
    private func toggleCheck() {
        guard var updatedPlan = currentPlan else { return }

        if let index = updatedPlan.packingItems.firstIndex(where: { $0.id == item.id }) {
            updatedPlan.packingItems[index].isChecked.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if let userId = authVM.userId {
                    viewModel.update(updatedPlan, userId: userId)
                }
            }
        }
    }

    private func deleteItem() {
        guard var updatedPlan = currentPlan else { return }

        updatedPlan.packingItems.removeAll(where: { $0.id == item.id })

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let userId = authVM.userId {
                viewModel.update(updatedPlan, userId: userId)
            }
        }
    }
}
