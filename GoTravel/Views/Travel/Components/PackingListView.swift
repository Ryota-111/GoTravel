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
    /// お土産のメモ。使わない種類では欄ごと出さない
    @State private var newItemNote: String = ""
    /// お土産を渡す相手（3.5）。続けて同じ人のぶんを足すことが多いので、足したあとも残す
    @State private var newItemRecipient: String = ""
    /// 閉じている相手（`SouvenirGroup.id`）
    @State private var collapsedRecipients: Set<String> = []
    /// ドラッグしたお土産を、いま重ねている相手（`SouvenirGroup.id`）
    @State private var dropTargetRecipient: String?
    /// お土産を「自分だけ」で足すか（共有中の旅行でだけ選べる。はじめは「みんな」）
    @State private var newItemIsPrivate = false
    /// 「よく使う持ち物」で選択中のもの。まとめて追加するまで保持する
    @State private var selectedPresets: Set<String> = []
    @State private var showPresetEditor = false
    @State private var showImport = false
    @State private var showReorder = false
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
    /// やりたいことは「みんなのもの」にしたいので持ち主を付けない。
    /// お土産は「みんな」から始まり、共有中の旅行で「自分だけ」を選んだときだけ持ち主を付ける
    private var newItemOwnerId: String? {
        if kind.choosesVisibilityPerItem {
            return currentPlan?.isShared == true && newItemIsPrivate ? authVM.userId : nil
        }
        return kind.isSharedWithMembers ? nil : authVM.userId
    }

    /// よく使うものから足すときの渡す相手。相手の欄に書いてあればその人のぶんにする
    private var presetRecipient: String? {
        guard kind.usesRecipient else { return nil }
        let trimmed = newItemRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
                if items.count >= 2 {
                    reorderButton
                }
                itemsList

                // 候補は空のときだけ出していたが、それだと
                // 1件でも足した瞬間に候補へ戻れなくなる
                presetSection
            }
        }
        .sheet(isPresented: $showPresetEditor) {
            PackingPresetEditorView(kind: kind)
        }
        .sheet(isPresented: $showReorder) {
            // 見えている順（済んだものは下）から並べ替え始める
            PackingReorderView(kind: kind, items: sortedItems) { orderedIds in
                saveOrder(orderedIds)
            }
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
            Image(systemName: kind.isSharedWithMembers || kind.choosesVisibilityPerItem ? "person.2.fill" : "lock.fill")
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
            RoundedRectangle(cornerRadius: AppRadius.medium)
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
                    // 数が入れ替わるのではなく、めくれて変わる
                    .contentTransition(.numericText(value: Double(checkedCount)))
                Text("/ \(items.count)")
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.secondaryText)

                Spacer()

                if checkedCount == items.count {
                    Label(kind.doneLabel, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(themeManager.currentTheme.success)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }

            ProgressView(value: Double(checkedCount), total: Double(max(items.count, 1)))
                .tint(checkedCount == items.count ? themeManager.currentTheme.success : accent)
        }
        .animation(.snappy, value: checkedCount)
        // 全部そろった瞬間だけ、手に伝える
        .sensoryFeedback(trigger: checkedCount == items.count) { _, isDone in isDone && !items.isEmpty ? .success : nil }
    }

    // MARK: - 追加

    private var addItemSection: some View {
        VStack(spacing: 8) {
            addNameRow

            // お土産は渡す相手を書ける（3.5）。相手ごとにまとめて出す
            if kind.usesRecipient {
                recipientField
            }

            // お土産だけメモを書ける
            if kind.usesNote {
                TextField(kind.notePlaceholder, text: $newItemNote)
                    .font(.system(size: 13))
                    .submitLabel(.done)
                    .onSubmit(addItem)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(cardFill)
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(cardStroke, lineWidth: 1))
                    )
            }

            // 共有中の旅行のお土産は、足す前に「みんな」か「自分だけ」かを選べる
            if kind.choosesVisibilityPerItem && currentPlan?.isShared == true {
                Picker("見る人", selection: $newItemIsPrivate) {
                    Label("みんな", systemImage: "person.2.fill").tag(false)
                    Label("自分だけ", systemImage: "lock.fill").tag(true)
                }
                .pickerStyle(.segmented)
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
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(cardFill)
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(cardStroke, lineWidth: 1))
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

    /// 渡す相手の欄と、これまでに書いた相手の候補
    private var recipientField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                TextField("渡す相手（例: お母さん・会社）", text: $newItemRecipient)
                    .font(.system(size: 13))
                    .submitLabel(.done)
                    .onSubmit(addItem)
                    .foregroundColor(textColor)
                if !newItemRecipient.isEmpty {
                    Button {
                        newItemRecipient = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("渡す相手を消す")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(cardFill)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.medium).stroke(cardStroke, lineWidth: 1))
            )

            // 書いたことのある相手を選べるようにする（同じ人の名前を毎回打たなくて済む）
            let recipients = SouvenirGrouping.suggestedRecipients(items)
            if !recipients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipients, id: \.self) { name in
                            let isSelected = newItemRecipient.trimmingCharacters(in: .whitespaces) == name
                            Button {
                                newItemRecipient = isSelected ? "" : name
                            } label: {
                                Text(name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(isSelected ? ThemePreset.readableText(on: accent) : accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(isSelected ? accent : accent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
                .clipped()
            }
        }
    }

    private var trimmedNewItemName: String {
        newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 並び替え

    private var reorderButton: some View {
        HStack {
            Spacer()
            Button {
                showReorder = true
            } label: {
                Label("並び替え", systemImage: "arrow.up.arrow.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accent)
            }
        }
    }

    private func saveOrder(_ orderedIds: [String]) {
        guard let userId = authVM.userId,
              var updatedPlan = currentPlan ?? Optional(plan) else { return }
        updatedPlan.reorderPackingItems(orderedIds: orderedIds)
        viewModel.update(updatedPlan, userId: userId)
    }

    // MARK: - 一覧

    @ViewBuilder
    private var itemsList: some View {
        if kind.usesRecipient && SouvenirGrouping.usesGroups(items) {
            groupedList
        } else {
            flatList
        }
    }

    /// 渡す相手ごとにまとめた一覧（3.5）。相手の行を押すと開け閉めできる。
    /// お土産を長押しして、ほかの相手のまとまり（閉じていても見出しでよい）へドラッグすると移せる
    private var groupedList: some View {
        VStack(spacing: 10) {
            ForEach(SouvenirGrouping.groups(items)) { group in
                VStack(spacing: 8) {
                    groupHeader(group)
                    if !collapsedRecipients.contains(group.id) {
                        ForEach(group.items) { item in
                            PackingItemRow(item: item, planId: plan.id ?? "")
                                .environmentObject(viewModel)
                                .environmentObject(authVM)
                                .padding(.leading, 14)
                                .draggable(item.id) {
                                    Text(item.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(cardFill))
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .fill(dropTargetRecipient == group.id ? accent.opacity(0.10) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.large)
                                .stroke(dropTargetRecipient == group.id ? accent.opacity(0.6) : Color.clear,
                                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        )
                )
                .dropDestination(for: String.self) { ids, _ in
                    dropTargetRecipient = nil
                    return moveSouvenirs(ids, to: group.recipient)
                } isTargeted: { targeted in
                    if targeted {
                        dropTargetRecipient = group.id
                    } else if dropTargetRecipient == group.id {
                        dropTargetRecipient = nil
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items.map(\.isChecked))
    }

    /// ドラッグで落としたお土産を、その相手へ移す。この旅行のお土産でなければ何もしない
    private func moveSouvenirs(_ ids: [String], to recipient: String?) -> Bool {
        let known = Set(items.map(\.id))
        let moving = ids.filter { known.contains($0) }
        guard !moving.isEmpty, let userId = authVM.userId,
              var updatedPlan = currentPlan ?? Optional(plan) else { return false }
        // もうその相手のものだけなら何もしない
        let alreadyThere = items.filter { moving.contains($0.id) }
            .allSatisfy { SouvenirGrouping.recipient(of: $0) == recipient }
        guard !alreadyThere else { return false }
        updatedPlan.assignSouvenirs(moving, to: recipient)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.update(updatedPlan, userId: userId)
            if let recipient { collapsedRecipients.remove(recipient) } else { collapsedRecipients.remove("") }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    private func groupHeader(_ group: SouvenirGroup) -> some View {
        let isCollapsed = collapsedRecipients.contains(group.id)
        let isDone = group.checkedCount == group.items.count
        return HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isCollapsed {
                        collapsedRecipients.remove(group.id)
                    } else {
                        collapsedRecipients.insert(group.id)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .frame(width: 14)
                    Image(systemName: group.recipient == nil ? "questionmark.circle" : "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(accent)
                    Text(group.recipient ?? "相手なし")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.currentTheme.success)
                    }
                    Text("\(group.checkedCount)/\(group.items.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(isDone ? themeManager.currentTheme.success : themeManager.currentTheme.secondaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(group.recipient ?? "相手なし")、\(group.items.count)個中\(group.checkedCount)個買った"))
            .accessibilityHint(isCollapsed ? "開く" : "閉じる")

            // この人に渡すものを足す。相手の欄に名前を入れて、名前の欄に移る
            Button {
                newItemRecipient = group.recipient ?? ""
                isInputFocused = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 17))
                    .foregroundColor(accent)
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(group.recipient ?? "相手なし")に渡すものを足す"))
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
    }

    private var flatList: some View {
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
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(cardFill)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large).stroke(cardStroke, lineWidth: 1))
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
                        RoundedRectangle(cornerRadius: AppRadius.medium)
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
                PackingItem(name: name, kind: kind, recipient: presetRecipient, ownerId: newItemOwnerId)
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

        // お土産は相手が違えば別のもの（`SouvenirGrouping.importKey`）
        var existingKeys = Set(items.map(SouvenirGrouping.importKey(of:)))
        var added = 0

        for item in incoming where existingKeys.insert(SouvenirGrouping.importKey(of: item)).inserted {
            updatedPlan.packingItems.append(
                PackingItem(name: item.name,
                            isChecked: false,
                            kind: kind,
                            note: item.note,
                            recipient: item.recipient,
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
        let recipient = kind.usesRecipient
            ? newItemRecipient.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        updatedPlan.packingItems.append(
            PackingItem(name: trimmed,
                        kind: kind,
                        note: note.isEmpty ? nil : note,
                        recipient: recipient.isEmpty ? nil : recipient,
                        ownerId: newItemOwnerId)
        )
        // 足した相手が閉じていたら開く（足したものが見えないと、足せたか分からない）
        collapsedRecipients.remove(recipient)

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

    /// 名前（とメモ）を書き換える
    @State private var showsEditor = false
    @State private var editingName = ""
    @State private var editingNote = ""
    @State private var editingRecipient = ""

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

                // お土産のメモ（3.4 までは「誰に」もここ）。入っているときだけ出す
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // 共有中の旅行の、自分だけのお土産（同行者には見えない）
            if showsVisibilityChoice && item.ownerId != nil {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.secondaryText)
                    .accessibilityLabel("自分だけ")
            }

            // 編集と削除は右端の「…」から。長押しの contextMenu だけだと気づけないので常に出す。
            // チェックの丸は左端なので、右端なら間違って押しにくい（予約や旅行計画のカードと同じ形）
            Menu {
                Button("編集", systemImage: "pencil", action: startEditing)
                duplicateMenu
                if showsVisibilityChoice {
                    visibilityButton
                }
                Button("削除", systemImage: "trash", role: .destructive, action: deleteItem)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.8))
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(item.name)のメニュー"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
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
            Button("編集", systemImage: "pencil", action: startEditing)
            duplicateMenu
            Button("削除", systemImage: "trash", role: .destructive, action: deleteItem)
        }
        .alert("\(item.kind.title)を編集", isPresented: $showsEditor) {
            TextField("名前", text: $editingName)
            if item.kind.usesRecipient {
                TextField("渡す相手", text: $editingRecipient)
            }
            // お土産はメモ、ほかもメモがあれば書き換えられるようにする
            if item.kind.usesNote || !(item.note ?? "").isEmpty {
                TextField(item.kind.usesNote ? item.kind.notePlaceholder : "メモ", text: $editingNote)
            }
            Button("キャンセル", role: .cancel) {}
            Button("保存", action: saveEdit)
        }
    }

    // MARK: 複製（3.5）

    /// お土産は「同じ相手に」か「ほかの相手に」を選べる（同じお菓子を何人かに買うとき）。
    /// ほかのリストは、すぐ下に同じものを足す
    @ViewBuilder
    private var duplicateMenu: some View {
        if item.kind.usesRecipient {
            let current = SouvenirGrouping.recipient(of: item)
            let others = SouvenirGrouping.suggestedRecipients(visibleSouvenirs).filter { $0 != current }
            Menu {
                Button("同じ相手に") { duplicate(to: .none) }
                if !others.isEmpty || current != nil {
                    Section("ほかの相手に") {
                        ForEach(others, id: \.self) { name in
                            Button("\(name)へ") { duplicate(to: .some(name)) }
                        }
                        if current != nil {
                            Button("相手なし") { duplicate(to: .some(nil)) }
                        }
                    }
                }
            } label: {
                Label("複製", systemImage: "plus.square.on.square")
            }
        } else {
            Button("複製", systemImage: "plus.square.on.square") { duplicate(to: .none) }
        }
    }

    /// この旅行の、自分に見えるお土産（複製先の相手の候補に使う）
    private var visibleSouvenirs: [PackingItem] {
        (currentPlan?.packingItems ?? []).filter { $0.kind == .souvenir && $0.isVisible(to: authVM.userId) }
    }

    private func duplicate(to recipient: String??) {
        guard var updatedPlan = currentPlan, let userId = authVM.userId else { return }
        updatedPlan.duplicatePackingItem(item.id, recipient: recipient)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.update(updatedPlan, userId: userId)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 共有中の旅行のお土産で、「みんな」と「自分だけ」を切り替えられるか
    private var showsVisibilityChoice: Bool {
        item.kind.choosesVisibilityPerItem && currentPlan?.isShared == true
    }

    @ViewBuilder
    private var visibilityButton: some View {
        if item.ownerId == nil {
            Button("自分だけにする", systemImage: "lock.fill") { setPrivate(true) }
        } else {
            Button("みんなに見せる", systemImage: "person.2.fill") { setPrivate(false) }
        }
    }

    /// 自分だけにすると、同行者のリストからは消える（共有には載らなくなる）
    private func setPrivate(_ isPrivate: Bool) {
        guard var updatedPlan = currentPlan,
              let index = updatedPlan.packingItems.firstIndex(where: { $0.id == item.id }),
              let userId = authVM.userId else { return }
        updatedPlan.packingItems[index].ownerId = isPrivate ? userId : nil
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.update(updatedPlan, userId: userId)
        }
    }

    private func startEditing() {
        editingName = item.name
        editingNote = item.note ?? ""
        editingRecipient = item.recipient ?? ""
        showsEditor = true
    }

    /// 名前が空なら何もしない（空の項目を作らない）
    private func saveEdit() {
        let name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              var updatedPlan = currentPlan,
              let index = updatedPlan.packingItems.firstIndex(where: { $0.id == item.id }),
              let userId = authVM.userId else { return }
        let note = editingNote.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPlan.packingItems[index].name = name
        updatedPlan.packingItems[index].note = note.isEmpty ? nil : note
        if item.kind.usesRecipient {
            let recipient = editingRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedPlan.packingItems[index].recipient = recipient.isEmpty ? nil : recipient
        }
        viewModel.update(updatedPlan, userId: userId)
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
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: item.isChecked)
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
