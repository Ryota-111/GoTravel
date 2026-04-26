import SwiftUI
import MapKit

struct PlacesListView: View {

    // MARK: - Properties
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var categoryManager = PlaceCategoryManager.shared
    @State private var selectedCategoryId: String = "hotel"
    @State private var hasLoadedData = false
    @State private var showManageCategories = false
    @State private var showMap = false
    @State private var selectedPlace: VisitedPlace?
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    // MARK: - Computed Properties
    private var filteredPlaces: [VisitedPlace] {
        vm.places.filter { $0.categoryId == selectedCategoryId }
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
                VStack(spacing: 0) {
                    planEventsTitleSection
                    if showMap {
                        mapView
                    } else {
                        eventTypeSelectionSection
                        contentView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // sheetはNavigationView外に置いてview再構築による不安定化を防ぐ
        .sheet(isPresented: $showManageCategories) {
            ManageCategoriesView()
        }
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
            Image(systemName: categoryManager.category(for: place.categoryId).icon)
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

            // マップ/リスト切り替え
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMap.toggle()
                    selectedPlace = nil
                }
            }) {
                Image(systemName: showMap ? "list.bullet" : "map.fill")
                    .foregroundColor(textColor)
                    .padding(8)
                    .background(textColor.opacity(0.1))
                    .clipShape(Circle())
            }

            Button(action: { showManageCategories = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                    Text("管理")
                        .font(.subheadline)
                }
                .foregroundColor(textColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Map View
    private var mapView: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition) {
                ForEach(vm.places) { place in
                    Annotation(place.title, coordinate: place.coordinate) {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                selectedPlace = place
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(selectedPlace?.id == place.id
                                          ? themeManager.currentTheme.xprimary
                                          : themeManager.currentTheme.error.opacity(0.9))
                                    .frame(width: 38, height: 38)
                                    .shadow(color: themeManager.currentTheme.error.opacity(0.4), radius: 4, x: 0, y: 2)
                                    .scaleEffect(selectedPlace?.id == place.id ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPlace?.id == place.id)
                                Image(systemName: categoryManager.category(for: place.categoryId).icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .onTapGesture {
                withAnimation { selectedPlace = nil }
            }

            // 選択済み場所のボトムパネル
            if let place = selectedPlace {
                placeBottomPanel(place)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func placeBottomPanel(_ place: VisitedPlace) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 12) {
                // カテゴリーアイコン
                ZStack {
                    Circle()
                        .fill(themeManager.currentTheme.error.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: categoryManager.category(for: place.categoryId).icon)
                        .font(.system(size: 18))
                        .foregroundColor(themeManager.currentTheme.error)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.title)
                        .font(.headline)
                        .foregroundColor(textColor)
                        .lineLimit(1)
                    Text(categoryManager.category(for: place.categoryId).name)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryText)
                    if let visitedAt = place.visitedAt {
                        Text(DateFormatter.japaneseDate.string(from: visitedAt))
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryText)
                    }
                }

                Spacer()

                Button(action: { withAnimation { selectedPlace = nil } }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(.systemGray3))
                }
            }
            .padding(.horizontal, 20)

            NavigationLink(destination: PlaceDetailView(place: place)) {
                Label("詳細を見る", systemImage: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(themeManager.currentTheme.xprimary)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark
                      ? themeManager.currentTheme.secondaryBackgroundDark
                      : Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -4)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private var eventTypeSelectionSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(categoryManager.categories) { category in
                    horizontalEventsCard(
                        menuName: category.name,
                        menuImage: category.icon,
                        rectColor: selectedCategoryId == category.id ? themeManager.currentTheme.xsecondary : themeManager.currentTheme.light,
                        imageColors: selectedCategoryId == category.id ? themeManager.currentTheme.light : themeManager.currentTheme.xsecondary,
                        textColor: selectedCategoryId == category.id ? themeManager.currentTheme.xsecondary : themeManager.currentTheme.secondaryText
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedCategoryId = category.id
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


