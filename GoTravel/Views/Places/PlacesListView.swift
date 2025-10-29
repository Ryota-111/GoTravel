import SwiftUI

struct PlacesListView: View {

    // MARK: - Properties
    @StateObject private var vm = PlacesViewModel()
    @State private var selectedCategory: PlaceCategory = .hotel
    @Environment(\.colorScheme) var colorScheme

    // MARK: - Computed Properties
    private var filteredPlaces: [VisitedPlace] {
        vm.places.filter { $0.category == selectedCategory }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [.blue.opacity(0.7), .black] : [.blue.opacity(0.6), .white]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var cardGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [.orange, .black.opacity(0.4)] : [.orange.opacity(0.8), .white.opacity(0.5)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6)
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
        }
    }

    // MARK: - View Components
    private var contentView: some View {
        Group {
            if filteredPlaces.isEmpty {
                emptyStateView
            } else {
                placesListView
            }
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(.orange)
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
                            .foregroundColor(.orange)
                        Text("場所を追加")
                            .font(.headline)
                            .foregroundColor(textColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.2))
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
            .shadow(color: colorScheme == .dark ? .black.opacity(0.3) : .gray.opacity(0.2), radius: 10, x: 0, y: 5)
        }
        .contextMenu {
            deleteButton(place: place)
        }
    }

    private func placeHeader(place: VisitedPlace) -> some View {
        HStack {
            Image(systemName: place.category.iconName)
                .foregroundColor(textColor)

            Text(place.title)
                .font(.headline)
                .foregroundColor(textColor)
        }
    }

    private func placeDate(place: VisitedPlace) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(secondaryTextColor)

            Text(formattedDate(place))
                .font(.subheadline)
                .foregroundColor(secondaryTextColor)
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
                        rectColor: selectedCategory == category ? .orange : Color.white,
                        imageColors: selectedCategory == category ? .white : .orange,
                        textColor: selectedCategory == category ? .orange : .gray
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
        FirestoreService.shared.delete(place: place) { err in
            if let err = err {
                print("delete error:", err.localizedDescription)
            }
        }
    }
}


