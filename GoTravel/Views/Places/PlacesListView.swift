import SwiftUI
import MapKit

struct PlacesListView: View {

    // MARK: - Properties
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = PlacesViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var categoryManager = PlaceCategoryManager.shared
    @State private var selectedCategoryId: String = Self.allCategoryId

    static let allCategoryId = "all"
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

    /// 地図の長押しで場所を追加する導線。マップ画面と同じ処理を使う
    @StateObject private var placePicker = MapPlacePicker()

    // MARK: - Computed Properties
    private var filteredPlaces: [VisitedPlace] {
        if selectedCategoryId == Self.allCategoryId {
            return vm.places
        }
        return vm.places.filter { $0.categoryId == selectedCategoryId }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? [themeManager.currentTheme.gradientDark, themeManager.currentTheme.dark] : [themeManager.currentTheme.gradientLight, themeManager.currentTheme.light]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// カード全体の基調となるテーマ色（予定計画カードと揃える）
    private var mainColor: Color {
        themeManager.currentTheme.xprimary
    }

    private var textColor: Color {
        colorScheme == .dark ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
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
            // 地図の情報パネルと重なるときだけ引っ込める
            .overlay(alignment: .bottomTrailing) {
                if !(showMap && selectedPlace != nil) {
                    addPlaceFloatingButton
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        // sheetはNavigationView外に置いてview再構築による不安定化を防ぐ
        .sheet(isPresented: $showManageCategories) {
            ManageCategoriesView()
        }
        .sheet(isPresented: $placePicker.isPresentingSheet, onDismiss: { placePicker.clearPin() }) {
            if let coordinate = placePicker.coordinate {
                SavePlaceView(vm: {
                    let saveVM = SavePlaceViewModel(coord: coordinate, placesVM: vm)
                    saveVM.title = placePicker.title
                    return saveVM
                }())
                .environmentObject(authVM)
            }
        }
        .task {
            // 初回のみCore DataのFetchedResultsControllerをセットアップ
            if !hasLoadedData, let userId = authVM.userId {
                vm.setupFetchedResultsController(userId: userId)
                hasLoadedData = true
            }
        }
    }

    /// 追加ボタン。
    /// リストの末尾に置くと件数が増えるほど遠ざかるため、内容に左右されない右下に浮かせる
    private var addPlaceFloatingButton: some View {
        NavigationLink(destination: MapHomeView()) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ThemePreset.readableText(on: mainColor))
                .frame(width: 56, height: 56)
                .background(Circle().fill(mainColor))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel(Text("場所を追加"))
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

                Text(vm.places.isEmpty ? "まだ保存された場所はありません" : "このカテゴリの場所はありません")
                    .font(.headline)
                    .foregroundColor(textColor)

                // 以前は「マップをタップ」と案内していたが、その操作は存在しなかった
                Text(vm.places.isEmpty ? "マップで検索するか、地図を長押しして場所を追加できます" : "別のカテゴリを選ぶか、場所を追加しましょう")
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
            // 右下の追加ボタンに最後の項目が隠れないようにする
            .padding(.bottom, 70)
        }
    }

    /// 予定カードと同じ言語で組む。面には色を敷かず、色はサムネイルとタグへ。
    /// 全カードにテーマ色を敷いていたときは、並べると一覧が騒がしかった
    private func placeCardView(_ place: VisitedPlace) -> some View {
        let category = categoryManager.category(for: place.categoryId)
        let accent = categoryColor(category)
        let surface: Color = colorScheme == .dark
            ? themeManager.currentTheme.secondaryBackgroundDark
            : themeManager.currentTheme.backgroundLight

        return NavigationLink(destination: PlaceDetailView(place: place)) {
            HStack(spacing: 12) {
                placeThumbnail(place, category: category, accent: accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                        .lineLimit(1)

                    // 同じ名前の店が複数あっても見分けられるように住所を出す
                    if let address = place.address, !address.isEmpty {
                        Text(address)
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }

                    HStack(spacing: 7) {
                        Text(category.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(accent.opacity(colorScheme == .dark ? 0.24 : 0.14), in: RoundedRectangle(cornerRadius: 6))

                        Text(formattedDate(place))
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                placeMenuButton(place: place)
            }
            .padding(.leading, 9)
            .padding(.vertical, 9)
            .padding(.trailing, 4)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(surface)
            )
            // ダークでは影が沈んで効かないので、細い輪郭に置き換える
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? mainColor.opacity(0.10) : .clear, lineWidth: 1)
            )
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.07),
                radius: 13,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// 保存した写真は詳細でしか見えていなかった。一覧でも出すと、
    /// 名前を読まなくてもどの場所か分かる
    private func placeThumbnail(_ place: VisitedPlace, category: CustomPlaceCategory, accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(accent.opacity(colorScheme == .dark ? 0.24 : 0.14))
            .frame(width: 56, height: 56)
            .overlay {
                if let fileName = place.localPhotoFileName,
                   let image = FileManager.documentsImage(named: fileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: category.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accent)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 長押しの contextMenu だけでは削除できることに気づけない。
    /// 予定カードと同じ44ptの「⋯」に揃える
    private func placeMenuButton(place: VisitedPlace) -> some View {
        Menu {
            deleteButton(place: place)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(secondaryTextColor)
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("この場所の操作")
    }

    /// カテゴリの色。`CustomPlaceCategory` は色を持たないので、
    /// 既定の3つは決め打ち、ユーザーが足した分はテーマのカテゴリ色から配る。
    /// モデルに色を足すと CloudKit と同期するスキーマを変えることになるため、
    /// ここで決める。並び順ではなくIDから決めるので、追加や削除でも色が動かない
    private func categoryColor(_ category: CustomPlaceCategory) -> Color {
        let theme = themeManager.currentTheme

        switch category.id {
        case "hotel":       return theme.outingPlanColor
        case "restaurant":  return theme.dailyPlanColor
        case "sightseeing": return theme.travelColor
        default:
            let palette = [theme.japan, theme.family, theme.landscape, theme.food, theme.custom]
            // String の hashValue は起動ごとに変わるため使わない
            let stable = category.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
            return palette[stable % palette.count]
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
            .accessibilityLabel(showMap ? "リスト表示に切り替え" : "マップ表示に切り替え")

            // 旅行計画（しおり）には提携リンクを置かないので、ここを入口にする
            NavigationLink(destination: ExperienceSearchView()) {
                Image(systemName: "ticket.fill")
                    .foregroundColor(textColor)
                    .padding(8)
                    .background(textColor.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel(Text("あそび・体験を探す"))

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
            // 長押しの変換基準を合わせるため、ignoresSafeArea は MapReader 側に付ける。
            // Map だけが安全領域を無視すると枠がずれ、押した位置と違う所にピンが立つ
            MapReader { proxy in
                placesMap
                    .longPressToDropPin(proxy: proxy, picker: placePicker)
            }
            .ignoresSafeArea(edges: .bottom)

            if let place = selectedPlace {
                placeBottomPanel(place)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                LongPressHintLabel()
            }
        }
    }

    private var placesMap: some View {
        Map(position: $mapPosition) {
            // 長押しで立てたピン
            droppedPinContent(at: placePicker.coordinate, color: themeManager.currentTheme.success)

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
        .onTapGesture {
            withAnimation { selectedPlace = nil }
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
                horizontalEventsCard(
                    menuName: "すべて",
                    menuImage: "square.grid.2x2.fill",
                    rectColor: selectedCategoryId == Self.allCategoryId ? themeManager.currentTheme.xsecondary : themeManager.currentTheme.light,
                    imageColors: selectedCategoryId == Self.allCategoryId ? themeManager.currentTheme.light : themeManager.currentTheme.xsecondary,
                    textColor: selectedCategoryId == Self.allCategoryId ? themeManager.currentTheme.xsecondary : themeManager.currentTheme.secondaryText
                )
                .onTapGesture {
                    withAnimation(.spring()) {
                        selectedCategoryId = Self.allCategoryId
                    }
                }

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


