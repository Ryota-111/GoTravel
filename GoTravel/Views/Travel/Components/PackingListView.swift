import SwiftUI

// MARK: - Packing List View
struct PackingListView: View {

    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var viewModel: TravelPlanViewModel
    @EnvironmentObject var authVM: AuthViewModel
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
        HStack(spacing: 12) {
            TextField("持ち物を追加", text: $newItemName)
                .font(.body)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )

            Button(action: addItem) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(newItemName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .gray.opacity(0.4))

            Text("持ち物を追加してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func itemsList(for plan: TravelPlan) -> some View {
        VStack(spacing: 8) {
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
    let item: PackingItem
    let planId: String

    // Computed property to get current plan from viewModel
    private var currentPlan: TravelPlan? {
        viewModel.travelPlans.first(where: { $0.id == planId })
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: toggleCheck) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isChecked ? .green : .secondary)
            }

            // Item name
            Text(item.name)
                .font(.body)
                .foregroundColor(item.isChecked ? .secondary : (colorScheme == .dark ? .white : .black))
                .strikethrough(item.isChecked, color: .secondary)

            Spacer()

            // Delete button
            Button(action: deleteItem) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            item.isChecked ? Color.green.opacity(0.3) : Color.orange.opacity(0.2),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
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
