import SwiftUI
import MapKit

struct AddPlanView: View {

    // MARK: - Properties
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var themeManager = ThemeManager.shared

    var onSave: (Plan) -> Void

    // Wizard state
    @State private var currentStep: Int = 0
    @State private var isGoingForward: Bool = true

    // Form data
    @State private var selectedPlanType: PlanType = .outing
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var places: [PlannedPlace] = []
    @State private var dailyDate: Date = Date()
    @State private var dailyTime: Date = Date()
    @State private var description: String = ""
    @State private var linkURL: String = ""

    // Map state
    @State private var showMapPicker: Bool = false
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var selectedMapResult: MKMapItem?
    @State private var mapVisibleRegion: MKCoordinateRegion?

    // MARK: - Computed Properties
    private var totalSteps: Int { selectedPlanType == .outing ? 4 : 6 }
    private var isLastStep: Bool { currentStep == totalSteps - 1 }

    private var canProceed: Bool {
        switch currentStep {
        case 1: return !title.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return selectedPlanType == .outing ? startDate <= endDate : true
        case 4: return !description.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    // MARK: - Theme-Adaptive Colors

    // テーマに合わせたプランカラー（白黒・パステルピンクテーマ時の色衝突を解消）
    private func planColorFor(_ type: PlanType) -> Color {
        switch themeManager.currentTheme.type {
        case .pastelPink:
            return type == .outing
                ? Color(red: 0.76, green: 0.37, blue: 0.51)   // ローズピンク
                : Color(red: 0.61, green: 0.45, blue: 0.74)   // ラベンダー
        case .whiteBlack:
            return type == .outing
                ? Color(red: 0.25, green: 0.38, blue: 0.68)   // スチールブルー
                : Color(red: 0.55, green: 0.37, blue: 0.16)   // ウォームブラウン
        case .blackWhite:
            return type == .outing
                ? Color(red: 0.38, green: 0.58, blue: 0.90)   // スカイブルー
                : Color(red: 0.84, green: 0.60, blue: 0.24)   // ゴールデン
        case .originalColor:
            return type == .outing
                ? themeManager.currentTheme.outingPlanColor
                : themeManager.currentTheme.dailyPlanColor
        }
    }

    // テーマに合わせたアクセントカラー（白背景時にwhiteが見えなくなる問題を解消）
    private func uiTextColorFor(_ type: PlanType) -> Color {
        switch themeManager.currentTheme.type {
        case .pastelPink:
            return type == .outing
                ? Color(red: 0.28, green: 0.12, blue: 0.22)   // ダークプラム（ピンク背景で視認性確保）
                : themeManager.currentTheme.accent1
        default:
            return type == .outing ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
        }
    }

    // カード内の強調テキスト（色付き背景の上に乗る文字）
    private func cardHighlightTextFor(_ type: PlanType) -> Color {
        if themeManager.currentTheme.type == .originalColor {
            return type == .outing ? themeManager.currentTheme.accent2 : themeManager.currentTheme.accent1
        }
        return .white
    }

    private var effectivePlanColor: Color { planColorFor(selectedPlanType) }
    private var uiAccentColor: Color { uiTextColorFor(selectedPlanType) }

    // 白黒テーマで同色グラデーションになる問題を修正
    private var backgroundGradient: some View {
        let colors: [Color]
        switch themeManager.currentTheme.type {
        case .whiteBlack:
            colors = [Color(white: 0.97), Color(white: 0.84)]
        case .blackWhite:
            colors = [Color(white: 0.07), Color(white: 0.17)]
        default:
            colors = selectedPlanType == .outing
                ? [themeManager.currentTheme.yprimary, themeManager.currentTheme.dark]
                : [themeManager.currentTheme.ysecondary, themeManager.currentTheme.light]
        }
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 0) {
                headerView
                progressView
                stepContentView
                navigationButtons
            }
        }
        .fullScreenCover(isPresented: $showMapPicker) { mapPickerView }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(uiAccentColor)
                    .imageScale(.medium)
                    .padding(8)
                    .background(uiAccentColor.opacity(0.15))
                    .clipShape(Circle())
            }
            Spacer()
            Text("新しいプラン")
                .font(.headline)
                .foregroundColor(uiAccentColor)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(effectivePlanColor.opacity(0.35))
    }

    // MARK: - Progress Indicator
    private var progressView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStep ? effectivePlanColor : uiAccentColor.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: totalSteps)
            .padding(.horizontal, 20)

            Text("\(currentStep + 1) / \(totalSteps)")
                .font(.caption)
                .foregroundColor(uiAccentColor.opacity(0.6))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Step Content
    private var stepContentView: some View {
        ZStack {
            switch currentStep {
            case 0: step0TypeSelection
            case 1: step1Title
            case 2: step2Date
            case 3: step3Places
            case 4: step4Description
            case 5: step5Link
            default: EmptyView()
            }
        }
        .id(currentStep)
        .transition(stepTransition)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(action: goBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                    }
                    .font(.headline)
                    .foregroundColor(uiAccentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(uiAccentColor.opacity(0.15))
                    .cornerRadius(14)
                }
            }

            Button(action: goForward) {
                HStack(spacing: 4) {
                    if isLastStep {
                        Image(systemName: selectedPlanType == .outing ? "airplane.departure" : "calendar.badge.clock")
                        Text("保存")
                    } else {
                        Text("次へ")
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.headline.weight(.bold))
                .foregroundColor(canProceed ? uiAccentColor : uiAccentColor.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canProceed ? effectivePlanColor : uiAccentColor.opacity(0.1))
                .cornerRadius(14)
                .animation(.easeInOut(duration: 0.2), value: canProceed)
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(.ultraThinMaterial)
    }

    private func goBack() {
        isGoingForward = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep -= 1
        }
    }

    private func goForward() {
        guard !isLastStep else {
            savePlan()
            return
        }
        isGoingForward = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep += 1
        }
    }

    // MARK: - Step 0: Type Selection
    private var step0TypeSelection: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("何のプランを作りますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("種類を選ぶとフローが最適化されます")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            HStack(spacing: 16) {
                typeCard(type: .outing, icon: "figure.walk", title: "おでかけ", subtitle: "旅行・お出かけ計画")
                typeCard(type: .daily, icon: "house.fill", title: "日常", subtitle: "日常のタスク・用事")
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func typeCard(type: PlanType, icon: String, title: String, subtitle: String) -> some View {
        let isSelected = selectedPlanType == type
        let cardColor = planColorFor(type)
        let highlightText = cardHighlightTextFor(type)
        let baseText = uiTextColorFor(type)

        return Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedPlanType = type
            }
        }) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? cardColor : cardColor.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(isSelected ? highlightText : cardColor)
                }
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(isSelected ? highlightText : baseText.opacity(0.45))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isSelected ? highlightText.opacity(0.75) : baseText.opacity(0.30))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? cardColor.opacity(0.25) : baseText.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? cardColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Step 1: Title
    private var step1Title: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("プランの名前は？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text(selectedPlanType == .outing ? "例：大阪旅行、週末お出かけ" : "例：ジム、英語の課題")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .foregroundColor(uiAccentColor.opacity(0.6))
                ZStack(alignment: .leading) {
                    if title.isEmpty {
                        Text(selectedPlanType == .outing ? "大阪旅行" : "ジム")
                            .foregroundColor(uiAccentColor.opacity(0.3))
                            .font(.title3)
                    }
                    TextField("", text: $title)
                        .font(.title3)
                        .foregroundColor(uiAccentColor)
                }
            }
            .padding(20)
            .background(uiAccentColor.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Step 2: Date / DateTime
    @ViewBuilder
    private var step2Date: some View {
        if selectedPlanType == .outing {
            outingDateStep
        } else {
            dailyDateTimeStep
        }
    }

    private var outingDateStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("いつ行きますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("開始日と終了日を選んでください")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                datePickerRow(label: "開始日", icon: "calendar", date: $startDate)
                datePickerRow(label: "終了日", icon: "calendar.badge.checkmark", date: $endDate)

                if endDate < startDate {
                    Label("終了日は開始日以降にしてください", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.error)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var dailyDateTimeStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("いつですか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("日付と時間を設定してください")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                datePickerRow(label: "日付", icon: "calendar", date: $dailyDate)
                timePickerRow(label: "時間", icon: "clock", time: $dailyTime)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func datePickerRow(label: String, icon: String, date: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(uiAccentColor.opacity(0.7))
                .frame(width: 24)
            Text(label)
                .font(.headline)
                .foregroundColor(uiAccentColor)
            Spacer()
            DatePicker("", selection: date, displayedComponents: .date)
                .colorMultiply(uiAccentColor)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
        }
        .padding(20)
        .background(uiAccentColor.opacity(0.1))
        .cornerRadius(16)
    }

    private func timePickerRow(label: String, icon: String, time: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(uiAccentColor.opacity(0.7))
                .frame(width: 24)
            Text(label)
                .font(.headline)
                .foregroundColor(uiAccentColor)
            Spacer()
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .colorMultiply(uiAccentColor)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
        }
        .padding(20)
        .background(uiAccentColor.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Step 3: Places
    private var step3Places: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text(selectedPlanType == .outing ? "行きたい場所は？" : "行く場所はありますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text(selectedPlanType == .outing ? "複数追加できます" : "任意 — スキップも可能です")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            ScrollView {
                VStack(spacing: 10) {
                    if places.isEmpty {
                        HStack {
                            Image(systemName: "mappin.slash")
                                .foregroundColor(uiAccentColor.opacity(0.4))
                            Text("まだ場所が追加されていません")
                                .font(.subheadline)
                                .foregroundColor(uiAccentColor.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(uiAccentColor.opacity(0.07))
                        .cornerRadius(16)
                    } else {
                        ForEach(places) { place in
                            placeRow(place)
                        }
                    }

                    Button(action: { showMapPicker = true }) {
                        Label("場所を追加", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(uiAccentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(effectivePlanColor.opacity(0.25))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func placeRow(_ place: PlannedPlace) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(effectivePlanColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.headline)
                    .foregroundColor(uiAccentColor)
                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(uiAccentColor.opacity(0.6))
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: { deletePlace(place) }) {
                Image(systemName: "trash")
                    .foregroundColor(themeManager.currentTheme.error)
                    .padding(8)
            }
        }
        .padding(16)
        .background(uiAccentColor.opacity(0.1))
        .cornerRadius(16)
    }

    // MARK: - Step 4: Description (daily only)
    private var step4Description: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("何をしますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("具体的な内容を入力してください（必須）")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("例：英語の課題をやる、ジムで30分走る")
                        .foregroundColor(uiAccentColor.opacity(0.3))
                        .font(.body)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $description)
                    .font(.body)
                    .foregroundColor(uiAccentColor)
                    .frame(height: 160)
                    .scrollContentBackground(.hidden)
            }
            .padding(16)
            .background(uiAccentColor.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Step 5: Link (daily only, optional)
    private var step5Link: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("参考リンクはありますか？")
                    .font(.title2.weight(.bold))
                    .foregroundColor(uiAccentColor)
                Text("任意 — スキップして保存できます")
                    .font(.subheadline)
                    .foregroundColor(uiAccentColor.opacity(0.6))
            }
            .padding(.top, 40)

            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundColor(uiAccentColor.opacity(0.6))
                ZStack(alignment: .leading) {
                    if linkURL.isEmpty {
                        Text("https://example.com")
                            .foregroundColor(uiAccentColor.opacity(0.3))
                    }
                    TextField("", text: $linkURL)
                        .foregroundColor(uiAccentColor)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .padding(20)
            .background(uiAccentColor.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Map Picker View
    private var mapPickerView: some View {
        NavigationView {
            ZStack {
                Map(position: $mapPosition, selection: $selectedMapResult) {
                    ForEach(searchResults, id: \.self) { result in
                        Marker(item: result)
                            .tint(themeManager.currentTheme.error)
                    }
                }
                .safeAreaInset(edge: .top) { mapSearchBarView }
                .safeAreaInset(edge: .bottom) {
                    if let selectedResult = selectedMapResult {
                        mapSelectedResultDetailView(selectedResult)
                    }
                }
                .onMapCameraChange { context in
                    mapVisibleRegion = context.region
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { showMapPicker = false }
                }
            }
        }
    }

    private var mapSearchBarView: some View {
        TextField("場所を検索", text: $searchText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .onSubmit { Task { await performMapSearch() } }
    }

    private func performMapSearch() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.resultTypes = .pointOfInterest
        request.region = mapVisibleRegion ?? MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 0.0125, longitudeDelta: 0.0125)
        )
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            searchResults = response.mapItems
            if let first = searchResults.first {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: first.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            searchText = ""
        } catch {}
    }

    private func mapSelectedResultDetailView(_ result: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name ?? "名称なし")
                        .font(.title2.weight(.bold))
                    if let category = result.pointOfInterestCategory?.rawValue {
                        Text(category)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let address = result.placemark.title {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.error)
                        .font(.title3)
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let phoneNumber = result.phoneNumber {
                HStack(spacing: 8) {
                    Image(systemName: "phone.circle.fill")
                        .foregroundStyle(themeManager.currentTheme.success)
                        .font(.title3)
                    Text(phoneNumber).font(.subheadline)
                    Spacer()
                    Button {
                        if let url = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("電話").font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(themeManager.currentTheme.success)
                            .foregroundStyle(.white).cornerRadius(8)
                    }
                }
            }

            if let url = result.url {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(themeManager.currentTheme.primary)
                        .font(.title3)
                    Text(url.host ?? "Website").font(.subheadline).lineLimit(1)
                    Spacer()
                    Button { UIApplication.shared.open(url) } label: {
                        Text("開く").font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(themeManager.currentTheme.primary)
                            .foregroundStyle(.white).cornerRadius(8)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button { result.openInMaps() } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(themeManager.currentTheme.primary.opacity(0.1))
                        .foregroundStyle(themeManager.currentTheme.primary).cornerRadius(10)
                }
                Button { addPlaceFromMapResult(result) } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(themeManager.currentTheme.accent1.opacity(0.1))
                        .foregroundStyle(themeManager.currentTheme.accent1).cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: -4)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func addPlaceFromMapResult(_ result: MKMapItem) {
        places.append(PlannedPlace(
            name: result.name ?? "名称不明",
            latitude: result.placemark.coordinate.latitude,
            longitude: result.placemark.coordinate.longitude,
            address: result.placemark.title
        ))
        selectedMapResult = nil
        showMapPicker = false
    }

    // MARK: - Helper Methods
    private func deletePlace(_ place: PlannedPlace) {
        places.removeAll { $0.id == place.id }
    }

    private func savePlan() {
        let plan: Plan
        if selectedPlanType == .outing {
            plan = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                endDate: endDate < startDate ? startDate : endDate,
                places: places,
                planType: .outing
            )
        } else {
            plan = Plan(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: dailyDate,
                endDate: dailyDate,
                places: places,
                planType: .daily,
                time: dailyTime,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                linkURL: linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        onSave(plan)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Preview
#Preview {
    AddPlanView { _ in }
}
