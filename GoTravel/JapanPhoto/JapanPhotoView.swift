import SwiftUI
import Combine

struct JapanPhotoView: View {
    @StateObject private var viewModel = JapanPhotoViewModel()
    @State private var selectedPrefecture: Prefecture?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.6), .white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        titleSection

                        japanMapView

                        prefectureListSection
                    }
                    .padding()
                }
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

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("日本全国フォトマップ")
                .font(.title2)
                .fontWeight(.bold)

            Text("訪れた都道府県の写真を追加しよう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var japanMapView: some View {
        VStack {
            Text("日本地図")
                .font(.headline)
                .padding(.bottom, 10)

            GeometryReader { geometry in
                ZStack {
                    ZStack {
                        Color.blue.opacity(0.2)
                            .frame(width: 370 * 2, height: 600 * 2)

                        ForEach(Prefecture.allCases) { prefecture in
                            prefectureMapCell(prefecture, in: CGSize(width: 370, height: 600))
                        }
                    }
                    .frame(width: 370, height: 600)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
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
                                },
                            DragGesture()
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
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                .clipped()
            }
            .frame(height: 700)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(15)
        }
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
                        .foregroundColor(.green.opacity(0.6))
                        .contentShape(
                            Rectangle()
                                .size(prefSize)
                        )
                        .onTapGesture {
                            selectedPrefecture = prefecture
                        }
                } else {
                    prefecture.shape
                        .fill(Color.green.opacity(0.6))
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

    private var prefectureListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("都道府県リスト")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                ForEach(Prefecture.allCases) { prefecture in
                    prefectureListCell(prefecture)
                }
            }
        }
    }

    private func prefectureListCell(_ prefecture: Prefecture) -> some View {
        Button(action: {
            selectedPrefecture = prefecture
        }) {
            VStack(spacing: 8) {
                ZStack {
                    if let image = viewModel.photos[prefecture] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 80)

                        Image(systemName: "photo.badge.plus")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }

                Text(prefecture.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Prefecture Enum
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

// MARK: - Prefecture Shape
struct PrefectureShape: Shape {
    let prefecture: Prefecture

    func path(in rect: CGRect) -> Path {
        let path = prefecture.shapePath
        let scaleX = rect.width
        let scaleY = rect.height

        return path.applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}

// MARK: - Masked Prefecture Image
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

    func savePhoto(for prefecture: Prefecture, image: UIImage) {
        photos[prefecture] = image
        // TODO: Firestoreに保存
    }
}

// MARK: - Photo Editor View
struct PrefecturePhotoEditorView: View {
    let prefecture: Prefecture
    let onSave: (UIImage) -> Void
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(prefecture.name)
                    .font(.title)
                    .fontWeight(.bold)

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(15)
                } else {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 400)
                        .overlay(
                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("写真を選択")
                                    .foregroundColor(.gray)
                            }
                        )
                }

                Button(action: {
                    showImagePicker = true
                }) {
                    Label("写真を選択", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }

                if selectedImage != nil {
                    Button(action: {
                        if let image = selectedImage {
                            onSave(image)
                        }
                    }) {
                        Text("保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $showImagePicker) {
            PhotoPicker { image in
                selectedImage = image
            }
        }
    }
}

#Preview {
    JapanPhotoView()
}
