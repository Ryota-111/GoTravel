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

    // Computed property to get current plan from viewModel
    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == plan.id })
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            // Add new item section
            addItemSection

            // Items list
            if let currentPlan = currentPlan {
                if currentPlan.packingItems.isEmpty {
                    emptyStateView
                } else {
                    itemsList(for: currentPlan)
                }
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - View Components
    private var addItemSection: some View {
        HStack(spacing: 10) {
            TextField("持ち物を追加", text: $newItemName)
                .font(.system(size: 15))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeManager.currentTheme.cardBorder, lineWidth: 1)
                )

            Button(action: addItem) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [themeManager.currentTheme.primary.opacity(0.9), themeManager.currentTheme.primary.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bag")
                .font(.system(size: 36))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))

            Text("持ち物を追加してください")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.6))
        )
    }

    private func itemsList(for plan: TravelPlan) -> some View {
        VStack(spacing: 6) {
            ForEach(plan.packingItems) { item in
                PackingItemRow(item: item, planId: plan.id ?? "")
                    .environmentObject(viewModel)
            }
        }
    }

    // MARK: - Actions
    private func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newItem = PackingItem(name: trimmedName)
        var updatedPlan = plan
        updatedPlan.packingItems.append(newItem)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if let userId = authVM.userId {
                viewModel.update(updatedPlan, userId: userId)
            }
            newItemName = ""
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

    // Computed property to get current plan from viewModel
    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == planId })
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button(action: toggleCheck) {
                ZStack {
                    Circle()
                        .stroke(item.isChecked ? themeManager.currentTheme.success.opacity(0.5) : themeManager.currentTheme.cardBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.currentTheme.success)
                    }
                }
            }

            // Item name
            Text(item.name)
                .font(.system(size: 15))
                .foregroundColor(item.isChecked ? .secondary : (colorScheme == .dark ? .white : .black))
                .strikethrough(item.isChecked, color: .secondary)

            Spacer()

            // Delete button
            Button(action: deleteItem) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.isChecked
                    ? themeManager.currentTheme.success.opacity(0.08)
                    : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.6))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    item.isChecked ? themeManager.currentTheme.success.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Actions
    private func toggleCheck() {
        guard var updatedPlan = currentPlan else { return }

        if let index = updatedPlan.packingItems.firstIndex(where: { $0.id == item.id }) {
            updatedPlan.packingItems[index].isChecked.toggle()

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
