import SwiftUI

// MARK: - Packing List View
struct PackingListView: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    let plan: TravelPlan

    @State private var newItemName: String = ""
    @FocusState private var isInputFocused: Bool

    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == plan.id })
    }

    private var items: [PackingItem] {
        currentPlan?.packingItems ?? []
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
            if !items.isEmpty {
                progressHeader
            }

            addItemSection

            if items.isEmpty {
                emptyStateView
            } else {
                itemsList
            }
        }
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
                    Label("準備完了", systemImage: "checkmark.circle.fill")
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
        HStack(spacing: 10) {
            TextField("持ち物を追加", text: $newItemName)
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
            Image(systemName: "bag")
                .font(.system(size: 34))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))

            Text("忘れ物を防ぐために、持ち物を書き出しておきましょう")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // 最初の1件を入力する手間が一番の障壁なので、よく使うものから足せるようにする
            VStack(alignment: .leading, spacing: 8) {
                Text("よく使う持ち物")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(themeManager.currentTheme.secondaryText)

                FlowChips(items: Self.presets) { preset in
                    add(name: preset)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardFill)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardStroke, lineWidth: 1))
        )
    }

    private static let presets = [
        "充電器", "モバイルバッテリー", "常備薬", "歯ブラシ",
        "着替え", "洗面用具", "傘", "身分証", "現金"
    ]

    // MARK: - Actions

    private func addItem() {
        add(name: trimmedNewItemName)
        newItemName = ""
    }

    private func add(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var updatedPlan = currentPlan ?? Optional(plan) else { return }

        updatedPlan.packingItems.append(PackingItem(name: trimmed))

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
    let onTap: (String) -> Void

    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        // 3列に固定すると文字数で崩れるため、可変幅のグリッドで折り返す
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text(item)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(themeManager.currentTheme.actionFill)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(themeManager.currentTheme.actionFill.opacity(0.12)))
                }
                .buttonStyle(.plain)
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

            Text(item.name)
                .font(.system(size: 15))
                .foregroundColor(item.isChecked ? themeManager.currentTheme.secondaryText : textColor)
                .strikethrough(item.isChecked, color: themeManager.currentTheme.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
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
