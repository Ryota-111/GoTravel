import SwiftUI
import MapKit

struct PlanDetailView: View {
    @State var plan: Plan
    @State private var showMap = false
    @State private var showStreetView = false
    @State private var isEditMode = false
    @State private var displayImage: UIImage?
    @State private var showSidebar = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var showScheduleEditor = false
    @State private var editingScheduleItem: PlanScheduleItem?

    // 編集用の一時変数
    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var editedLinkURL: String = ""
    @State private var editedPlanType: PlanType = .outing
    @State private var editedStartDate: Date = Date()
    @State private var editedEndDate: Date = Date()
    @State private var editedTime: Date?
    @State private var editedPlaces: [PlannedPlace] = []
    @State private var showAddPlaceInEdit = false
    @State private var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    ))
    @State private var selectedMapResult: MKMapItem?
    @State private var mapVisibleRegion: MKCoordinateRegion?
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: PlansViewModel
    @EnvironmentObject var authVM: AuthViewModel

    var onUpdate: ((Plan) -> Void)?

    var body: some View {
        ZStack(alignment: .leading) {
            // Main Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if isEditMode {
                        editModeView
                    } else {
                        viewModeView
                    }
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ?
                        [planColor.opacity(0.8), .black] :
                        [planColor.opacity(0.7), .white.opacity(0.1)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .offset(x: showSidebar ? 280 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isEditMode {
                            if value.translation.width > 0 && !showSidebar {
                                showSidebar = true
                            } else if value.translation.width < -50 && showSidebar {
                                showSidebar = false
                            }
                        }
                    }
            )

            // Overlay to close sidebar
            if showSidebar {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSidebar = false
                        }
                    }
                    .transition(.opacity)
            }

            // Sidebar (編集モード時は非表示)
            if !isEditMode {
                sidebarView
                    .offset(x: showSidebar ? 0 : -280)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showSidebar)
                    .zIndex(1)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditMode {
                    HStack(spacing: 12) {
                        Button("キャンセル") {
                            cancelEdit()
                        }
                        .foregroundColor(.secondary)

                        Button(action: saveChanges) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("保存")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isSaving || editedTitle.isEmpty)
                        .foregroundColor(editedTitle.isEmpty ? .secondary : planColor)
                    }
                } else {
                    Button(action: {
                        enterEditMode()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("編集")
                        }
                        .foregroundColor(planColor)
                    }
                }
            }
        }
        .task {
            loadLocalImage()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .fullScreenCover(isPresented: $showAddPlaceInEdit) {
            mapPickerView
        }
        .alert("エラー", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .alert("プランを削除", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text("このプランを削除してもよろしいですか？この操作は取り消せません。")
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if newValue != nil {
                displayImage = newValue
            }
        }
    }

    // MARK: - Computed Properties
    private var planColor: Color {
        isEditMode ? (editedPlanType == .daily ? .orange : .blue) : (plan.planType == .daily ? .orange : .blue)
    }

    private var planTypeText: String {
        isEditMode ? (editedPlanType == .daily ? "日常" : "おでかけ") : (plan.planType == .daily ? "日常" : "おでかけ")
    }

    private var planTypeIcon: String {
        isEditMode ? (editedPlanType == .daily ? "house.fill" : "figure.walk") : (plan.planType == .daily ? "house.fill" : "figure.walk")
    }

    // MARK: - View Mode
    private var viewModeView: some View {
        VStack(spacing: 0) {
            // Header Image
            headerImageView

            // Content Card
            VStack(alignment: .leading, spacing: 15) {
                // Category Tag
                categoryTag

                // Title
                titleSection

                // Date & Time Section
                dateTimeSection

                // Description Section
                if let description = plan.description, !description.isEmpty {
                    descriptionSection(description)
                }

                // Link Section
                if let linkURL = plan.linkURL, !linkURL.isEmpty {
                    linkSection(linkURL)
                }

                // Schedule Section (おでかけプランのみ)
                if plan.planType == .outing {
                    scheduleSection
                }

                // Action Buttons
                if !plan.places.isEmpty {
                    actionButtons

                    // Map Section (expandable)
                    if showMap {
                        mapSection
                    }
                }

                // Places Section
                if !plan.places.isEmpty {
                    placesSection
                }
            }
            .padding(24)
        }
    }

    // MARK: - Edit Mode View
    private var editModeView: some View {
        VStack(spacing: 0) {
            // Header Image with Edit Button
            editHeaderImageView

            // Edit Form
            VStack(spacing: 20) {
                // Title Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("プラン名")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    TextField("例：東京観光", text: $editedTitle)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Plan Type Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("プランタイプ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Menu {
                        Button(action: {
                            editedPlanType = .daily
                        }) {
                            HStack {
                                Image(systemName: "house.fill")
                                Text("日常")
                                if editedPlanType == .daily {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button(action: {
                            editedPlanType = .outing
                        }) {
                            HStack {
                                Image(systemName: "figure.walk")
                                Text("おでかけ")
                                if editedPlanType == .outing {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: editedPlanType == .daily ? "house.fill" : "figure.walk")
                                .foregroundColor(editedPlanType == .daily ? .orange : .blue)
                            Text(editedPlanType == .daily ? "日常" : "おでかけ")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Date Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("日程")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    VStack(spacing: 12) {
                        if editedPlanType == .outing {
                            DatePicker("開始日", selection: $editedStartDate, displayedComponents: .date)
                                .datePickerStyle(.compact)

                            DatePicker("終了日", selection: $editedEndDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        } else {
                            DatePicker("日付", selection: $editedStartDate, displayedComponents: .date)
                                .datePickerStyle(.compact)

                            if let time = editedTime {
                                DatePicker("時刻", selection: Binding(
                                    get: { time },
                                    set: { editedTime = $0 }
                                ), displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                            } else {
                                Button(action: {
                                    editedTime = Date()
                                }) {
                                    HStack {
                                        Image(systemName: "clock")
                                        Text("時刻を設定")
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.orange)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.orange.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                    )
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Description Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("予定内容")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        if editedDescription.isEmpty {
                            Text("この予定についての説明を記入...")
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        }

                        TextEditor(text: $editedDescription)
                            .font(.body)
                            .frame(minHeight: 120)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

                // Link Card
                if editedPlanType == .daily {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("関連リンク")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        TextField("https://example.com", text: $editedLinkURL)
                            .font(.body)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                            )
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                }

                // Places Card (おでかけプランのみ)
                if editedPlanType == .outing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("訪問場所")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        if editedPlaces.isEmpty {
                            Text("まだ場所が追加されていません")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                        } else {
                            ForEach(editedPlaces) { place in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(place.name)
                                            .foregroundColor(.primary)
                                        if let address = place.address {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(action: {
                                        if let index = editedPlaces.firstIndex(where: { $0.id == place.id }) {
                                            editedPlaces.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
                                )
                            }
                        }

                        Button(action: {
                            showAddPlaceInEdit = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("場所を追加")
                            }
                            .foregroundColor(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                }

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: cancelEdit) {
                        Text("キャンセル")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    Button(action: saveChanges) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("保存")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(editedTitle.isEmpty ? Color.gray : Color.blue)
                                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(isSaving || editedTitle.isEmpty)
                }
                .padding(.top, 10)

                // Delete Button
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.body)
                        Text("プランを削除")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red)
                            .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.top, 20)
            }
            .padding(24)
        }
    }

    // MARK: - Header Image (View Mode)
    private var headerImageView: some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                planColor.opacity(0.6),
                                planColor.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: planTypeIcon)
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .cornerRadius(15)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    // MARK: - Header Image (Edit Mode)
    private var editHeaderImageView: some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                planColor.opacity(0.6),
                                planColor.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: editedPlanType == .daily ? "house.fill" : "figure.walk")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }

            // Change Photo Button
            Button(action: {
                showImagePicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.body)
                    Text("写真を変更")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .cornerRadius(15)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    // MARK: - Title Section
    private var titleSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }

    // MARK: - Category Tag
    private var categoryTag: some View {
        HStack(spacing: 8) {
            Image(systemName: planTypeIcon)
                .font(.caption)
            Text(planTypeText)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(planColor)
        )
        .shadow(color: planColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    // MARK: - Date & Time Section
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .font(.headline)
                    .foregroundColor(planColor)
                Text("日程")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                if plan.planType == .outing {
                    Text(dateRangeString(plan.startDate, plan.endDate))
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text(formatDate(plan.startDate))
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                if plan.planType == .daily, let time = plan.time {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(planColor)
                        Text(formatTime(time))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Description Section
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.headline)
                    .foregroundColor(planColor)
                Text("予定内容")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Link Section
    private func linkSection(_ linkURL: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .font(.headline)
                    .foregroundColor(planColor)
                Text("関連リンク")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            if let url = URL(string: linkURL) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "safari")
                            .foregroundColor(planColor)
                        Text(linkURL)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(planColor.opacity(0.1))
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Show on Map Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showMap.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: showMap ? "map.slash.fill" : "map.fill")
                        .font(.body)
                    Text(showMap ? "閉じる" : "マップを開く")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(planColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    planColor.opacity(0.6),
                                    planColor.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(planColor, lineWidth: 2)
                        )
                )
            }
        }
    }

    // MARK: - Map Section
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.circle.fill")
                    .font(.headline)
                    .foregroundColor(planColor)
                Text("マップ")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Map(position: .constant(.region(calculateMapRegion()))) {
                ForEach(plan.places) { place in
                    Marker(place.name, coordinate: place.coordinate)
                        .tint(planColor)
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text("\(plan.places.count)件")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(12)
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }

    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.headline)
                    .foregroundColor(planColor)
                Text("スケジュール")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    editingScheduleItem = nil
                    showScheduleEditor = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                        Text("追加")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(planColor)
                }
            }

            if plan.scheduleItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("スケジュールがまだありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemBackground))
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedScheduleItems) { item in
                        scheduleItemRow(item: item)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .sheet(isPresented: $showScheduleEditor) {
            ScheduleItemEditorView(
                plan: $plan,
                scheduleItem: editingScheduleItem,
                onSave: { updatedPlan in
                    plan = updatedPlan
                    if let userId = authVM.userId {
                        viewModel.update(updatedPlan, userId: userId)
                    }
                }
            )
        }
    }

    private func scheduleItemRow(item: PlanScheduleItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            VStack(spacing: 2) {
                Text(formatTime(item.time))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(planColor)
            }
            .frame(width: 50)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)

                if let placeId = item.placeId,
                   let place = plan.places.first(where: { $0.id == placeId }) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(planColor.opacity(0.7))
                        Text(place.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Edit/Delete Buttons
            Menu {
                Button(action: {
                    editingScheduleItem = item
                    showScheduleEditor = true
                }) {
                    Label("編集", systemImage: "pencil")
                }

                Button(role: .destructive, action: {
                    deleteScheduleItem(item)
                }) {
                    Label("削除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var sortedScheduleItems: [PlanScheduleItem] {
        plan.scheduleItems.sorted { $0.time < $1.time }
    }

    private func deleteScheduleItem(_ item: PlanScheduleItem) {
        var updatedPlan = plan
        updatedPlan.scheduleItems.removeAll { $0.id == item.id }
        plan = updatedPlan
        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }
    }

    // MARK: - Places Section
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundColor(planColor)
                Text("訪問予定の場所")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            VStack(spacing: 12) {
                ForEach(plan.places) { place in
                    PlaceRowCard(place: place, planColor: planColor)
                }
            }
        }
    }

    // MARK: - Sidebar View
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("スケジュール")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Spacer()
                }

                Text("\(sortedPlans.count)件のプラン")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        planColor,
                        planColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Schedule List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(sortedPlans) { schedulePlan in
                        sidebarPlanItem(plan: schedulePlan)
                    }
                }
                .padding(12)
            }
            .background(Color(.systemBackground))
        }
        .frame(width: 280)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.2), radius: 15, x: 5, y: 0)
    }

    private func sidebarPlanItem(plan schedulePlan: Plan) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                plan = schedulePlan
                showSidebar = false
                loadLocalImage()
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Plan type icon
                ZStack {
                    Circle()
                        .fill(schedulePlan.planType == .daily ?
                              LinearGradient(gradient: Gradient(colors: [.orange, .orange.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing) :
                              LinearGradient(gradient: Gradient(colors: [.blue, .blue.opacity(0.7)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)

                    Image(systemName: schedulePlan.planType == .outing ? "figure.walk" : "house.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: (schedulePlan.planType == .daily ? Color.orange : Color.blue).opacity(0.3), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(schedulePlan.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if schedulePlan.planType == .outing {
                            Text(dateRangeString(schedulePlan.startDate, schedulePlan.endDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(formatDate(schedulePlan.startDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !schedulePlan.places.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption2)
                                .foregroundColor(schedulePlan.planType == .daily ? .orange : .blue)
                            Text("\(schedulePlan.places.count)件")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if schedulePlan.id == plan.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(schedulePlan.planType == .daily ? .orange : .blue)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(schedulePlan.id == plan.id ?
                          (schedulePlan.planType == .daily ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1)) :
                          Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(schedulePlan.id == plan.id ?
                            (schedulePlan.planType == .daily ? Color.orange.opacity(0.4) : Color.blue.opacity(0.4)) :
                            Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Computed Properties for Sidebar
    private var sortedPlans: [Plan] {
        viewModel.plans.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Edit Mode Functions
    private func enterEditMode() {
        editedTitle = plan.title
        editedDescription = plan.description ?? ""
        editedLinkURL = plan.linkURL ?? ""
        editedPlanType = plan.planType
        editedStartDate = plan.startDate
        editedEndDate = plan.endDate
        editedTime = plan.time
        editedPlaces = plan.places
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = true
        }
    }

    private func cancelEdit() {
        selectedImage = nil
        displayImage = loadImageFromLocal()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isEditMode = false
        }
    }

    private func saveChanges() {
        guard !editedTitle.isEmpty else { return }

        isSaving = true

        // 画像を保存（選択されている場合）
        if let image = selectedImage {
            saveImageLocally(image) { result in
                switch result {
                case .success(let fileName):
                    updatePlanData(with: fileName)
                case .failure(let error):
                    handleSaveError(error)
                }
            }
        } else {
            updatePlanData(with: plan.localImageFileName)
        }
    }

    private func updatePlanData(with localFileName: String?) {
        var updatedPlan = plan
        updatedPlan.title = editedTitle
        updatedPlan.description = editedDescription.isEmpty ? nil : editedDescription
        updatedPlan.linkURL = editedLinkURL.isEmpty ? nil : editedLinkURL
        updatedPlan.planType = editedPlanType
        updatedPlan.startDate = editedStartDate
        updatedPlan.endDate = editedEndDate
        updatedPlan.time = editedTime
        updatedPlan.places = editedPlaces
        updatedPlan.localImageFileName = localFileName

        if let userId = authVM.userId {
            viewModel.update(updatedPlan, userId: userId)
        }

        DispatchQueue.main.async {
            isSaving = false
            plan = updatedPlan
            selectedImage = nil
            displayImage = loadImageFromLocal()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isEditMode = false
            }
        }
    }

    private func handleSaveError(_ error: Error) {
        DispatchQueue.main.async {
            isSaving = false
            alertMessage = "保存に失敗しました: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Image Storage Functions
    private func saveImageLocally(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "PlanDetailView", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像データの変換に失敗しました"])))
            return
        }

        let fileName = "plan_\(plan.id).jpg"

        do {
            try FileManager.saveImageDataToDocuments(data: imageData, named: fileName)
            completion(.success(fileName))
        } catch {
            completion(.failure(error))
        }
    }

    private func loadLocalImage() {
        displayImage = loadImageFromLocal()
    }

    private func loadImageFromLocal() -> UIImage? {
        guard let fileName = plan.localImageFileName else { return nil }

        if let image = FileManager.documentsImage(named: fileName) {
            return image
        } else {
            return nil
        }
    }

    // MARK: - Helper Functions
    private func calculateMapRegion() -> MKCoordinateRegion {
        guard let firstPlace = plan.places.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }

        return MKCoordinateRegion(
            center: firstPlace.coordinate,
            latitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000)),
            longitudinalMeters: CLLocationDistance(max(plan.places.count * 1000, 2000))
        )
    }

    private func dateRangeString(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return "\(formatter.string(from: start))〜\(formatter.string(from: end))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: time)
    }

    // MARK: - Delete Function
    private func deletePlan() {
        print("🗑️ [PlanDetailView] Delete button pressed for plan: \(plan.title)")
        Task { @MainActor in
            print("🗑️ [PlanDetailView] Calling viewModel.deletePlan...")
            // ViewModelからプランを削除（CloudKitの削除完了まで待つ）
            await viewModel.deletePlan(plan, userId: authVM.userId)
            print("🗑️ [PlanDetailView] deletePlan completed")

            // ローカル画像ファイルを削除
            if let fileName = plan.localImageFileName {
                print("🗑️ [PlanDetailView] Removing local image: \(fileName)")
                try? FileManager.removeDocumentFile(named: fileName)
            }

            // CloudKit削除完了後に画面を閉じる
            print("🗑️ [PlanDetailView] Dismissing view")
            dismiss()
            print("🗑️ [PlanDetailView] View dismissed")
        }
    }

    // MARK: - Map Picker View
    private var mapPickerView: some View {
        NavigationView {
            ZStack {
                Map(position: $mapPosition, selection: $selectedMapResult) {
                    ForEach(searchResults, id: \.self) { result in
                        Marker(item: result)
                            .tint(.red)
                    }
                }
                .safeAreaInset(edge: .top) {
                    mapSearchBarView
                }
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
                    Button("閉じる") {
                        showAddPlaceInEdit = false
                    }
                }
            }
        }
    }

    // MARK: - Map Search Bar
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
            .onSubmit {
                Task {
                    await performMapSearch()
                }
            }
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
            if let firstResult = searchResults.first {
                withAnimation {
                    mapPosition = .region(MKCoordinateRegion(
                        center: firstResult.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
            searchText = ""
        } catch {
        }
    }

    // MARK: - Map Selected Result Detail View
    private func mapSelectedResultDetailView(_ result: MKMapItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name ?? "名称なし")
                        .font(.title2)
                        .fontWeight(.bold)

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
                        .foregroundStyle(.red)
                        .font(.title3)
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let phoneNumber = result.phoneNumber {
                HStack(spacing: 8) {
                    Image(systemName: "phone.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text(phoneNumber)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        if let url = URL(string: "tel:\(phoneNumber.replacingOccurrences(of: " ", with: ""))") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("電話")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }

            if let url = result.url {
                HStack(spacing: 8) {
                    Image(systemName: "safari.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                    Text(url.host ?? "Website")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Text("開く")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    result.openInMaps()
                } label: {
                    Label("経路", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(10)
                }

                Button {
                    addPlaceFromMapResult(result)
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .foregroundStyle(.orange)
                        .cornerRadius(10)
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
        let place = PlannedPlace(
            name: result.name ?? "名称不明",
            latitude: result.placemark.coordinate.latitude,
            longitude: result.placemark.coordinate.longitude,
            address: result.placemark.title
        )
        editedPlaces.append(place)
        selectedMapResult = nil
        showAddPlaceInEdit = false
    }
}

