import SwiftUI

struct PlacesListView: View {

    // MARK: - Properties
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedCategory: PlaceCategory = .hotel
    @State private var hasLoadedData = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    // MARK: - Computed Properties
    private var filteredPlaces: [VisitedPlace] {
        vm.places.filter { $0.category == selectedCategory }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var cardGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.xsecondary, themeManager.currentTheme.dark.opacity(0.1)] : [themeManager.currentTheme.xsecondary, themeManager.currentTheme.light.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
    }
    
    private var xtextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent1 : themeManager.currentTheme.accent2
    }
    
    private var DLtextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.light : themeManager.currentTheme.dark
    }
    
    private var xDLtextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.dark : themeManager.currentTheme.light
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2.opacity(0.7) : themeManager.currentTheme.accent1.opacity(0.6)
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                VStack {
                    planEventsTitleSection
                    eventTypeSelectionSection
                    contentView
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .task {
            // 初回のみCore DataのFetchedResultsControllerをセットアップ
            if !hasLoadedData, let userId = authVM.userId {
                vm.setupFetchedResultsController(userId: userId)
                hasLoadedData = true
            }
        }
    }

    // MARK: - View Components
    private var contentView: some View {
        Group {
            if vm.isLoading {
                loadingView
            } else if filteredPlaces.isEmpty {
                emptyStateView
            } else {
                placesListView
            }
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.accent1))
                .scaleEffect(1.5)
            Text("読み込み中...")
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
                .padding(.top, 20)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(secondaryTextColor)

                Text("まだ保存された場所はありません")
                    .font(.headline)
                    .foregroundColor(textColor)

                Text("マップをタップして場所を追加しましょう")
                    .font(.subheadline)
                    .foregroundColor(secondaryTextColor)

                NavigationLink(destination: MapHomeView()) {
                    Text("場所を追加")
                        .font(.headline)
                        .foregroundColor(xDLtextColor)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(textColor)
                        .cornerRadius(25)
                }
            }
            .padding()

            Spacer()
        }
    }

    private var placesListView: some View {
        ScrollView {
            VStack(spacing: 15) {
                ForEach(filteredPlaces) { place in
                    placeCardView(place)
                }

                NavigationLink(destination: MapHomeView()) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(textColor)
                        Text("場所を追加")
                            .font(.headline)
                            .foregroundColor(textColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.currentTheme.accent2.opacity(0.2))
                    .cornerRadius(15)
                }
                .padding(.top, 10)
            }
            .padding()
        }
    }

    private func placeCardView(_ place: VisitedPlace) -> some View {
        NavigationLink(destination: PlaceDetailView(place: place)) {
            VStack(alignment: .leading, spacing: 10) {
                placeHeader(place: place)

                Divider()
                    .background(secondaryTextColor)

                placeDate(place: place)
            }
            .padding()
            .background(cardGradient)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.secondary.opacity(0.5),
                                themeManager.currentTheme.secondary.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(
                color: themeManager.currentTheme.secondary.opacity(0.5),
                radius: 10
            )
        }
        .contextMenu {
            deleteButton(place: place)
        }
    }

    private func placeHeader(place: VisitedPlace) -> some View {
        HStack {
            Image(systemName: place.category.iconName)
                .foregroundColor(DLtextColor)

            Text(place.title)
                .font(.headline)
                .foregroundColor(DLtextColor)
        }
    }

    private func placeDate(place: VisitedPlace) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(DLtextColor)

            Text(formattedDate(place))
                .font(.subheadline)
                .foregroundColor(DLtextColor)
        }
    }

    private func deleteButton(place: VisitedPlace) -> some View {
        Button(role: .destructive) {
            deletePlace(place)
        } label: {
            Label("削除", systemImage: "trash")
        }
    }
    
    private var planEventsTitleSection: some View {
        HStack {
            Text("保存した場所")
                .font(.title.weight(.semibold))
                .foregroundColor(textColor)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var eventTypeSelectionSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(PlaceCategory.allCases) { category in
                    horizontalEventsCard(
                        menuName: category.displayName,
                        menuImage: category.iconName,
                        rectColor: selectedCategory == category ? themeManager.currentTheme.xsecondary : themeManager.currentTheme.light,
                        imageColors: selectedCategory == category ? themeManager.currentTheme.light : themeManager.currentTheme.xsecondary,
                        textColor: selectedCategory == category ? themeManager.currentTheme.xsecondary : themeManager.currentTheme.secondaryText
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helper Methods
    private func formattedDate(_ place: VisitedPlace) -> String {
        let formatter = DateFormatter.japaneseDate
        return place.visitedAt != nil
            ? formatter.string(from: place.visitedAt!)
            : formatter.string(from: place.createdAt)
    }

    // MARK: - Actions
    private func deletePlace(_ place: VisitedPlace) {
        guard let userId = authVM.userId else { return }
        vm.delete(place, userId: userId)
    }
}


