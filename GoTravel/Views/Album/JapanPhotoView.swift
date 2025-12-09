import SwiftUI
import Combine

struct JapanPhotoView: View {
    @StateObject private var viewModel = JapanPhotoViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedPrefecture: Prefecture?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var animateCards = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection

                        mapCardSection

                        statsSection

                        prefectureGridSection
                    }
                    .padding()
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primary)
                }
            }
            .onAppear {
                animateCards = true
            }
        }
        .sheet(item: $selectedPrefecture) { prefecture in
            PrefecturePhotoEditorView(
                prefecture: prefecture,
                onSave: { image in
                    viewModel.savePhoto(for: prefecture, image: image)
                    selectedPrefecture = nil
                }
            )
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.primary.opacity(0.7), .black] :
                [themeManager.currentTheme.primary.opacity(0.6), .white.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentTheme.primary.opacity(0.8),
                                    themeManager.currentTheme.primary.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .shadow(color: themeManager.currentTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("日本全国フォトマップ")
                        .font(.title2.bold())

                    Text("訪れた都道府県の思い出を記録")
                        .font(.subheadline)
                }

                Spacer()
            }
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : -20)
    }

    // MARK: - Map Card Section
    private var mapCardSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("インタラクティブマップ")
                    .font(.headline)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "hand.pinch")
                        .font(.caption)
                    Text("ピンチ・ドラッグで操作")
                        .font(.caption)
                }
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeManager.currentTheme.secondaryText.opacity(0.15))
                )
            }

            mapView
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
    }

    private var mapView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        colorScheme == .dark ?
                            Color.white.opacity(0.05) :
                            Color.white.opacity(0.3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeManager.currentTheme.primary.opacity(0.3),
                                        themeManager.currentTheme.primary.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // Map content
                ZStack {
                    themeManager.currentTheme.primary.opacity(0.15)
                        .frame(width: 370 * 2, height: 600 * 2)

                    ForEach(Prefecture.allCases) { prefecture in
                        prefectureMapCell(prefecture, in: CGSize(width: 370, height: 600))
                    }
                }
                .frame(width: 370, height: 500)
                .scaleEffect(scale)
                .offset(offset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { value in
                        lastScale = scale
                        if scale < 1.0 {
                            scale = 1.0
                            lastScale = 1.0
                        } else if scale > 3.0 {
                            scale = 3.0
                            lastScale = 3.0
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let newOffset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                        let maxOffsetX = (370 * 2 * scale - geometry.size.width) / 2
                        let maxOffsetY = (600 * 2 * scale - geometry.size.height) / 2

                        offset = CGSize(
                            width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                            height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                        )
                    }
                    .onEnded { value in
                        lastOffset = offset
                    }
            )
        }
        .frame(height: 500)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    private func prefectureMapCell(_ prefecture: Prefecture, in size: CGSize) -> some View {
        let position = prefecture.mapPosition
        let prefSize = prefecture.mapSize

        return ZStack {
            if let photo = viewModel.photos[prefecture] {
                MaskedPrefectureImage(
                    prefecture: prefecture,
                    photo: photo,
                    size: prefSize
                )
                .contentShape(
                    Rectangle()
                        .size(prefSize)
                )
                .onTapGesture {
                    selectedPrefecture = prefecture
                }
            } else {
                if let maskImage = prefecture.maskImage {
                    Image(uiImage: maskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: prefSize.width, height: prefSize.height)
                        .foregroundColor(themeManager.currentTheme.success.opacity(0.6))
                        .contentShape(
                            Rectangle()
                                .size(prefSize)
                        )
                        .onTapGesture {
                            selectedPrefecture = prefecture
                        }
                } else {
                    prefecture.shape
                        .fill(themeManager.currentTheme.success.opacity(0.6))
                        .frame(width: prefSize.width, height: prefSize.height)
                        .overlay(
                            prefecture.shape
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .contentShape(prefecture.shape)
                        .onTapGesture {
                            selectedPrefecture = prefecture
                        }
                }
            }

            Text(prefecture.shortName)
                .font(.system(size: 4))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 1)
                .allowsHitTesting(false)
        }
        .position(
            x: size.width * position.x,
            y: size.height * position.y
        )
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 12) {
            JapanStatCard(
                icon: "photo.on.rectangle",
                title: "登録済み",
                value: "\(viewModel.photos.count)",
                color: themeManager.currentTheme.primary
            )

            JapanStatCard(
                icon: "location.fill",
                title: "残り",
                value: "\(47 - viewModel.photos.count)",
                color: themeManager.currentTheme.success
            )

            JapanStatCard(
                icon: "percent",
                title: "達成率",
                value: String(format: "%.0f%%", Double(viewModel.photos.count) / 47.0 * 100),
                color: themeManager.currentTheme.accent1
            )
        }
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
    }

    // MARK: - Prefecture Grid Section
    private var prefectureGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("都道府県一覧")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(Prefecture.allCases.enumerated()), id: \.element.id) { index, prefecture in
                    PrefectureGridCard(
                        prefecture: prefecture,
                        hasPhoto: viewModel.photos[prefecture] != nil,
                        photo: viewModel.photos[prefecture]
                    )
                    .onTapGesture {
                        selectedPrefecture = prefecture
                    }
                    .opacity(animateCards ? 1 : 0)
                    .scaleEffect(animateCards ? 1 : 0.8)
                }
            }
        }
    }
}

// MARK: - Japan Stat Card
struct JapanStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title2.bold())

                Text(title)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark ?
                        Color.white.opacity(0.1) :
                        Color.white.opacity(0.25)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.5),
                            color.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Prefecture Grid Card
struct PrefectureGridCard: View {
    let prefecture: Prefecture
    let hasPhoto: Bool
    let photo: UIImage?
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let image = photo {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentTheme.secondaryText.opacity(0.3),
                                    themeManager.currentTheme.secondaryText.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.6))

                                Text("追加")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        )
                }

                if hasPhoto {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundColor(themeManager.currentTheme.success)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                )
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        hasPhoto ?
                            themeManager.currentTheme.primary.opacity(0.4) :
                            Color.white.opacity(0.2),
                        lineWidth: hasPhoto ? 2 : 1
                    )
            )

            Text(prefecture.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Prefecture Photo Editor View
struct PrefecturePhotoEditorView: View {
    let prefecture: Prefecture
    let onSave: (UIImage) -> Void
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient

                ScrollView {
                    VStack(spacing: 24) {
                        prefectureHeaderSection

                        imagePreviewSection

                        actionButtonsSection

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker { image in
                selectedImage = image
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ?
                [themeManager.currentTheme.primary.opacity(0.7), .black] :
                [themeManager.currentTheme.primary.opacity(0.6), .white.opacity(0.3)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var prefectureHeaderSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.primary.opacity(0.8),
                                themeManager.currentTheme.primary.opacity(0.5)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "location.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            .shadow(color: themeManager.currentTheme.primary.opacity(0.4), radius: 10, x: 0, y: 5)

            Text(prefecture.name)
                .font(.title.bold())

            Text("思い出の写真を追加")
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var imagePreviewSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeManager.currentTheme.primary.opacity(0.5),
                                        themeManager.currentTheme.primary.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        colorScheme == .dark ?
                            Color.white.opacity(0.05) :
                            Color.white.opacity(0.3)
                    )
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))

                            Text("写真を選択してください")
                                .font(.headline)
                                .foregroundColor(themeManager.currentTheme.secondaryText.opacity(0.6))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                Color.white.opacity(0.2),
                                style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                            )
                    )
            }
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showImagePicker = true
            }) {
                Label("写真を選択", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.primary,
                                themeManager.currentTheme.primary.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: themeManager.currentTheme.primary.opacity(0.4), radius: 10, x: 0, y: 5)
            }

            if selectedImage != nil {
                Button(action: {
                    if let image = selectedImage {
                        onSave(image)
                    }
                }) {
                    Label("保存", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentTheme.success,
                                    themeManager.currentTheme.success.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: themeManager.currentTheme.success.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
        }
    }
}

// MARK: - Prefecture Enum (No changes - kept as is)
enum Prefecture: String, CaseIterable, Identifiable {
    case hokkaido, aomori, iwate, miyagi, akita, yamagata, fukushima
    case ibaraki, tochigi, gunma, saitama, chiba, tokyo, kanagawa
    case niigata, toyama, ishikawa, fukui, yamanashi, nagano, gifu, shizuoka, aichi
    case mie, shiga, kyoto, osaka, hyogo, nara, wakayama
    case tottori, shimane, okayama, hiroshima, yamaguchi
    case tokushima, kagawa, ehime, kochi
    case fukuoka, saga, nagasaki, kumamoto, oita, miyazaki, kagoshima
    case okinawa

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hokkaido: return "北海道"
        case .aomori: return "青森県"
        case .iwate: return "岩手県"
        case .miyagi: return "宮城県"
        case .akita: return "秋田県"
        case .yamagata: return "山形県"
        case .fukushima: return "福島県"
        case .ibaraki: return "茨城県"
        case .tochigi: return "栃木県"
        case .gunma: return "群馬県"
        case .saitama: return "埼玉県"
        case .chiba: return "千葉県"
        case .tokyo: return "東京都"
        case .kanagawa: return "神奈川県"
        case .niigata: return "新潟県"
        case .toyama: return "富山県"
        case .ishikawa: return "石川県"
        case .fukui: return "福井県"
        case .yamanashi: return "山梨県"
        case .nagano: return "長野県"
        case .gifu: return "岐阜県"
        case .shizuoka: return "静岡県"
        case .aichi: return "愛知県"
        case .mie: return "三重県"
        case .shiga: return "滋賀県"
        case .kyoto: return "京都府"
        case .osaka: return "大阪府"
        case .hyogo: return "兵庫県"
        case .nara: return "奈良県"
        case .wakayama: return "和歌山県"
        case .tottori: return "鳥取県"
        case .shimane: return "島根県"
        case .okayama: return "岡山県"
        case .hiroshima: return "広島県"
        case .yamaguchi: return "山口県"
        case .tokushima: return "徳島県"
        case .kagawa: return "香川県"
        case .ehime: return "愛媛県"
        case .kochi: return "高知県"
        case .fukuoka: return "福岡県"
        case .saga: return "佐賀県"
        case .nagasaki: return "長崎県"
        case .kumamoto: return "熊本県"
        case .oita: return "大分県"
        case .miyazaki: return "宮崎県"
        case .kagoshima: return "鹿児島県"
        case .okinawa: return "沖縄県"
        }
    }

    var shortName: String {
        String(name.prefix(3))
    }

    var mapPosition: CGPoint {
        switch self {
        // 北海道
        case .hokkaido: return CGPoint(x: 1.45, y: 0.69)

        // 東北
        case .aomori: return CGPoint(x: 1.33, y: 0.82)
        case .iwate: return CGPoint(x: 1.368, y: 0.888)
        case .akita: return CGPoint(x: 1.301, y: 0.883)
        case .miyagi: return CGPoint(x: 1.341, y: 0.951)
        case .yamagata: return CGPoint(x: 1.284, y: 0.9493)
        case .fukushima: return CGPoint(x: 1.284, y: 1)

        // 関東
        case .ibaraki: return CGPoint(x: 1.294, y: 1.053)
        case .tochigi: return CGPoint(x: 1.265, y: 1.036)
        case .gunma: return CGPoint(x: 1.215, y: 1.045)
        case .saitama: return CGPoint(x: 1.231, y: 1.065)
        case .chiba: return CGPoint(x: 1.298, y: 1.093)
        case .tokyo: return CGPoint(x: 1.239, y: 1.081)
        case .kanagawa: return CGPoint(x: 1.236, y: 1.096)

        // 中部
        case .niigata: return CGPoint(x: 1.196, y: 0.9885)
        case .toyama: return CGPoint(x: 1.095, y: 1.04)
        case .ishikawa: return CGPoint(x: 1.064, y: 1.032)
        case .fukui: return CGPoint(x: 1.006, y: 1.081)
        case .yamanashi: return CGPoint(x: 1.189, y: 1.088)
        case .nagano: return CGPoint(x: 1.146, y: 1.066)
        case .gifu: return CGPoint(x: 1.07, y: 1.082)
        case .shizuoka: return CGPoint(x: 1.167, y: 1.111)
        case .aichi: return CGPoint(x: 1.089, y: 1.125)

        // 関西
        case .mie: return CGPoint(x: 1.025, y: 1.159)
        case .shiga: return CGPoint(x: 1.003, y: 1.114)
        case .kyoto: return CGPoint(x: 0.952, y: 1.115)
        case .osaka: return CGPoint(x: 0.947, y: 1.15)
        case .hyogo: return CGPoint(x: 0.9065, y: 1.132)
        case .nara: return CGPoint(x: 0.985, y: 1.169)
        case .wakayama: return CGPoint(x: 0.959, y: 1.194)

        // 中国
        case .tottori: return CGPoint(x: 0.827, y: 1.109)
        case .shimane: return CGPoint(x: 0.725, y: 1.132)
        case .okayama: return CGPoint(x: 0.829, y: 1.136)
        case .hiroshima: return CGPoint(x: 0.744, y: 1.152)
        case .yamaguchi: return CGPoint(x: 0.661, y: 1.174)

        // 四国
        case .tokushima: return CGPoint(x: 0.864, y: 1.189)
        case .kagawa: return CGPoint(x: 0.849, y: 1.171)
        case .ehime: return CGPoint(x: 0.774, y: 1.204)
        case .kochi: return CGPoint(x: 0.812, y: 1.218)

        // 九州
        case .fukuoka: return CGPoint(x: 0.589, y: 1.211)
        case .saga: return CGPoint(x: 0.553, y: 1.223)
        case .nagasaki: return CGPoint(x: 0.531, y: 1.237)
        case .kumamoto: return CGPoint(x: 0.592, y: 1.249)
        case .oita: return CGPoint(x: 0.642, y: 1.222)
        case .miyazaki: return CGPoint(x: 0.63, y: 1.273)
        case .kagoshima: return CGPoint(x: 0.592, y: 1.293)
        case .okinawa: return CGPoint(x: 0.35, y: 1.40)
        }
    }

    var mapSize: CGSize {
        switch self {
        case .hokkaido: return CGSize(width: 130, height: 130)
        case .aomori: return CGSize(width: 50, height: 42)
        case .iwate: return CGSize(width: 55, height: 55)
        case .akita: return CGSize(width: 53, height: 53)
        case .miyagi: return CGSize(width: 39, height: 39)
        case .yamagata: return CGSize(width: 45, height: 44)
        case .fukushima: return CGSize(width: 44, height: 44)
        case .ibaraki: return CGSize(width: 36, height: 36)
        case .tochigi: return CGSize(width: 29, height: 29)
        case .gunma: return CGSize(width: 36, height: 36)
        case .saitama: return CGSize(width: 29, height: 29)
        case .chiba: return CGSize(width: 35, height: 35)
        case .tokyo: return CGSize(width: 25, height: 25)
        case .kanagawa: return CGSize(width: 21, height: 21)
        case .niigata: return CGSize(width: 58, height: 60)
        case .toyama: return CGSize(width: 24, height: 30)
        case .ishikawa: return CGSize(width: 50, height: 45)
        case .fukui: return CGSize(width: 40, height: 40)
        case .yamanashi: return CGSize(width: 25, height: 25)
        case .nagano: return CGSize(width: 55, height: 57)
        case .gifu: return CGSize(width: 46, height: 46)
        case .shizuoka: return CGSize(width: 42, height: 42)
        case .aichi: return CGSize(width: 32, height: 32)
        case .mie: return CGSize(width: 55, height: 55)
        case .shiga: return CGSize(width:33, height: 33)
        case .kyoto: return CGSize(width:38, height: 38)
        case .osaka: return CGSize(width: 30, height: 30)
        case .hyogo: return CGSize(width:51, height: 51)
        case .nara: return CGSize(width:33, height: 33)
        case .wakayama: return CGSize(width:35, height: 33)
        case .tottori: return CGSize(width:40, height: 40)
        case .shimane: return CGSize(width:47, height: 47)
        case .okayama: return CGSize(width:36, height: 36)
        case .hiroshima: return CGSize(width:41, height: 41)
        case .yamaguchi: return CGSize(width:40, height: 40)
        case .tokushima: return CGSize(width:28, height: 28)
        case .kagawa: return CGSize(width:23, height: 23)
        case .ehime: return CGSize(width:41, height: 41)
        case .kochi: return CGSize(width:44, height: 44)
        case .fukuoka: return CGSize(width:32, height: 32)
        case .saga: return CGSize(width:24, height: 24)
        case .nagasaki: return CGSize(width:35, height: 35)
        case .kumamoto: return CGSize(width:30, height: 30)
        case .oita: return CGSize(width:29, height: 29)
        case .miyazaki: return CGSize(width:40, height: 40)
        case .kagoshima: return CGSize(width:36, height: 36)
        case .okinawa: return CGSize(width: 40, height: 40)
        }
    }

    var shapePath: Path {
        var path = Path()

        switch self {
        case .hokkaido:
            path.move(to: CGPoint(x: 0.5, y: 0))
            path.addLine(to: CGPoint(x: 1, y: 0.3))
            path.addLine(to: CGPoint(x: 0.9, y: 0.7))
            path.addLine(to: CGPoint(x: 0.6, y: 1))
            path.addLine(to: CGPoint(x: 0.2, y: 0.9))
            path.addLine(to: CGPoint(x: 0, y: 0.5))
            path.addLine(to: CGPoint(x: 0.1, y: 0.2))
            path.closeSubpath()

        case .tokyo:
            path.addEllipse(in: CGRect(x: 0, y: 0, width: 1, height: 1))

        case .osaka:
            path.move(to: CGPoint(x: 0.3, y: 0))
            path.addLine(to: CGPoint(x: 1, y: 0.2))
            path.addLine(to: CGPoint(x: 0.9, y: 0.8))
            path.addLine(to: CGPoint(x: 0.4, y: 1))
            path.addLine(to: CGPoint(x: 0, y: 0.6))
            path.closeSubpath()

        default:
            path.move(to: CGPoint(x: 0.2, y: 0))
            path.addLine(to: CGPoint(x: 1, y: 0.1))
            path.addLine(to: CGPoint(x: 0.9, y: 0.9))
            path.addLine(to: CGPoint(x: 0.1, y: 1))
            path.addLine(to: CGPoint(x: 0, y: 0.3))
            path.closeSubpath()
        }

        return path
    }

    var shape: some Shape {
        PrefectureShape(prefecture: self)
    }

    var maskImage: UIImage? {
        UIImage(named: "prefecture_\(rawValue)")
    }

    func generateMaskImage() -> UIImage? {
        let size = mapSize
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let path = shapePath
            let scaledPath = path.applying(CGAffineTransform(scaleX: size.width, y: size.height))

            UIColor.white.setFill()
            context.cgContext.addPath(scaledPath.cgPath)
            context.cgContext.fillPath()
        }
    }
}

// MARK: - Prefecture Shape (No changes - kept as is)
struct PrefectureShape: Shape {
    let prefecture: Prefecture

    func path(in rect: CGRect) -> Path {
        let path = prefecture.shapePath
        let scaleX = rect.width
        let scaleY = rect.height

        return path.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}

// MARK: - Masked Prefecture Image (No changes - kept as is)
struct MaskedPrefectureImage: View {
    let prefecture: Prefecture
    let photo: UIImage
    let size: CGSize

    var body: some View {
        if let maskImage = prefecture.maskImage {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .mask(
                    Image(uiImage: maskImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)
                )
        } else {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipShape(prefecture.shape)
        }
    }
}

// MARK: - ViewModel
class JapanPhotoViewModel: ObservableObject {
    @Published var photos: [Prefecture: UIImage] = [:]
    private let photoManager = JapanPhotoManager.shared

    init() {
        loadAllPhotos()
    }

    func savePhoto(for prefecture: Prefecture, image: UIImage) {
        // Save to local storage
        if photoManager.savePhoto(image, for: prefecture.rawValue) {
            // Update in-memory photos
            photos[prefecture] = image
        } else {
        }
    }

    func deletePhoto(for prefecture: Prefecture) {
        // Delete from local storage
        if photoManager.deletePhoto(for: prefecture.rawValue) {
            // Update in-memory photos
            photos.removeValue(forKey: prefecture)
        } else {
        }
    }

    private func loadAllPhotos() {
        // Load all photos from local storage
        let savedPhotos = photoManager.loadAllPhotos()

        for (prefectureRawValue, image) in savedPhotos {
            if let prefecture = Prefecture.allCases.first(where: { $0.rawValue == prefectureRawValue }) {
                photos[prefecture] = image
            }
        }

    }
}

#Preview {
    JapanPhotoView()
}
