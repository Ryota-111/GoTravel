import SwiftUI

/// 「場所保存」に貯めた場所からスケジュールの行き先を選ぶ。
/// 保存した場所と旅程が分断されていて、同じ場所を検索し直す必要があったため用意した
struct SavedPlacePickerView: View {
    let accentColor: Color
    let onSelect: (VisitedPlace) -> Void

    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @ObservedObject private var categoryManager = PlaceCategoryManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var searchText = ""
    @State private var selectedCategoryId = SavedPlacePickerView.allCategoryId

    static let allCategoryId = "all"

    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }

    private var filteredPlaces: [VisitedPlace] {
        var places = vm.places

        if selectedCategoryId != Self.allCategoryId {
            places = places.filter { $0.categoryId == selectedCategoryId }
        }

        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        if !keyword.isEmpty {
            places = places.filter { place in
                place.title.localizedCaseInsensitiveContains(keyword)
                    || (place.address?.localizedCaseInsensitiveContains(keyword) ?? false)
            }
        }

        return places
    }

    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark
                 ? themeManager.currentTheme.backgroundDark
                 : themeManager.currentTheme.backgroundLight)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if !vm.places.isEmpty {
                        categoryFilter
                    }

                    if vm.places.isEmpty {
                        emptyState(
                            icon: "mappin.slash",
                            title: "保存した場所がありません",
                            message: "「場所保存」タブで場所を保存すると\nここから選べるようになります"
                        )
                    } else if filteredPlaces.isEmpty {
                        emptyState(
                            icon: "magnifyingglass",
                            title: "該当する場所がありません",
                            message: "検索条件を変えてお試しください"
                        )
                    } else {
                        placeList
                    }
                }
            }
            .searchable(text: $searchText, prompt: "保存した場所を検索")
            .navigationTitle("保存した場所")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(accentColor)
                }
            }
            .task {
                if let userId = authVM.userId {
                    vm.setupFetchedResultsController(userId: userId)
                }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "すべて", id: Self.allCategoryId, icon: "square.grid.2x2.fill")

                ForEach(categoryManager.categories) { category in
                    filterChip(title: category.name, id: category.id, icon: category.icon)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(title: String, id: String, icon: String) -> some View {
        let isSelected = selectedCategoryId == id

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedCategoryId = id
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(isSelected ? .white : accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(accentColor)
                } else {
                    Capsule().fill(accentColor.opacity(0.12))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - List

    private var placeList: some View {
        List {
            ForEach(filteredPlaces) { place in
                Button {
                    onSelect(place)
                    dismiss()
                } label: {
                    row(for: place)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .listStyle(.plain)
    }

    private func row(for place: VisitedPlace) -> some View {
        let category = categoryManager.category(for: place.categoryId)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: category.icon)
                    .font(.system(size: 17))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(category.name)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.12), in: Capsule())

                    if let address = place.address, !address.isEmpty {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(accentColor)
        }
        .contentShape(Rectangle())
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.4))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(textColor)

            Text(message)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }
}
